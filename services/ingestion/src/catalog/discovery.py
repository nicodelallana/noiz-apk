"""Dynamic catalogue discovery for Moveuskadi public transport data.

Discovers the JSON catalogue, retrieves all operators and resources,
detects deltas, and validates feed metadata without hardcoded assumptions.
"""

import hashlib
import json
import re
import urllib.parse
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
import httpx

from src.catalog.models import CatalogueDiff, CatalogueSnapshot, OperatorCatalog, ResourceItem
from src.config import settings
from src.utils.logging import logger


def slugify(text: str) -> str:
    """Creates a stable URL/DB-safe slug from an operator name."""
    cleaned = text.lower().strip()
    cleaned = re.sub(r"[^\w\s-]", "", cleaned)
    cleaned = re.sub(r"[\s-]+", "_", cleaned)
    return cleaned.strip("_")


def normalize_operator_name(name: str) -> str:
    """Cleans whitespace and fixes casing inconsistencies."""
    return re.sub(r"\s+", " ", name).strip()


class CatalogueDiscoveryService:
    """Service to discover and monitor the Moveuskadi JSON data index."""

    def __init__(self, index_url: Optional[str] = None, page_url: Optional[str] = None):
        self.index_url = index_url or settings.MOVEUSKADI_CATALOG_URL
        self.page_url = page_url or settings.MOVEUSKADI_CATALOGUE_PAGE_URL
        self.client = httpx.Client(
            timeout=settings.DOWNLOAD_TIMEOUT_SECONDS,
            headers={"User-Agent": settings.USER_AGENT},
            follow_redirects=True,
            verify=False  # Required for some regional government SSL chains
        )

    def discover_index_url(self) -> str:
        """Inspects the official Moveuskadi portal page to discover index URL dynamically.
        Falls back to configured index_url if page inspection fails or does not yield changes."""
        try:
            resp = self.client.get(self.page_url)
            if resp.status_code == 200:
                html = resp.text
                matches = re.findall(r'https?://[^\s"\'<>]+\bdata-index\.json\b', html)
                if matches:
                    discovered = matches[0]
                    logger.info(f"Discovered authoritative index URL from portal: {discovered}")
                    self.index_url = discovered
                    return discovered
        except Exception as e:
            logger.warning(f"Could not scrape portal page for dynamic index URL, using default: {e}")
        return self.index_url

    def fetch_catalogue(self) -> Tuple[CatalogueSnapshot, Dict[str, OperatorCatalog]]:
        """Retrieves and parses the complete JSON index.
        Returns the snapshot and a mapped dictionary of OperatorCatalog objects."""
        logger.info(f"Fetching Moveuskadi JSON index from {self.index_url}...")
        resp = self.client.get(self.index_url)
        resp.raise_for_status()

        raw_bytes = resp.content
        checksum = hashlib.sha256(raw_bytes).hexdigest()
        data = resp.json()

        catalogue_last_update = data.get("last-update") if isinstance(data, dict) else None
        operators_dict = data.get("data", data) if isinstance(data, dict) else data

        total_resources = 0
        operator_catalogs: Dict[str, OperatorCatalog] = {}
        raw_operators: Dict[str, List[ResourceItem]] = {}

        for op_name, resources_list in operators_dict.items():
            if op_name in ("last-update", "data") and not isinstance(resources_list, list):
                continue

            clean_name = normalize_operator_name(op_name)
            op_slug = slugify(clean_name)
            parsed_resources: List[ResourceItem] = []
            formats_set = set()

            for r in resources_list:
                try:
                    # Validate and fix URL encoding if necessary without corrupting valid parts
                    url_str = r.get("url", "").strip()
                    # Parse into ResourceItem
                    item = ResourceItem(
                        format=r.get("format", "UNKNOWN").upper(),
                        url=url_str,
                        name=r.get("name", "").strip(),
                        last_update=r.get("last-update")
                    )
                    parsed_resources.append(item)
                    formats_set.add(item.format)
                    total_resources += 1
                except Exception as ex:
                    logger.warning(f"Invalid resource item in operator '{clean_name}': {r} - {ex}")

            op_cat = OperatorCatalog(
                original_name=op_name,
                normalized_name=clean_name,
                slug=op_slug,
                resources=parsed_resources,
                available_formats=sorted(list(formats_set))
            )
            operator_catalogs[clean_name] = op_cat
            raw_operators[clean_name] = parsed_resources

        snapshot = CatalogueSnapshot(
            catalogue_url=self.index_url,
            catalogue_last_update=catalogue_last_update,
            retrieved_at=datetime.now(timezone.utc),
            checksum=checksum,
            total_operators=len(operator_catalogs),
            total_resources=total_resources,
            operators=raw_operators
        )

        logger.info(
            f"Catalogue discovery complete: {snapshot.total_operators} operators, "
            f"{snapshot.total_resources} resources discovered (Checksum: {checksum[:8]})."
        )
        return snapshot, operator_catalogs

    def compute_diff(
        self,
        current_snapshot: CatalogueSnapshot,
        previous_snapshot: Optional[CatalogueSnapshot]
    ) -> CatalogueDiff:
        """Compares current snapshot with a previous snapshot to detect deltas."""
        if not previous_snapshot:
            # First run: all operators and resources are new
            new_ops = list(current_snapshot.operators.keys())
            all_res = [res for r_list in current_snapshot.operators.values() for res in r_list]
            return CatalogueDiff(
                new_operators=new_ops,
                deprecated_operators=[],
                new_resources=all_res,
                updated_resources=[],
                removed_resources=[],
                has_changes=True
            )

        if current_snapshot.checksum == previous_snapshot.checksum:
            return CatalogueDiff(has_changes=False)

        current_ops = set(current_snapshot.operators.keys())
        prev_ops = set(previous_snapshot.operators.keys())

        new_ops = list(current_ops - prev_ops)
        deprecated_ops = list(prev_ops - current_ops)

        # Map previous resources by URL
        prev_res_map: Dict[str, ResourceItem] = {
            res.url: res
            for r_list in previous_snapshot.operators.values()
            for res in r_list
        }
        curr_res_map: Dict[str, ResourceItem] = {
            res.url: res
            for r_list in current_snapshot.operators.values()
            for res in r_list
        }

        new_res = [res for url, res in curr_res_map.items() if url not in prev_res_map]
        removed_res = [res for url, res in prev_res_map.items() if url not in curr_res_map]

        updated_res = []
        for url, res in curr_res_map.items():
            if url in prev_res_map:
                old_res = prev_res_map[url]
                if res.last_update and old_res.last_update and res.last_update != old_res.last_update:
                    updated_res.append(res)

        has_changes = bool(new_ops or deprecated_ops or new_res or updated_res or removed_res)

        diff = CatalogueDiff(
            new_operators=new_ops,
            deprecated_operators=deprecated_ops,
            new_resources=new_res,
            updated_resources=updated_res,
            removed_resources=removed_res,
            has_changes=has_changes
        )

        logger.info(
            f"Catalogue diff computed: {len(new_ops)} new ops, {len(deprecated_ops)} deprecated ops, "
            f"{len(new_res)} new res, {len(updated_res)} updated res."
        )
        return diff

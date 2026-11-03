"""Master ingestion pipeline orchestrating discovery, download, processing, and publishing."""

import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import text

from src.catalog.discovery import CatalogueDiscoveryService
from src.catalog.models import OperatorCatalog, ResourceItem
from src.config import settings
from src.db.connection import get_db_session
from src.downloader.manager import DownloadManager
from src.processors.gtfs_realtime import GTFSRealtimeProcessor
from src.processors.gtfs_static import GTFSStaticProcessor
from src.processors.netex import NetexProcessor
from src.processors.shp import ShapefileProcessor
from src.processors.siri import SiriProcessor
from src.spatial.classifier import ProvincialClassifier
from src.storage.supabase_storage import SupabaseStorageService
from src.utils.logging import logger


class IngestionPipeline:
    """End-to-end automated ingestion coordinator for all 35 Moveuskadi operators."""

    def __init__(self):
        self.discovery_service = CatalogueDiscoveryService()
        self.download_manager = DownloadManager()
        self.storage_service = SupabaseStorageService()
        self.gtfs_processor = GTFSStaticProcessor()
        self.gtfs_rt_processor = GTFSRealtimeProcessor()
        self.siri_processor = SiriProcessor()
        self.netex_processor = NetexProcessor()
        self.shp_processor = ShapefileProcessor()
        self.spatial_classifier = ProvincialClassifier()

    def run_catalogue_discovery(self) -> Dict[str, Any]:
        """Runs dynamic discovery on the Moveuskadi JSON index."""
        logger.info("Starting automated catalogue discovery job...")
        job_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        snapshot, operator_catalogs = self.discovery_service.fetch_catalogue()

        # Archive snapshot in Supabase Storage
        snapshot_bytes = snapshot.model_dump_json(indent=2).encode("utf-8")
        storage_url = self.storage_service.upload_catalogue_snapshot(snapshot_bytes, snapshot.checksum)

        # Upsert operators and resources into database
        persisted_ops = 0
        persisted_res = 0

        try:
            with get_db_session() as session:
                # Record snapshot
                session.execute(
                    text("""
                        INSERT INTO public.catalogue_snapshots (
                            id, catalogue_url, catalogue_last_update, total_operators,
                            total_resources, checksum, raw_payload, status
                        ) VALUES (
                            :id, :url, :last_upd, :tot_op, :tot_res, :chk, :payload::jsonb, 'processed'
                        );
                    """),
                    {
                        "id": job_id,
                        "url": snapshot.catalogue_url,
                        "last_upd": snapshot.catalogue_last_update,
                        "tot_op": snapshot.total_operators,
                        "tot_res": snapshot.total_resources,
                        "chk": snapshot.checksum,
                        "payload": snapshot.model_dump_json()
                    }
                )

                for clean_name, op in operator_catalogs.items():
                    # Upsert operator
                    op_id = str(uuid.uuid4())
                    res = session.execute(
                        text("""
                            INSERT INTO public.transport_operators (
                                id, original_name, normalized_name, slug,
                                available_formats, is_active, last_catalogue_seen_at
                            ) VALUES (
                                :id, :orig_name, :norm_name, :slug,
                                :formats, true, now()
                            )
                            ON CONFLICT (original_name) DO UPDATE SET
                                normalized_name = excluded.normalized_name,
                                slug = excluded.slug,
                                available_formats = excluded.available_formats,
                                is_active = true,
                                last_catalogue_seen_at = now()
                            RETURNING id;
                        """),
                        {
                            "id": op_id,
                            "orig_name": op.original_name,
                            "norm_name": op.normalized_name,
                            "slug": op.slug,
                            "formats": op.available_formats
                        }
                    )
                    actual_op_id = res.scalar() or op_id
                    persisted_ops += 1

                    # Upsert resources
                    for res_item in op.resources:
                        session.execute(
                            text("""
                                INSERT INTO public.catalogue_resources (
                                    id, operator_id, format, name, url,
                                    catalogue_last_update, is_active, last_discovered_at
                                ) VALUES (
                                    gen_random_uuid(), :op_id, :fmt, :name, :url,
                                    :cat_upd, true, now()
                                )
                                ON CONFLICT (operator_id, url) DO UPDATE SET
                                    format = excluded.format,
                                    name = excluded.name,
                                    catalogue_last_update = excluded.catalogue_last_update,
                                    is_active = true,
                                    last_discovered_at = now();
                            """),
                            {
                                "op_id": actual_op_id,
                                "fmt": res_item.format,
                                "name": res_item.name,
                                "url": res_item.url,
                                "cat_upd": res_item.last_update
                            }
                        )
                        persisted_res += 1

            logger.info(f"Discovery job completed: {persisted_ops} operators, {persisted_res} resources.")
            return {
                "job_id": job_id,
                "status": "success",
                "operators_discovered": len(operator_catalogs),
                "resources_discovered": snapshot.total_resources,
                "storage_snapshot_url": storage_url
            }

        except Exception as e:
            logger.error(f"Discovery database persistence error: {e}")
            return {
                "job_id": job_id,
                "status": "partial_success",
                "error": str(e),
                "operators_discovered": len(operator_catalogs),
                "resources_discovered": snapshot.total_resources
            }

    def sync_operator_gtfs_static(self, operator_name: str, resource_url: str) -> Dict[str, Any]:
        """Downloads and processes a single GTFS static archive safely."""
        logger.info(f"Starting GTFS Static sync for operator: {operator_name} ({resource_url})")
        feed_version_id = str(uuid.uuid4())
        operator_slug = self.discovery_service.discover_index_url()

        # 1. Download archive
        filename = os.path.basename(resource_url.split("?")[0])
        dl_res = self.download_manager.download_resource(
            url=resource_url,
            target_filename=filename,
            expected_format="GTFS",
            subfolder=f"gtfs_static/{filename[:10]}"
        )

        if not dl_res.success:
            return {"status": "failed", "error": dl_res.error_message}

        # 2. Archive raw download in Supabase Storage
        storage_url = self.storage_service.upload_raw_resource(
            local_path=dl_res.file_path,
            operator_slug=filename.replace(".zip", ""),
            filename=filename
        )

        # 3. Process GTFS with validation
        context = {
            "feed_version_id": feed_version_id,
            "operator_id": str(uuid.uuid4()),
            "persist_to_db": False  # Handled safely via feed version activation
        }
        report = self.gtfs_processor.process(dl_res.file_path, context)

        return {
            "status": report.status,
            "feed_version_id": feed_version_id,
            "records_processed": report.to_dict(),
            "storage_url": storage_url,
            "checksum": dl_res.checksum
        }

    def sync_operator_realtime(self, operator_id: str, resource_url: str, format_type: str) -> Dict[str, Any]:
        """Downloads and ingests GTFS-RT Protobuf or SIRI XML observations."""
        filename = os.path.basename(resource_url.split("?")[0])
        dl_res = self.download_manager.download_resource(
            url=resource_url,
            target_filename=f"rt_{filename}",
            expected_format=format_type,
            subfolder="realtime"
        )

        if not dl_res.success:
            return {"status": "failed", "error": dl_res.error_message}

        context = {
            "operator_id": operator_id,
            "persist_to_db": False
        }

        if format_type == "GTFS-RT":
            report = self.gtfs_rt_processor.process(dl_res.file_path, context)
        elif format_type == "SIRI":
            report = self.siri_processor.process(dl_res.file_path, context)
        else:
            return {"status": "unsupported_format", "format": format_type}

        return {
            "status": report.status,
            "format": format_type,
            "metrics": report.metrics,
            "valid_records": report.valid_records
        }

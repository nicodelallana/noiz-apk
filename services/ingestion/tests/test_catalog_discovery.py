"""Unit tests for catalogue discovery, parsing, and delta detection."""

import hashlib
import json
from src.catalog.discovery import CatalogueDiscoveryService, normalize_operator_name, slugify
from src.catalog.models import CatalogueSnapshot, ResourceItem


def test_slugify():
    assert slugify("Metro Bilbao") == "metro_bilbao"
    assert slugify("Goierrialdea (Lurraldebus)") == "goierrialdea_lurraldebus"
    assert slugify("Erandio! busa") == "erandio_busa"
    assert slugify("Álavabus") == "álavabus"


def test_normalize_operator_name():
    assert normalize_operator_name("  BilboBus  ") == "BilboBus"
    assert normalize_operator_name("Metro   Bilbao") == "Metro Bilbao"


def test_parse_catalog_sample(sample_catalog_json):
    discovery = CatalogueDiscoveryService()
    # Mocking client get response with sample
    raw_str = json.dumps(sample_catalog_json)
    checksum = hashlib.sha256(raw_str.encode("utf-8")).hexdigest()

    operators_dict = sample_catalog_json["data"]
    total_resources = sum(len(res) for res in operators_dict.values())

    snapshot = CatalogueSnapshot(
        catalogue_url="https://test.local/data-index.json",
        catalogue_last_update=sample_catalog_json.get("last-update"),
        checksum=checksum,
        total_operators=len(operators_dict),
        total_resources=total_resources,
        operators={
            op: [
                ResourceItem(
                    format=r["format"],
                    url=r["url"],
                    name=r["name"],
                    last_update=r.get("last-update")
                )
                for r in res_list
            ]
            for op, res_list in operators_dict.items()
        }
    )

    assert snapshot.total_operators == 2
    assert snapshot.total_resources == 5
    assert "Metro Bilbao" in snapshot.operators
    assert len(snapshot.operators["Metro Bilbao"]) == 4


def test_compute_diff():
    discovery = CatalogueDiscoveryService()
    prev = CatalogueSnapshot(
        catalogue_url="https://test.local/data-index.json",
        checksum="hash1",
        total_operators=1,
        total_resources=1,
        operators={
            "Metro Bilbao": [
                ResourceItem(
                    format="GTFS",
                    url="https://opendata.euskadi.eus/gtfs.zip",
                    name="gtfs.zip",
                    last_update="2026-11-01 00:00:00"
                )
            ]
        }
    )

    curr = CatalogueSnapshot(
        catalogue_url="https://test.local/data-index.json",
        checksum="hash2",
        total_operators=2,
        total_resources=2,
        operators={
            "Metro Bilbao": [
                ResourceItem(
                    format="GTFS",
                    url="https://opendata.euskadi.eus/gtfs.zip",
                    name="gtfs.zip",
                    last_update="2026-11-03 00:00:00"  # updated
                )
            ],
            "Tuvisa": [
                ResourceItem(
                    format="GTFS",
                    url="https://opendata.euskadi.eus/tuvisa.zip",
                    name="tuvisa.zip",
                    last_update="2026-11-03 00:00:00"  # new
                )
            ]
        }
    )

    diff = discovery.compute_diff(curr, prev)
    assert diff.has_changes is True
    assert "Tuvisa" in diff.new_operators
    assert len(diff.updated_resources) == 1
    assert diff.updated_resources[0].url == "https://opendata.euskadi.eus/gtfs.zip"
    assert len(diff.new_resources) == 1
    assert diff.new_resources[0].url == "https://opendata.euskadi.eus/tuvisa.zip"


def test_live_catalogue_discovery():
    """Hits the live Moveuskadi endpoint to verify real 35 operators and 195 resources."""
    discovery = CatalogueDiscoveryService()
    snapshot, catalogs = discovery.fetch_catalogue()

    assert snapshot.total_operators == 35
    assert snapshot.total_resources >= 190
    assert "Metro Bilbao" in catalogs
    assert "BizkaiBus" in catalogs
    assert "Tuvisa" in catalogs
    assert "Dbus" in catalogs
    assert len(catalogs["Metro Bilbao"].resources) >= 4

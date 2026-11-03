"""Test configuration and shared fixtures."""

import os
import sys
import pytest

# Add services/ingestion to sys.path so tests import src.* cleanly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


@pytest.fixture
def sample_catalog_json():
    """Returns a representative Moveuskadi catalog sample."""
    return {
        "last-update": "2026-11-03 10:14:30",
        "data": {
            "Metro Bilbao": [
                {
                    "format": "GTFS",
                    "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfs_metro_bilbao.zip",
                    "name": "gtfs_metro_bilbao.zip",
                    "last-update": "2026-11-03 07:01:16"
                },
                {
                    "format": "GTFS-RT",
                    "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfsrt_metro_bilbao_vehicle_positions.pb",
                    "name": "gtfsrt_metro_bilbao_vehicle_positions.pb",
                    "last-update": "2026-11-03 10:14:27"
                },
                {
                    "format": "SIRI",
                    "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/siri_metro_bilbao_situation_exchange.xml",
                    "name": "siri_metro_bilbao_situation_exchange.xml",
                    "last-update": "2026-11-03 10:14:27"
                },
                {
                    "format": "NETEX",
                    "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/netex_metro_bilbao.zip",
                    "name": "netex_metro_bilbao.zip",
                    "last-update": "2026-11-03 07:01:17"
                }
            ],
            "Errenteria Urbanoa": [
                {
                    "format": "GTFS-RT",
                    "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
                    "name": "gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
                    "last-update": "2026-11-03 09:27:17"
                }
            ]
        }
    }

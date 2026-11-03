"""Unit tests for GTFS-Realtime Protocol Buffers decoding and extraction."""

import os
import tempfile
from google.transit import gtfs_realtime_pb2
from src.processors.gtfs_realtime import GTFSRealtimeProcessor


def test_synthetic_gtfs_rt_vehicle_positions():
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.header.gtfs_realtime_version = "2.0"
    feed.header.timestamp = 1793697000

    entity = feed.entity.add()
    entity.id = "V1"
    entity.vehicle.trip.trip_id = "TRIP_100"
    entity.vehicle.trip.route_id = "R1"
    entity.vehicle.vehicle.id = "VEH_501"
    entity.vehicle.position.latitude = 43.2625
    entity.vehicle.position.longitude = -2.9475
    entity.vehicle.timestamp = 1793697000

    with tempfile.NamedTemporaryFile(suffix=".pb", delete=False) as f:
        f.write(feed.SerializeToString())
        pb_path = f.name

    try:
        processor = GTFSRealtimeProcessor()
        report = processor.process(pb_path, context={"operator_id": "test_op"})
        assert report.status == "passed"
        assert report.metrics["vehicles_parsed"] == 1
        assert report.valid_records == 1
    finally:
        if os.path.exists(pb_path):
            os.remove(pb_path)


def test_corrupt_gtfs_rt():
    with tempfile.NamedTemporaryFile(suffix=".pb", delete=False) as f:
        f.write(b"this is definitely not protobuf data")
        pb_path = f.name

    try:
        processor = GTFSRealtimeProcessor()
        report = processor.process(pb_path, context={"operator_id": "test_op"})
        assert report.status == "failed"
    finally:
        if os.path.exists(pb_path):
            os.remove(pb_path)


def test_live_metro_bilbao_gtfs_rt():
    """Downloads and decodes live Metro Bilbao vehicle positions."""
    from src.downloader.manager import DownloadManager
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir)
        url = "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfsrt_metro_bilbao_vehicle_positions.pb"
        dl = dm.download_resource(url, "metro_vp.pb", "GTFS-RT")
        assert dl.success is True

        processor = GTFSRealtimeProcessor()
        report = processor.process(dl.file_path, context={"operator_id": "metro_op"})
        assert report.status in ("passed", "warnings")
        assert report.metrics["entity_count"] > 0
        assert report.metrics["vehicles_parsed"] > 0

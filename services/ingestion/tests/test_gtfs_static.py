"""Unit tests for GTFS Static validation and processing."""

import io
import os
import tempfile
import zipfile
from src.processors.gtfs_static import GTFSStaticProcessor


def create_synthetic_gtfs_zip(dest_path: str, corrupt: bool = False):
    """Creates a minimal valid or corrupt GTFS archive for testing."""
    with zipfile.ZipFile(dest_path, "w") as z:
        if corrupt:
            z.writestr("notes.txt", "not a real gtfs feed")
            return

        z.writestr(
            "agency.txt",
            "agency_id,agency_name,agency_url,agency_timezone\n"
            "AG1,Metro Test,https://metro.local,Europe/Madrid\n"
        )
        z.writestr(
            "stops.txt",
            "stop_id,stop_name,stop_lat,stop_lon\n"
            "S1,Casco Viejo,43.2590,-2.9220\n"
            "S2,Moyua,43.2630,-2.9348\n"
            "S_BAD,Bad Point,10.0,10.0\n"
        )
        z.writestr(
            "routes.txt",
            "route_id,route_short_name,route_long_name,route_type\n"
            "R1,L1,Plentzia - Etxebarri,1\n"
        )
        z.writestr(
            "trips.txt",
            "route_id,service_id,trip_id,trip_headsign\n"
            "R1,WD,T1,Plentzia\n"
        )
        z.writestr(
            "stop_times.txt",
            "trip_id,arrival_time,departure_time,stop_id,stop_sequence\n"
            "T1,07:00:00,07:00:00,S1,1\n"
            "T1,07:05:00,07:05:00,S2,2\n"
        )


def test_synthetic_gtfs_validation():
    with tempfile.TemporaryDirectory() as tmpdir:
        zip_path = os.path.join(tmpdir, "gtfs.zip")
        create_synthetic_gtfs_zip(zip_path, corrupt=False)

        processor = GTFSStaticProcessor()
        report = processor.process(zip_path, context={"feed_version_id": "test_ver_1"})

        assert report.status in ("passed", "warnings")
        assert report.metrics["stops_count"] == 2  # S_BAD rejected due to coordinates (10, 10)
        assert report.metrics["routes_count"] == 1
        assert report.metrics["trips_count"] == 1
        assert report.metrics["stop_times_count"] == 2
        assert report.rejected_records == 1  # 1 rejected out-of-bounds stop


def test_corrupt_gtfs_missing_required_files():
    with tempfile.TemporaryDirectory() as tmpdir:
        zip_path = os.path.join(tmpdir, "corrupt.zip")
        create_synthetic_gtfs_zip(zip_path, corrupt=True)

        processor = GTFSStaticProcessor()
        report = processor.process(zip_path, context={"feed_version_id": "test_ver_2"})

        assert report.status == "failed"
        assert len(report.errors) > 0


def test_live_gtfs_processing():
    """Downloads and validates a real GTFS package from Open Data Euskadi (Metro Bilbao or Funicular Artxanda)."""
    from src.downloader.manager import DownloadManager
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir)
        # Download Funicular Artxanda (lightweight GTFS)
        url = "https://opendata.euskadi.eus/transport/moveuskadi/funicular_artxanda/gtfs_funicular_artxanda.zip"
        dl = dm.download_resource(url, "artxanda.zip", "GTFS")
        assert dl.success is True

        processor = GTFSStaticProcessor()
        report = processor.process(dl.file_path, context={"feed_version_id": "artxanda_v1"})
        assert report.status in ("passed", "warnings")
        assert report.metrics["stops_count"] >= 2
        assert report.metrics["routes_count"] >= 1

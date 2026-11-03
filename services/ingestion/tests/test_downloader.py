"""Unit tests for robust download manager and URL sanitization."""

import os
import tempfile
from src.downloader.manager import DownloadManager, sanitize_url


def test_sanitize_url_spaces():
    raw = "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/gtfsrt_errenteriako urbanoa_vehicle_positions.pb"
    sanitized = sanitize_url(raw)
    assert "%20" in sanitized
    assert "errenteriako%20urbanoa" in sanitized


def test_download_failure_404():
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir, max_retries=1)
        res = dm.download_resource(
            url="https://opendata.euskadi.eus/transport/non_existent_file.zip",
            target_filename="not_found.zip",
            expected_format="GTFS"
        )
        assert res.success is False
        assert res.error_message is not None


def test_download_real_gtfs_rt_pb():
    """Downloads a live real GTFS-RT pb file from Metro Bilbao."""
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir, max_retries=2)
        url = "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfsrt_metro_bilbao_vehicle_positions.pb"
        res = dm.download_resource(
            url=url,
            target_filename="metro_rt.pb",
            expected_format="GTFS-RT"
        )
        assert res.success is True
        assert res.file_size_bytes > 0
        assert res.checksum is not None
        assert os.path.exists(res.file_path)

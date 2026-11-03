"""Unit tests for NeTEx XML/Zip processor."""

import os
import tempfile
import zipfile
from src.processors.netex import NetexProcessor

SAMPLE_NETEX_XML = """<?xml version="1.0" encoding="UTF-8"?>
<PublicationDelivery xmlns="http://www.netex.org.uk/netex" version="1.0">
  <dataObjects>
    <SiteFrame>
      <stopPlaces>
        <ScheduledStopPoint id="SP_1">
          <Name>Abando</Name>
        </ScheduledStopPoint>
        <ScheduledStopPoint id="SP_2">
          <Name>San Mames</Name>
        </ScheduledStopPoint>
      </stopPlaces>
    </SiteFrame>
    <ServiceFrame>
      <lines>
        <Line id="L_MB">
          <Name>Metro Bilbao</Name>
        </Line>
      </lines>
      <routes>
        <Route id="R_1">
          <Name>L1 Etxebarri - Plentzia</Name>
        </Route>
      </routes>
    </ServiceFrame>
  </dataObjects>
</PublicationDelivery>
"""


def test_synthetic_netex_parsing():
    with tempfile.TemporaryDirectory() as tmpdir:
        zip_path = os.path.join(tmpdir, "netex.zip")
        with zipfile.ZipFile(zip_path, "w") as z:
            z.writestr("lines.xml", SAMPLE_NETEX_XML)

        processor = NetexProcessor()
        report = processor.process(zip_path, context={"operator_id": "test_op"})
        assert report.status == "passed"
        assert report.metrics["netex_stops"] == 2
        assert report.metrics["netex_lines"] == 1
        assert report.metrics["netex_routes"] == 1


def test_live_netex_feed():
    """Downloads and inspects real NeTEx archive from Metro Bilbao."""
    from src.downloader.manager import DownloadManager
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir)
        url = "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/netex_metro_bilbao.zip"
        dl = dm.download_resource(url, "metro_netex.zip", "NETEX")
        assert dl.success is True

        processor = NetexProcessor()
        report = processor.process(dl.file_path, context={"operator_id": "metro_op"})
        assert report.status in ("passed", "warnings")

"""Unit tests for SIRI XML processor."""

import os
import tempfile
from src.processors.siri import SiriProcessor

SAMPLE_SIRI_XML = """<?xml version="1.0" encoding="UTF-8"?>
<Siri xmlns="http://www.siri.org.uk/siri" version="2.0">
  <ServiceDelivery>
    <ResponseTimestamp>2026-11-03T10:14:27Z</ResponseTimestamp>
    <VehicleMonitoringDelivery>
      <VehicleActivity>
        <RecordedAtTime>2026-11-03T10:14:25Z</RecordedAtTime>
        <VehicleMonitoringRef>VM1</VehicleMonitoringRef>
        <MonitoredVehicleJourney>
          <LineRef>L1</LineRef>
          <DirectionRef>1</DirectionRef>
          <VehicleRef>BUS_202</VehicleRef>
          <VehicleLocation>
            <Longitude>-2.9348</Longitude>
            <Latitude>43.2630</Latitude>
          </VehicleLocation>
        </MonitoredVehicleJourney>
      </VehicleActivity>
    </VehicleMonitoringDelivery>
    <SituationExchangeDelivery>
      <PtSituationElement>
        <SituationNumber>SIT_001</SituationNumber>
        <Summary>Obras en Gran Via</Summary>
        <Description>Desvio de linea por obras</Description>
      </PtSituationElement>
    </SituationExchangeDelivery>
  </ServiceDelivery>
</Siri>
"""


def test_synthetic_siri_parsing():
    with tempfile.NamedTemporaryFile(suffix=".xml", mode="w", delete=False) as f:
        f.write(SAMPLE_SIRI_XML)
        xml_path = f.name

    try:
        processor = SiriProcessor()
        report = processor.process(xml_path, context={"operator_id": "test_op"})
        assert report.status == "passed"
        assert report.metrics["siri_vehicles"] == 1
        assert report.metrics["siri_situations"] == 1
    finally:
        if os.path.exists(xml_path):
            os.remove(xml_path)


def test_malformed_siri_xml():
    with tempfile.NamedTemporaryFile(suffix=".xml", mode="w", delete=False) as f:
        f.write("<Siri><unclosed_tag>")
        xml_path = f.name

    try:
        processor = SiriProcessor()
        report = processor.process(xml_path, context={"operator_id": "test_op"})
        assert report.status == "failed"
        assert len(report.errors) > 0
    finally:
        if os.path.exists(xml_path):
            os.remove(xml_path)


def test_live_siri_feed_parsing():
    """Downloads and parses a real SIRI feed from Metro Bilbao or Bizkaibus."""
    from src.downloader.manager import DownloadManager
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir)
        url = "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/siri_metro_bilbao_situation_exchange.xml"
        dl = dm.download_resource(url, "metro_siri.xml", "SIRI")
        assert dl.success is True

        processor = SiriProcessor()
        report = processor.process(dl.file_path, context={"operator_id": "metro_op"})
        assert report.status in ("passed", "warnings")

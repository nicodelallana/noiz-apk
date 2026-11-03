# Developer Guide: Extending Formats & Processors

How to add new transport formats, custom operator adapters, or telemetry decoders to the Moveuskadi ingestion engine.

---

## 1. Architectural Extension Points

The ingestion engine is modular and format-decoupled:

```text
src/processors/
├── base.py             # Defines BaseProcessor & ValidationReport
├── gtfs_static.py      # Format: GTFS
├── gtfs_realtime.py    # Format: GTFS-RT
├── siri.py             # Format: SIRI
├── netex.py            # Format: NETEX
└── shp.py              # Format: SHP
```

To support a new format (e.g., `GBFS` for shared bicycles or `MDS` for micromobility):
1. Subclass `BaseProcessor` in `src/processors/`.
2. Implement the `process(file_path: str, context: dict) -> ValidationReport` method.
3. Register the new processor in `IngestionPipeline` (`src/normalizer/pipeline.py`).

---

## 2. Implementing a Custom Processor

Create `src/processors/gbfs.py`:

```python
import json
from typing import Any, Dict
from src.processors.base import BaseProcessor, ValidationReport, ValidationError
from src.utils.logging import logger

class GBFSProcessor(BaseProcessor):
    """Processes General Bikeshare Feed Specification JSON files."""

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="GBFS")
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            stations = data.get("data", {}).get("stations", [])
            report.total_records = len(stations)

            for station in stations:
                lat = station.get("lat")
                lon = station.get("lon")
                if lat and lon and (41.0 <= lat <= 44.5 and -4.5 <= lon <= -1.0):
                    report.valid_records += 1
                else:
                    report.rejected_records += 1

            report.metrics["station_count"] = report.valid_records
            report.mark_completed()
            return report
        except Exception as e:
            report.rejected_records += 1
            report.errors.append(ValidationError("gbfs_json", file_path, str(e)))
            report.mark_completed("failed")
            return report
```

---

## 3. Registering the Processor in the Pipeline

In `src/normalizer/pipeline.py`:

```python
from src.processors.gbfs import GBFSProcessor

class IngestionPipeline:
    def __init__(self):
        # ...
        self.gbfs_processor = GBFSProcessor()

    def route_resource(self, format_type: str, file_path: str, context: dict):
        if format_type == "GBFS":
            return self.gbfs_processor.process(file_path, context)
        # ...
```

---

## 4. Writing Unit & Integration Tests

Create `tests/test_gbfs.py` following the pytest conventions in `tests/`:

```python
import tempfile
import json
from src.processors.gbfs import GBFSProcessor

def test_gbfs_processing():
    sample = {
        "data": {
            "stations": [
                {"station_id": "1", "name": "Bilbao Bizi 1", "lat": 43.26, "lon": -2.93}
            ]
        }
    }
    with tempfile.NamedTemporaryFile(suffix=".json", mode="w") as f:
        json.dump(sample, f)
        f.flush()
        proc = GBFSProcessor()
        report = proc.process(f.name, context={})
        assert report.status == "passed"
        assert report.valid_records == 1
```

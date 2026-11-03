# Automated Euskadi Public Transport Data Platform (Ingestion Engine)

Production-ready, format-aware, fully automated transit data ingestion, provincial classification, and real-time processing engine for the Basque Country (Euskadi), Spain.

Integrates all **35 transport operators** and **195 data resources** published through Open Data Euskadi / Moveuskadi across **Bizkaia**, **Gipuzkoa**, and **Araba / Álava**.

---

## 1. Key Capabilities

- **Zero Manual Downloads:** Dynamically polls the authoritative Moveuskadi JSON catalogue (`data-index.json`). Discovers new operators and resources automatically without code changes.
- **Multi-Format Processing:**
  - **GTFS Static:** Automated ZIP integrity check, CSV parsing with BOM handling, referential validation, and atomic staging.
  - **GTFS-Realtime (GTFS-RT):** Protocol Buffers decoding (`google.transit.gtfs_realtime_pb2`) for Vehicle Positions, Trip Updates, and Service Alerts.
  - **SIRI XML:** Secure parsing (`defusedxml`) of VehicleMonitoring, EstimatedTimetable, and SituationExchange with full namespace support.
  - **NeTEx:** Safe ZIP decompression and XML extraction of ScheduledStopPoints, Lines, and Routes.
  - **SHP / GeoEuskadi:** Coordinate transformation from ETRS89 UTM 30N (EPSG:25830) to WGS84 (EPSG:4326).
- **Collision-Proof Relational Model:** Prevents cross-operator identifier collisions using source namespaces: `(feed_version_id, external_id)` and internal UUID primary keys.
- **Authoritative Provincial Classification:** Uses PostGIS `ST_Contains` and official GeoEuskadi territorial boundary polygons (Bizkaia `48`, Gipuzkoa `20`, Araba `01`) to classify stops and derive multi-province route relationships.
- **Safe Publication:** Isolates incoming feeds in versioned staging sets. Fails gracefully without corrupting or destroying previous active production data.
- **Supabase Storage Integration:** Uploads snapshots and raw versioned packages to `moveuskadi/` storage bucket hierarchy.
- **Automated Scheduling:** APScheduler background execution with configurable intervals (15m catalogue, 6h static, 20s vehicle positions, 45s trip updates, 2m alerts).
- **Monitoring API:** FastAPI server with healthchecks (`/health`), live operator inventory (`/operators`), and manual trigger endpoints.

---

## 2. Directory Structure

```text
services/ingestion/
├── Dockerfile                  # Container build with libpq, GEOS, and Proj
├── docker-compose.yml          # Containerized deployment specification
├── requirements.txt            # Python dependencies
├── pyproject.toml              # Project metadata & CLI script entrypoints
├── .env.example                # Template environment variables
├── README.md                   # This documentation
├── src/
│   ├── config.py               # Pydantic Settings & environment discovery
│   ├── cli.py                  # Command-line interface
│   ├── utils/
│   │   └── logging.py          # Structured JSON logging
│   ├── catalog/
│   │   ├── models.py           # Pydantic models for catalog, operators, and diffs
│   │   └── discovery.py        # Dynamic index fetcher & delta detection
│   ├── downloader/
│   │   └── manager.py          # Resilient HTTP client with backoff & validation
│   ├── storage/
│   │   └── supabase_storage.py # Supabase Storage upload & archive manager
│   ├── db/
│   │   ├── connection.py       # SQLAlchemy engine pool & healthcheck
│   │   └── models.py           # Relational & PostGIS ORM entities
│   ├── processors/
│   │   ├── base.py             # BaseProcessor, ValidationReport, ValidationError
│   │   ├── gtfs_static.py      # GTFS static parser & referential validator
│   │   ├── gtfs_realtime.py    # GTFS-RT Protobuf telemetry decoder
│   │   ├── siri.py             # SIRI XML parser with defusedxml
│   │   ├── netex.py            # NeTEx ZIP & XML parser
│   │   └── shp.py              # Shapefile processor & ETRS89->WGS84 transformer
│   ├── spatial/
│   │   └── classifier.py       # Point-in-polygon provincial classifier
│   ├── normalizer/
│   │   └── pipeline.py         # End-to-end orchestration pipeline
│   ├── scheduler/
│   │   └── runner.py           # Automated APScheduler background runner
│   └── api/
│       └── app.py              # FastAPI monitoring server
└── tests/
    ├── conftest.py             # Fixtures & sample feeds
    ├── test_catalog_discovery.py
    ├── test_downloader.py
    ├── test_gtfs_static.py
    ├── test_gtfs_rt.py
    ├── test_siri.py
    ├── test_netex.py
    ├── test_shp_and_spatial.py
    └── test_collision_and_safety.py
```

---

## 3. Quick Start (Local Development)

### 3.1. Prerequisites
- Python 3.11+
- PostgreSQL 15+ with PostGIS extension enabled

### 3.2. Setup Environment
```bash
cd services/ingestion
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

### 3.3. Run CLI Commands

1. **Discover all Moveuskadi Operators & Resources:**
   ```bash
   python -m src.cli discover
   ```
   *Output:*
   ```text
   Moveuskadi Discovered Operators (35 Operators, 195 Resources)
   ├── Metro Bilbao (GTFS, GTFS-RT, NETEX, SIRI)
   ├── BizkaiBus (GTFS, GTFS-RT, NETEX, SIRI)
   ├── Tuvisa (GTFS, GTFS-RT, NETEX)
   └── ...
   ```

2. **Download & Import GeoEuskadi Territorial Boundaries:**
   ```bash
   python -m src.cli import-boundaries
   ```

3. **Start Monitoring API & Automated Scheduler:**
   ```bash
   python -m src.cli run-all
   ```
   The API will be accessible at `http://localhost:8000/docs`.

### 3.4. Run Test Suite
```bash
python -m pytest -v
```
All 22 test suites will run, testing live catalog discovery, real Protobuf decoding, XML parsing, coordinate transformation, and spatial containment.

---

## 4. Docker Deployment

### 4.1. Build & Run with Docker Compose
```bash
docker compose up --build -d
```

### 4.2. Verify Health
```bash
curl http://localhost:8000/health
```
*Expected response:*
```json
{
  "status": "healthy",
  "service": "moveuskadi-ingestion",
  "database_connected": true,
  "scheduler_running": true
}
```

---

## 5. Security & Production Hardening

1. **Untrusted Input Protection:**
   - All downloaded archives are scanned for directory traversal (Zip Slip protection).
   - All XML parsing is executed via `defusedxml` to block XXE attacks and quadratic entity expansion.
   - HTTP responses undergo MIME and magic byte signature verification before parsing.
2. **Database Isolation:**
   - Supabase Row Level Security (RLS) is enabled on 100% of tables.
   - Public users can only read `active` feeds and current vehicle telemetry.
   - Ingestion worker uses `service_role` credentials exclusively.
3. **Safe Feed Activation:**
   - Imports stage into an isolated `feed_version_id`.
   - The stored procedure `activate_feed_version(feed_id)` atomically deactivates the previous version and promotes the new version only when validation passes.

# Tasks: Automated Euskadi Public Transport Data Platform

## Phase 1: Database Schema & PostGIS Setup
- [ ] 1.1 Create Supabase SQL migration `20261103000000_automated_transport_platform.sql` with PostGIS extension, geography tables, operators, catalogue metadata, feed versions, GTFS static, real-time, SIRI/NeTEx tables, RLS policies, indexes, and stored procedures.
- [ ] 1.2 Seed official provinces (Bizkaia 48, Gipuzkoa 20, Araba/Álava 01) and transport modes (bus, metro, train, tram, funicular, ferry, cable).
- [ ] 1.3 Implement atomic activation and rollback SQL functions (`activate_feed_version`, `classify_stops_provinces`).

## Phase 2: Ingestion Engine Project Foundation
- [ ] 2.1 Set up `services/ingestion/` directory structure with `requirements.txt`, `pyproject.toml`, Dockerfile, docker-compose.yml, and `.env.example`.
- [ ] 2.2 Implement configuration management (`src/config.py`) with environment variables, timeouts, rate limits, and catalogue endpoints.
- [ ] 2.3 Implement structured JSON logging and exception tracing (`src/utils/logging.py`).
- [ ] 2.4 Set up database connection pool and Supabase Storage client integration (`src/db/` and `src/storage/`).

## Phase 3: Catalogue Discovery & Download Manager
- [ ] 3.1 Implement dynamic catalogue discovery service (`src/catalog/discovery.py`) fetching `data-index.json`, parsing all 35 operators and 195 resources, computing checksums, and registering operators.
- [ ] 3.2 Implement robust HTTP download manager (`src/downloader/manager.py`) with exponential backoff, retry limits, temporary files, atomic staging, and SHA-256 validation.
- [ ] 3.3 Implement Supabase Storage uploader for snapshots and raw archives.

## Phase 4: GTFS Static Processor & Validation
- [ ] 4.1 Implement GTFS static zip processor (`src/processors/gtfs_static.py`) extracting and parsing agency, stops, routes, trips, stop_times, calendar, calendar_dates, shapes, frequencies, transfers, and fare files.
- [ ] 4.2 Enforce source namespacing `(feed_version_id, operator_id, external_id)` to avoid cross-operator identifier collisions.
- [ ] 4.3 Implement structural and referential GTFS validation engine (`src/processors/base.py` / `src/processors/gtfs_static.py`).

## Phase 5: Spatial Classification with PostGIS
- [ ] 5.1 Implement GeoEuskadi boundary importer (`src/processors/shp.py`) converting `TERRITORIOS_5000_ETRS89` shapefile from EPSG:25830 to EPSG:4326 and persisting polygons in PostGIS.
- [ ] 5.2 Implement spatial classifier (`src/spatial/classifier.py`) executing point-in-polygon assignment for stops and multi-province derivation for routes.

## Phase 6: GTFS-Realtime Protobuf Processor
- [ ] 6.1 Implement GTFS-RT Protobuf processor (`src/processors/gtfs_realtime.py`) for Vehicle Positions, Trip Updates, and Service Alerts.
- [ ] 6.2 Match real-time vehicles and trips to static feeds using operator scoping.
- [ ] 6.3 Implement observation deduplication and pruning retention policy.

## Phase 7: SIRI & NeTEx Processors
- [ ] 7.1 Implement SIRI XML processor (`src/processors/siri.py`) parsing VehicleMonitoring, EstimatedTimetable, and SituationExchange with defused XML.
- [ ] 7.2 Implement NeTEx processor (`src/processors/netex.py`) parsing scheduled stops, lines, and routes.

## Phase 8: Automation, Scheduler, API & Monitoring
- [ ] 8.1 Implement APScheduler background task runner (`src/scheduler/runner.py`) with configurable cadence (15m catalogue, 6h static, 20s vehicle positions, 45s trip updates, 2m alerts).
- [ ] 8.2 Implement FastAPI monitoring dashboard (`src/api/app.py`) exposing `/health`, `/metrics`, `/operators`, `/jobs`, and `/trigger`.
- [ ] 8.3 Write unit and integration test suite (`services/ingestion/tests/`) covering discovery, downloads, parsers, spatial classification, and error resilience.
- [ ] 8.4 Write comprehensive documentation:
  - `docs/automated-platform-architecture.md`
  - `docs/licencias-datos.md`
  - `docs/recovery-and-troubleshooting.md`
  - `docs/extending-formats.md`

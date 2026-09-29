# Tasks: gtfs-pipeline

## 1. ETL Compiler Engine (`tools/build_gtfs/`)

- [ ] 1.1 Create `tools/build_gtfs/build_transit_db.py` to download verified static GTFS ZIPs with `If-Modified-Since` headers.
- [ ] 1.2 Implement SQLite schema creation and table extraction for operators, routes, stops, trips, stop_times, calendar, and calendar_dates in `tools/build_gtfs/build_transit_db.py`.
- [ ] 1.3 Implement Metro Bilbao L1/L2 route classification heuristic in `tools/build_gtfs/build_transit_db.py` based on served station sets.
- [ ] 1.4 Implement database indexing (`idx_stop_times_lookup`, `idx_trips_service`), gzip compression (`transit.sqlite.gz`), and SHA-256 `manifest.json` generation.
- [ ] 1.5 Run `python3 tools/build_gtfs/build_transit_db.py` locally against Metro Bilbao GTFS to verify database generation, table counts, and query performance.

## 2. Supabase Storage Migration

- [ ] 2.1 Create SQL migration `supabase/migrations/20260929000001_transit_storage_bucket.sql` establishing the public `transit-packs` bucket with public read-only access policies.

## 3. Nightly Pipeline & Keep-Alive Automation

- [ ] 3.1 Create GitHub Actions workflow `.github/workflows/build-gtfs.yml` running on nightly schedule (`0 2 * * *`) to compile feeds, upload artifacts, and execute the Supabase keep-alive ping.
- [ ] 3.2 Validate the change structure with `openspec validate gtfs-pipeline`.

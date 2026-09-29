# Proposal: gtfs-pipeline

## Why

Storing complete GTFS transit schedules in Postgres would consume hundreds of megabytes of relational database storage, rapidly breaching the 500 MB limit of the Supabase Free tier. In alignment with Architectural Decision #1 (§4) and the infrastructure strategy (§9), transit schedules must live offline on the mobile device in SQLite.

To achieve this at zero infrastructure cost, an automated nightly ETL pipeline must download verified static GTFS feeds, filter and compact them to Bizkaia transport networks, compute operator-specific classification rules (such as Metro Bilbao L1/L2 distinction), build an indexed `transit.sqlite` database, and upload it with a cryptographic `manifest.json` to public Supabase Storage.

## What Changes

- **ETL Compiler Engine (`tools/build_gtfs/build_transit_db.py`)**:
  - Downloads verified static GTFS zips (Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe Cercanías) using HTTP cache headers (`If-Modified-Since`).
  - Extracts and normalizes core GTFS tables: `agency`, `routes`, `trips`, `stops`, `stop_times`, `calendar`, and `calendar_dates`.
  - Computes Metro Bilbao line classification: dynamically infers L1 vs L2 based on served stations (Lutxana ⇄ Plentzia → L1; Gurutzeta ⇄ Kabiezes → L2).
  - Compacts data into an optimized SQLite database (`transit.sqlite`) with query indices on `stop_times(stop_id, departure_time)` and `trips(trip_id, service_id)`.
  - Generates Gzip-compressed artifact (`transit.sqlite.gz`) and metadata `manifest.json` containing SHA-256 checksums, byte counts, generation timestamp, and feed source versions.
- **Supabase Storage Infrastructure**:
  - SQL migration creating public read-only bucket `transit-packs` with public download policies.
- **Nightly Pipeline & Keep-Alive Automation (`.github/workflows/build-gtfs.yml`)**:
  - Nightly GitHub Actions cron (`0 2 * * *`) that runs the ETL compiler, uploads artifacts to Supabase Storage, and issues an authenticated ping to Supabase REST API (`/rest/v1/profiles?select=id&limit=1`) to prevent project pausing due to inactivity (§9).

## Capabilities

### New Capabilities
None. This change implements the serverless backend data compilation and distribution pipeline.

### Modified Capabilities
None. Behavioral requirements remain unchanged (`skip_specs: true` in `.openspec.yaml`).

## Impact

- **Affected Code**: `tools/build_gtfs/`, `supabase/migrations/`, `.github/workflows/build-gtfs.yml`.
- **Operators Affected**: Metro Bilbao (MVP focus), with schema support for Bizkaibus, Bilbobus, Euskotren, and Renfe.
- **Non-Goals**: Does not implement Flutter Drift client synchronization or mobile UI (handled in change 4: `metro-departures`).
- **Dependencies**: Uses standard Python 3 with `sqlite3` and `urllib` in the GitHub Actions runner.

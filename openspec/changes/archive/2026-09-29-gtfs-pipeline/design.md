# Design: gtfs-pipeline

## Context

See [proposal.md](proposal.md) for motivation.
Under Architectural Decision #1 (§4) and §9 of `spec.md`, relational database size on the Supabase Free tier is capped at 500 MB, whereas static GTFS schedule records (`stop_times.txt`) can expand significantly. Storing schedules in local SQLite on mobile devices eliminates server egress, avoids database quota exhaustion, and guarantees instant sub-second queries without network latency.

This design specifies the automated nightly ETL engine that builds and publishes optimized SQLite schedule bundles to public Supabase Storage.

## Goals / Non-Goals

**Goals:**
- Implement `tools/build_gtfs/build_transit_db.py` in standalone Python 3 (standard library only) to download, parse, filter, and compile GTFS feeds into `transit.sqlite`.
- Implement Metro Bilbao L1/L2 route classification heuristic based on served station sets.
- Create optimized query indices in SQLite (`idx_stop_times_stop`, `idx_trips_service`) to ensure mobile query latency < 100 ms.
- Generate Gzip-compressed artifact (`transit.sqlite.gz`) and metadata manifest (`manifest.json`) containing SHA-256 hash, byte size, and generation timestamps.
- Configure public Supabase Storage bucket `transit-packs` with read-only public access policies.
- Automate nightly execution (`0 2 * * *`) and Supabase keep-alive ping via `.github/workflows/build-gtfs.yml`.

**Non-Goals:**
- Implementing the Flutter Drift repository or in-app download manager (deferred to change 4: `metro-departures`).
- Implementing multi-modal transfer pathfinding algorithms (RAPTOR/CSA).

## Decisions

### 1. Python 3 Zero-Dependency ETL Tool
- **Decision**: Write `tools/build_gtfs/build_transit_db.py` using standard library modules (`urllib.request`, `zipfile`, `csv`, `sqlite3`, `gzip`, `hashlib`, `json`).
- **Rationale**: Executes immediately on GitHub Actions ubuntu runners, macOS, and Linux without requiring virtual environments, pip packages, or Docker build steps.

### 2. SQLite Database Schema & Indexing Strategy
- **Decision**: Define a streamlined schema in `transit.sqlite`:
  ```sql
  create table operators (
    operator_id text primary key,
    name text not null
  );

  create table routes (
    route_id text primary key,
    operator_id text not null,
    route_short_name text not null,
    route_long_name text not null,
    route_type integer not null,
    route_color text
  );

  create table stops (
    stop_id text primary key,
    operator_id text not null,
    stop_name text not null,
    stop_lat real not null,
    stop_lon real not null,
    zone_id text
  );

  create table trips (
    trip_id text primary key,
    route_id text not null,
    service_id text not null,
    trip_headsign text,
    direction_id integer,
    inferred_line text -- 'L1', 'L2', etc.
  );

  create table stop_times (
    trip_id text not null,
    stop_id text not null,
    stop_sequence integer not null,
    arrival_time text not null,   -- HH:MM:SS (may exceed 24:00:00)
    departure_time text not null,
    primary key (trip_id, stop_sequence)
  );

  create table calendar (
    service_id text primary key,
    monday integer not null,
    tuesday integer not null,
    wednesday integer not null,
    thursday integer not null,
    friday integer not null,
    saturday integer not null,
    sunday integer not null,
    start_date text not null,
    end_date text not null
  );

  create table calendar_dates (
    service_id text not null,
    date text not null,
    exception_type integer not null,
    primary key (service_id, date)
  );

  create index idx_stop_times_lookup on stop_times (stop_id, departure_time);
  create index idx_trips_service on trips (service_id, route_id);
  ```
- **Rationale**: Minimizes footprint while providing O(log N) lookup for the "next departures from stop X" query.

### 3. Metro Bilbao Line Classification Heuristic
- **Decision**: Metro Bilbao source GTFS routes define a single route `MB`. The ETL classifies trips by inspecting the station IDs served:
  - Stations exclusively on Line 1 (Lutxana through Plentzia) → `inferred_line = 'L1'`.
  - Stations exclusively on Line 2 (Gurutzeta/Cruces through Kabiezes) → `inferred_line = 'L2'`.
  - Shared trunk (San Inazio ⇄ Basauri/Ariz): classified as `L2` if serving Ariz/Basauri unless originating from Plentzia branch.

### 4. Supabase Storage Bucket & Keep-Alive Strategy
- **Decision**: Store `transit.sqlite.gz` and `manifest.json` in a dedicated public bucket named `transit-packs`.
- **Nightly Keep-Alive**: The GitHub Actions runner issues `curl -s "https://zbwrjtncyblaxaarbmsr.supabase.co/rest/v1/profiles?select=id&limit=1" -H "apikey: $SUPABASE_ANON_KEY"`, providing the active traffic required to prevent 7-day inactivity pause (§9).

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| Large file download on mobile | High cellular data consumption | Compress with gzip (`.sqlite.gz`); client checks `manifest.json` sha256 before downloading |
| Metro Bilbao GTFS structure changes | Misclassified L1/L2 lines | Fallback to headsign inspection if station sets yield ambiguous results |
| Supabase Storage upload failure | Outdated schedule pack | Workflow fails gracefully and alerts; app continues using cached local pack |

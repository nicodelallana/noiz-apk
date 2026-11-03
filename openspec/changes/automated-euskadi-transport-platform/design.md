# Design: Automated Euskadi Public Transport Data Platform

## Architecture Overview

The system is designed as a decoupled, resilient, event-driven data ingestion platform built around Python 3, Supabase (PostgreSQL 15+ with PostGIS, Storage, and RLS), and FastAPI.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Moveuskadi / Open Data Euskadi                       │
│  - data-index.json (35 Operators, 195 Resources)                       │
│  - GTFS Static (.zip), GTFS-RT (.pb), SIRI (.xml), NeTEx (.zip)        │
│  - GeoEuskadi Administrative Boundaries (TERRITORIOS_5000_ETRS89.zip)  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ HTTP / TLS (Backoff & Checksums)
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Python Ingestion Engine                           │
│  ┌──────────────────────┐  ┌─────────────────────┐  ┌───────────────┐  │
│  │  Catalog Discovery   │  │  Download Manager   │  │  Storage Svc  │  │
│  └──────────┬───────────┘  └──────────┬──────────┘  └───────┬───────┘  │
│             │                         │                     │          │
│             ▼                         ▼                     ▼          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Format Detection & Processors:                                   │  │
│  │   • GTFS Static Parser (zip validation, referential checks)     │  │
│  │   • GTFS-Realtime Parser (Protobuf vehicle positions, alerts)    │  │
│  │   • SIRI XML Parser (Situation Exchange, Vehicle Monitoring)     │  │
│  │   • NeTEx XML/Zip Parser (Scheduled stops, lines)                │  │
│  │   • SHP Processor (ETRS89 -> WGS84 GeoJSON/PostGIS conversion)   │  │
│  └──────────────────────────────────┬───────────────────────────────┘  │
│                                     │                                  │
│             ┌───────────────────────┴───────────────────────┐          │
│             ▼                                               ▼          │
│  ┌───────────────────────────┐             ┌────────────────────────┐  │
│  │ Spatial Classifier        │             │ Normalizer & Publisher │  │
│  │ (PostGIS ST_Contains)     │             │ (Atomic Feed Versions) │  │
│  └──────────┬────────────────┘             └────────────┬───────────┘  │
└─────────────┼───────────────────────────────────────────┼──────────────┘
              │                                           │
              ▼                                           ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Supabase Infrastructure                         │
│  PostgreSQL + PostGIS:                                                 │
│    • Core Geography: provinces, municipalities, boundaries             │
│    • Operators & Catalogs: transport_operators, catalogue_resources    │
│    • GTFS Model: agencies, stops, routes, trips, stop_times (isolated) │
│    • Real-Time: vehicle_positions, trip_updates, service_alerts        │
│    • Storage: moveuskadi/{catalogue,raw,processed,archives}/           │
│    • Row Level Security (RLS) on 100% of tables                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Key Architectural Decisions

### 1. Authoritative Index Discovery
The system polls `https://opendata.euskadi.eus/transport/moveuskadi/data-index.json`. It computes SHA-256 hashes of the catalogue payload and detects:
- Added operators and resources.
- Modified resources (checked via catalogue `last-update` timestamp, HTTP ETag/Last-Modified, and payload checksum).
- Deleted/deprecated resources (flagged as inactive, never deleted abruptly).

### 2. Identifier Collision Prevention
GTFS IDs (such as stop `1`, route `L1`, trip `1001`) are locally scoped by each transit agency. In Moveuskadi, multiple operators share identical strings.
**Solution:**
- Primary keys are internal UUIDs (`gen_random_uuid()`).
- Source scoping: `(feed_version_id, external_id)` or `(operator_id, external_id)` form unique composite indexes.
- All relationships reference internal UUIDs (`stop_id`, `route_id`, `trip_id`).

### 3. Spatial Classification & PostGIS
Stops are classified using authoritative territorial boundary polygons from GeoEuskadi (`TERRITORIOS_5000_ETRS89`):
- Coordinates are projected from ETRS89 UTM 30N (EPSG:25830) to WGS84 (EPSG:4326).
- PostGIS function `classify_stops_provinces()` evaluates `ST_Contains(boundary.geom, stop.geom)`.
- Stops outside Euskadi (e.g. boundary crossings in Cantabria, Burgos, or Navarra) or in maritime areas are flagged as `unclassified` or assigned to adjacent territory with recorded confidence.
- Routes are classified into provinces based on the set of provinces their stops intersect.

### 4. Safe Publication & Feed Versioning
Each static import creates a new `feed_versions` record in `status = 'importing'`.
1. Data is ingested into version-scoped tables or marked with `feed_version_id`.
2. Integrity validation checks route counts, trip counts, calendar dates, and stop coordinates.
3. If validation succeeds, `activate_feed_version()` atomically flips the active pointer.
4. If an import fails, the error is recorded in `ingestion_errors`, the new version is marked `failed`, and the currently active feed version continues serving traffic without interruption.

### 5. Storage Hierarchy in Supabase Storage
Bucket: `transit-packs` (or `moveuskadi`):
- `catalogue/snapshots/{YYYY-MM-DD}/{timestamp}_data-index.json`
- `raw/{province_or_shared}/{operator_slug}/{version_id}_{filename}`
- `processed/{format}/{operator_slug}/{version_id}/`
- `archives/{operator_slug}/{timestamp}_{filename}`

### 6. Error Handling & Rate Limiting
- HTTP requests utilize `httpx` with exponential backoff (initial 1.0s, multiplier 2.0, max 3 retries) and explicit connection timeouts (30s).
- Protobuf decoding is wrapped with schema verification.
- Defused XML parser prevents XXE, quadratic expansion, and external entity injection.
- Circuit breaker pattern prevents repetitive downloads of failing or 5xx endpoints.

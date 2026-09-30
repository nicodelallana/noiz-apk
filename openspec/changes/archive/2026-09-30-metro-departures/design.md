# Design: metro-departures

## Context

See [proposal.md](proposal.md) for motivation.
`gtfs-pipeline` successfully generates and publishes `transit.sqlite.gz` and `manifest.json` to public Supabase Storage CDN. This design describes the client-side architecture for downloading, opening, and querying schedules in SQLite via Drift, calculating GTFS service-day timetables, and presenting the Metro Bilbao departures screen.

## Goals / Non-Goals

**Goals:**
- Implement `ScheduleSyncService` using `dio` to synchronize `transit.sqlite.gz` based on `manifest.json` checksums.
- Implement `AppDatabase` using `drift` to connect to the local SQLite database.
- Define pure domain entities (`Stop`, `Route`, `Trip`, `Departure`, `ServiceDay`) independent of any database or Flutter UI framework.
- Implement `MetroRepositoryImpl` incorporating:
  - Station lookup (supporting Basque and Spanish station names).
  - Accurate service-day resolution (`Europe/Madrid` timezone, midnight rollover > 24:00:00).
  - Line filtering (`L1`, `L2`, or all).
- Implement `MetroDeparturesScreen` using Flutter Riverpod with origin station selector, line filter chips, and departure countdown list.

**Non-Goals:**
- GTFS-RT protobuf delay adjustments (change 8: `realtime-overlay`).
- Native home-screen widgets (change 7: `widget-android` / `widget-ios`).

## Decisions

### 1. Database Layer: Drift with Pre-populated SQLite File
- **Decision**: Use `drift` with `NativeDatabase.createInBackground` pointing to the unpacked `transit.sqlite` in `getApplicationDocumentsDirectory()`.
- **Rationale**: Drift provides typed queries, compile-time query validation, and asynchronous Isolate-backed queries that guarantee zero UI frame drops.

### 2. Synchronization Strategy (Atomic Swap)
- **Decision**:
  1. On app startup, `ScheduleSyncService` fetches `manifest.json` (538 bytes) via `dio`.
  2. Compares `manifest.json["compressed"]["sha256"]` with the locally stored hash.
  3. If identical, reuse local database immediately (< 10 ms).
  4. If altered or missing: download `transit.sqlite.gz` to a temporary file (`transit.sqlite.gz.part`), decompress using `dart:io` `GZipCodec`, and atomically rename to `transit.sqlite`.
- **Rationale**: Prevents database corruption if the app is closed mid-download.

### 3. Service Day Calculation Algorithm
- **Decision**:
  - Step 1: Convert current device time to `Europe/Madrid` timezone.
  - Step 2: Extract current time string (`HH:MM:SS`) and current date (`YYYYMMDD`), plus yesterday's date (`YYYYMMDD`).
  - Step 3: Identify active `service_id`s for today:
    - Match `calendar` day-of-week flag (1 for today).
    - Apply `calendar_dates`: include if `exception_type = 1`, exclude if `exception_type = 2`.
  - Step 4: If current time is between 00:00:00 and 06:00:00 (madrugada):
    - Identify active `service_id`s for yesterday.
    - Match yesterday's trips where `departure_time >= (hour + 24):MM:SS` (e.g. `24:26:00`).
  - Step 5: Query `stop_times` for the selected `stop_id` for both active service sets.
  - Step 6: Map to `Departure` domain entities with calculated countdown in minutes.

### 4. Presentation & Motion Architecture
- **Decision**: Build `MetroDeparturesScreen` following project guidelines:
  - Initial pack download displays a clean Lottie transit loading indicator (< 50 KB, wrapped in `RepaintBoundary`).
  - Filter chips for `Todas`, `L1 (Plentzia / Ibarbengoa)`, `L2 (Kabiezes)`.
  - Departure cards show headsign, line badge (red L1 / L2), departure time, and remaining minutes.
  - Sub-second departures list updates every 30 seconds via timer.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| First-time launch download latency | Blank screen while downloading 5 MB | Show downloading progress percentage and cached fallback |
| Midnight departures missed | Users at 00:30 see next morning trips | Service day algorithm explicitly queries yesterday's service > 24:00 |
| Station search diacritic mismatch | User types "San Mames" instead of "San Mamés" | Normalized ASCII substring search |

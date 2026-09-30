# Proposal: metro-departures

## Why

With the `gtfs-pipeline` actively publishing compressed `transit.sqlite.gz` bundles and `manifest.json` to public Supabase Storage, the mobile application requires the client-side capability to download, unpack, and query schedule data offline. Implementing Metro Bilbao departure queries establishes the core MVP functionality (Phase 0.x) defined in §2: sub-second local departures, robust GTFS service-day resolution (handling departures beyond 24:00:00 and Europe/Madrid timezone), and Line 1 / Line 2 classification, verified against the primary reference route: Bagatza ⇄ Kabiezes (§1).

## What Changes

- **Schedule Synchronization Client (`lib/data/gtfs/schedule_sync_service.dart`)**:
  - Queries `manifest.json` from Supabase Storage CDN.
  - Compares local SQLite checksum with remote SHA-256 hash.
  - Downloads and decompresses `transit.sqlite.gz` with progress indication into local storage only when changed.
- **Local Drift / SQLite Access (`lib/data/local/app_database.dart`)**:
  - Connects to local `transit.sqlite` file.
  - Provides typed query access for stops, routes, trips, stop times, and calendar dates.
- **Domain Entities & Repository Contract (`lib/domain/`)**:
  - Core domain models: `Stop`, `Route`, `Trip`, `Departure`, `ServiceDay`.
  - Repository interface `MetroRepository` defining `getStops()`, `getNextDepartures(originStopId, destinationStopId?, lineFilter?)`.
- **Metro Bilbao Adapter & Service Day Engine (`lib/data/adapters/metro_repository_impl.dart`)**:
  - Implements GTFS service-day resolution: resolves active service IDs for both the current calendar day and the previous calendar day (to capture services scheduled between 24:00:00 and 28:00:00).
  - Handles timezone conversion with `Europe/Madrid`.
  - Filters by inferred line (L1 vs L2) and target destination.
- **Presentation Layer (`lib/presentation/screens/metro/`)**:
  - Riverpod state providers for sync status, station selection, and upcoming departures stream.
  - User interface: `MetroDeparturesScreen` featuring station search/picker, L1/L2 line filter toggle, countdown timer, and departure list labeled as "horario teórico".
- **Automated Verification**:
  - Unit tests verifying service day resolution, 24:00+ time formatting, and Bagatza ⇄ Kabiezes departures.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. Implements existing requirements declared in `transit-data` and `ui-navigation` (`skip_specs: true` in `.openspec.yaml`).

## Impact

- **Affected Code**: `lib/data/`, `lib/domain/`, `lib/presentation/screens/metro/`, `test/`.
- **Operators Affected**: Metro Bilbao (L1 and L2).
- **Non-Goals**: Does not yet ingest GTFS-RT real-time delays (change 8: `realtime-overlay`), user authentication (change 5: `auth-google`), or native home-screen widgets (change 7: `widget-android` / `widget-ios`).
- **Dependencies**: Leverages existing dependencies (`drift`, `sqlite3_flutter_libs`, `flutter_riverpod`, `timezone`).

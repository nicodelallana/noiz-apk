# Tasks

## 1. Domain Models & Contracts

- [x] 1.1 Create pure domain models (`Stop`, `MetroLine`, `Departure`) in `lib/domain/models/transit_models.dart` and verify data immutability and equality
- [x] 1.2 Define `MetroRepository` interface in `lib/domain/repositories/metro_repository.dart` for stations lookup and departures querying

## 2. Schedule Synchronization Service

- [x] 2.1 Implement `ScheduleSyncService` in `lib/data/gtfs/schedule_sync_service.dart` to fetch remote `manifest.json`, verify SHA-256 checksums, and atomically unpack `transit.sqlite.gz`
- [x] 2.2 Add unit tests for `ScheduleSyncService` in `test/unit/schedule_sync_service_test.dart` verifying checksum matching, skip on identical hash, and decompression error handling

## 3. Local Drift SQLite Database

- [x] 3.1 Implement Drift table definitions and database class in `lib/data/local/app_database.dart` reflecting the transit schema (`stops`, `routes`, `trips`, `stop_times`, `calendar`, `calendar_dates`)
- [x] 3.2 Implement typed Drift query methods for active service day lookup, station search, and stop departures query

## 4. Metro Repository & Service Day Resolution Engine

- [x] 4.1 Implement `MetroRepositoryImpl` in `lib/data/adapters/metro_repository_impl.dart` with GTFS service-day resolution (`Europe/Madrid` timezone, 24:00+ rollover handling for midnight to 06:00 queries)
- [x] 4.2 Implement Metro line classification heuristic (L1 vs L2) and headsign mapping in `MetroRepositoryImpl`
- [x] 4.3 Add unit and integration tests in `test/unit/metro_repository_test.dart` validating service-day resolution, 24:00:00+ departures, and Bagatza ⇄ Kabiezes departures against real compiled SQLite data

## 5. Presentation Layer & Lottie Motion

- [x] 5.1 Add lightweight Lottie loading animation asset (< 50 KB) in `assets/lottie/metro_loading.json` adhering to fluid animation guidelines
- [x] 5.2 Implement Riverpod state providers in `lib/presentation/providers/metro_providers.dart` for sync status, station picker, line filter, and auto-refreshing departures
- [x] 5.3 Implement `MetroDeparturesScreen` in `lib/presentation/screens/metro/metro_departures_screen.dart` with station search modal, line filter chips, Lottie loading state, and departure cards labeled with theoretical timetable

## 6. End-to-End Verification & OpenSpec Validation

- [x] 6.1 Execute test suite and verify all unit tests pass with zero regressions
- [x] 6.2 Run `openspec validate metro-departures` to verify specification compliance and readiness for apply

# Tasks

## 1. Renfe Headsign Fallback and SQLite Data Hygiene

- [x] 1.1 Update `AppDatabase.getRawDepartures` and `findDirectRoute` queries in `lib/data/local/app_database.dart` with the `COALESCE(NULLIF(TRIM(t.trip_headsign), ''), ...)` terminal stop fallback subquery, verifying with unit tests.
- [x] 1.2 Update prepackaged `assets/db/transit.sqlite.gz` so trips without headsigns or inferred_line have their destination and line pre-populated.
- [x] 1.3 Update `compile_official_gtfs.py` and `compile_all_gtfs.py` to trim headers and resolve empty headsigns during GTFS build.

## 2. Save Trip Dialog Multi-Operator Fix

- [x] 2.1 Refactor `SaveTripDialog` in `lib/presentation/screens/saved_trips/save_trip_dialog.dart` to support active operator stops instead of hardcoding `metroStationsProvider`, verifying that a Renfe stop displays its origin name accurately.
- [x] 2.2 Ensure saving a trip preserves the correct `operatorId` rather than forcing `TransitOperator.metro`.

## 3. Map Polyline Smoothing and Zigzag Fix

- [x] 3.1 Update `TransitRepositoryImpl.getOperatorNetworkGeoJson` and `getRouteShapes` to choose the single canonical longest shape per line, preventing overlapping reverse-direction tracks.
- [x] 3.2 Fix the stop-sequence fallback in `TransitRepositoryImpl.getRouteShapes` and `AppDatabase.getStopsForRoute` to avoid concatenating direction 1 stops after direction 0 stops in a single LineString.

## 4. Replace "Cuenta" with "Tarifas" Screen

- [x] 4.1 Update `AppShell` in `lib/presentation/navigation/app_shell.dart` and `AppRouter` in `lib/presentation/navigation/app_router.dart` to replace tab 4 "Cuenta" with "Tarifas" (`/fares`) with no authentication barrier.
- [x] 4.2 Create `TransitFaresScreen` in `lib/presentation/screens/fares/transit_fares_screen.dart` with operator selector, origin-destination zone calculator, Barik vs Ocasional price comparison, discount profiles, and full fare table.
- [x] 4.3 Update `departures_ui_test.dart` to assert the "Tarifas" tab in `AppShell`.

## 5. Incident & Delay Correlation in Route Planner & Live Notifications

- [x] 5.1 Update `RoutePlannerScreen` in `lib/presentation/screens/planner/route_planner_screen.dart` to check `serviceAlertsProvider` for matching lines/operators and display active disruption banners.
- [x] 5.2 Pass active delay seconds and disruption instructions into `LiveTripState` when following a trip, verifying that `TransitLiveService` displays delay tags in notification.

## 6. Verification and Regression Testing

- [x] 6.1 Run `flutter test` and verify that all unit and widget tests pass without regressions.

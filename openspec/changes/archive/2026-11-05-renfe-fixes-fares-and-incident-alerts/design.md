# Design: Renfe Headsigns, Map Polyline Smoothing, Fare Calculator, and Incident Alerts

## Context
See `proposal.md` for background and motivation. The app is a Flutter/Riverpod mobile application running against local SQLite tables pre-compiled from GTFS.

Currently:
1. Renfe trips contain whitespace headsigns, causing SQLite queries and the UI to fall back to the string `'Destino'`. Additionally, `SaveTripDialog` is hardcoded to `metroStationsProvider`, meaning non-Metro stops cannot be matched in the origin dropdown and journeys get saved with `operator: metro`.
2. When displaying map polylines, `getOperatorNetworkGeoJson` and `getRouteShapes` fetch all shape variations (both outbound and inbound tracks digitized separately with 3–10 meter lateral offsets). Rendering them simultaneously causes visual weaving, jagged lines, and moiré patterns when zooming in.
3. The 4th tab currently routes to `ProfileSettingsScreen` ("Cuenta"). The user requested transforming this into a "Tarifas" screen without login barriers, comparing Barik Creditrans vs Occasional tickets across operators based on zones (MoveEuskadi/CTB standards).
4. `RoutePlannerScreen` does not correlate results with `serviceAlertsProvider`, and live notifications do not display active delays when searching/tracking a journey.

## Goals / Non-Goals

**Goals:**
- Eliminate `'Destino'` fallbacks by resolving terminal stop names dynamically when headsign is empty.
- Fix `SaveTripDialog` to work seamlessly for all operators and preserve the selected origin name.
- Eliminate map polyline zig-zags by rendering a single canonical shape per line/route without overlapping reverse tracks.
- Build a dedicated, accessible, and elegant `TransitFaresScreen` in the bottom shell navigation.
- Highlight active incidents on itineraries and propagate delay metrics to lock screen notifications.

**Non-Goals:**
- Modifying the underlying database schema with breaking column drops or restructuring.
- Scraping external ticketing sites: all fare computations are governed by official CTB/MoveEuskadi tables and GTFS rules.

## Decisions

### 1. Dynamic Terminal Stop Headsign Resolution in SQL
- **Decision**: In `AppDatabase.getRawDepartures` and `findDirectRoute`, evaluate:
  ```sql
  COALESCE(NULLIF(TRIM(t.trip_headsign), ''), (
    SELECT s_dest.stop_name
    FROM stop_times st_dest
    JOIN stops s_dest ON st_dest.stop_id = s_dest.stop_id
    WHERE st_dest.trip_id = st.trip_id
    ORDER BY st_dest.stop_sequence DESC
    LIMIT 1
  )) AS trip_headsign
  ```
- **Rationale**: This is fast (0.1ms with existing SQLite indices) and guarantees that any trip missing a headsign will display its actual terminus station (e.g., Santurtzi, Muskiz, Orduña, Abando) rather than 'Destino'.
- **Complement**: In the packaged `transit.sqlite`, run the update script so `trips.trip_headsign` and `trips.inferred_line` are pre-populated.

### 2. Multi-Operator Support in `SaveTripDialog`
- **Decision**: Update `SaveTripDialog` to accept and prioritize `activeOperator` and load stops via `stopsForActiveOperatorProvider` (or fallback to repository stops). Include the provided `initialOrigin` in the items list even if search filters are active, and pass the correct operator when saving.
- **Rationale**: Stops from Renfe, Bizkaibus, Bilbobus, or Euskotren will immediately match and show their proper name in the origin dropdown.

### 3. Canonical Single-Line Geometries for Map Rendering
- **Decision**:
  - In `getOperatorNetworkGeoJson`: For each route/line code, select the single longest canonical shape (e.g., for Metro: `ETX_PLE` for L1, `BSR_KAB` for L2, `Line:9:` for L3; for Renfe: `60_C1`, `60_C2`, `60_C3`, `60_C4`, `60_C5`).
  - In `getRouteShapes`: Return only the canonical shape for the requested route/direction.
  - In fallback stop sequencing: If no shape exists, return separate directional paths `[d0Coords, d1Coords]` instead of appending return stops to the end of outbound stops.
- **Rationale**: Eliminates line doubling and overlapping reverse vectors that cross each other and cause zigzagging upon zoom.

### 4. Interactive `TransitFaresScreen`
- **Decision**:
  - Replace the 4th tab (`app_shell.dart`) with `_TabSpec('Tarifas', Icons.credit_card_outlined, Icons.credit_card_rounded)`.
  - Route `/fares` loads `TransitFaresScreen`.
  - Operator selection pills (Metro Bilbao, Bizkaibus, Bilbobus, Renfe Cercanías, Euskotren, Tranvía Bilbao, Funicular Artxanda, etc.).
  - Origin and Destination dropdowns with automatic zone calculation (comparing `origin.zoneId` and `dest.zoneId`, or zone hops).
  - Comparative pricing card (Barik vs Ocasional), showing percentage savings, transfer rules (20% bonus within 50 min), profile selector (Estándar, Gizatrans, Gazte, F20/F50), and complete zone rate table.

### 5. Incident & Delay Correlation
- **Decision**: In `RoutePlannerScreen`, watch `serviceAlertsProvider` and match against itinerary legs using line code or operator. Show a warning banner when affected, and pass `delaySeconds` to `LiveTripState` when starting live tracking.

## Risks / Trade-offs

- **[Risk]** GTFS stops for some operators have alphanumeric or custom zone IDs.
  - **Mitigation**: Implement robust zone mapper (`ZoneResolver`) that handles Metro zones (`A`, `B0-B2`, `C` -> 1-3 zones), Bizkaibus numeric zones (1-5), Bilbobus (flat 1 zone), and Renfe station mappings.
- **[Risk]** Live tracking notification on Android TIRAMISU+ requires notification permission.
  - **Mitigation**: Permissions are already handled with graceful fallbacks in `MainActivity.kt` and `LiveTripService`.

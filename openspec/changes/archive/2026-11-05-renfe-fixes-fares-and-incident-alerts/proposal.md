# Proposal: Renfe Headsigns, Map Polyline Smoothing, Fare Calculator, and Incident Alerts

## Why
Users of Renfe Cercanías currently experience missing origin names in the save trip dialog and see "Destino" instead of the actual terminus station in the departures list due to empty headsigns in the GTFS feed. Furthermore, map polylines for transit routes suffer from severe zigzagging and moiré artifacts at close zoom levels caused by overlapping bidirectional tracks and flawed fallback stop sequencing. 

Additionally, user feedback requires replacing the "Cuenta" tab with a dedicated "Tarifas" screen supporting all operators (taking into account Barik card discounts, occasional tickets, and origin-to-destination zones via MoveEuskadi/CTB standards) without requiring login, and ensuring delays/incidents are verified and actively highlighted when searching for transport and tracking journeys.

## What Changes
- **Renfe Cercanías Headsign & Origin Station Resolution**:
  - Automatically resolve missing/whitespace headsigns to the terminus station name from `stop_times` in SQLite queries and database compilation.
  - Fix `SaveTripDialog` to load stops for the active operator (or all operators) and properly retain the origin station name instead of defaulting to Metro-only stations and blank selections.
  - Save the correct `operatorId` instead of hardcoding `TransitOperator.metro`.
- **Map Polyline Smoothing & Zigzag Elimination**:
  - Refactor `getOperatorNetworkGeoJson` and `getRouteShapes` to select a single canonical directional shape per line/route rather than drawing outbound and inbound tracks on top of each other.
  - Fix the stop-sequence fallback in `getStopsForRoute` and `getRouteShapes` so direction 1 is not concatenated to direction 0 in a single LineString.
- **Fare Calculator ("Tarifas") Tab**:
  - Replace the "Cuenta" tab in `AppShell` and `AppRouter` with "Tarifas" (`/fares`), removing the authentication barrier.
  - Implement an interactive fare calculator allowing the user to select any operator (Metro Bilbao, Bizkaibus, Bilbobus, Renfe Cercanías, Euskotren, Tranvía, Funicular Artxanda, etc.).
  - Support origin and destination station selection with automatic zone jump detection (1 to 5 zones) and MoveEuskadi/CTB fare rules.
  - Compare Barik (Creditrans) prices against Billete Ocasional/Sencillo, showing savings, special discounts (Gizatrans, Gazte, Familias Numerosas), and transfer discount rules.
- **Incident & Delay Alerts in Search & Tracking**:
  - Integrate `serviceAlertsProvider` into `RoutePlannerScreen` and transport search to alert users if an active incident or disruption affects their itinerary.
  - Ensure that when a journey is tracked, active delays (`delaySeconds >= 60`) and incident instructions are passed to `liveTripServiceProvider` and native `TransitLiveService` for display on the Android lock screen notification.

## Capabilities

### New Capabilities
- `fares`: Comprehensive transit fare calculator for Bizkaia and Basque Country operators, supporting Barik vs occasional pricing, multi-zone journeys, and fare profile discounts.

### Modified Capabilities
- `transit-data`: Headsign fallback for empty GTFS trip headsigns and canonical single-track shape resolution to eliminate map zigzagging.
- `saved-trips`: Multi-operator support in bookmarking journeys without dropping station names or forcing Metro Bilbao.
- `ui-navigation`: Replaces the "Cuenta" shell tab with "Tarifas" without authentication requirement.
- `trip-planner`: Incident awareness for itinerary legs and propagation of delay status to live trip notifications.

## Impact
- **Database & GTFS Pipeline**: SQL query adjustments in `AppDatabase`, updated pre-packaged `transit.sqlite.gz`, and updates to GTFS compilers.
- **Frontend / Presentation**: `SaveTripDialog`, `TransitMapScreen`, `RoutePlannerScreen`, `AppShell`, `AppRouter`, and new `TransitFaresScreen`.
- **Domain & Services**: `TransitRepositoryImpl`, `LiveTripService`, and fare estimation logic.

# Design: saved-trips

## Context

See [proposal.md](proposal.md) for motivation.
`metro-departures` established offline schedules, and `auth-google` established identity and Supabase RLS.
`saved-trips` brings the primary feature of Bizkaia Transit: bookmarking daily transit journeys (e.g. Metro Bilbao L2 Bagatza ⇄ Kabiezes) and displaying them with immediate countdown times.

## Goals / Non-Goals

**Goals:**
- Provide a responsive, offline-first saved journeys manager with sub-10ms UI reads.
- Sync saved trips with Supabase Postgres `public.saved_trips` when authenticated.
- Enable full guest mode (unauthenticated users can save trips locally without an account).
- Automatic migration of guest trips to the cloud upon user sign-in.
- Display live countdown departures directly within each saved trip card in `SavedTripsScreen`.
- Provide a quick-save button from `MetroDeparturesScreen`.

**Non-Goals:**
- Native Android/iOS homescreen widget code (handled in change 7: `widget-android` / `widget-ios`).
- Trip sharing codes (handled in future change: `sharing-codes`).

## Decisions

### 1. Two-Tier Storage: Offline-First Drift Cache + Supabase Cloud
- **Decision**: Saved trips are always read directly from local SQLite table `user_saved_trips`. When online and authenticated, background synchronization pushes local changes to Supabase and pulls remote changes to SQLite.
- **Rationale**: Guarantees the app opens instantly with zero network delay and functions reliably in underground stations with poor connectivity.

### 2. Guest Support & Sign-In Merging
- **Decision**: Unauthenticated users have their saved trips stored locally with `user_id = 'guest'`. When `authController` notifies a successful login, `SavedTripsRepository` automatically updates local guest trips with the new `auth.uid` and syncs them to Supabase.
- **Rationale**: Maximizes app adoption by not forcing registration before experiencing value, while providing painless cloud backup once authenticated.

### 3. Trip Representation & Next Departure Integration
- **Decision**: The `SavedTrip` domain entity contains:
  ```dart
  class SavedTrip {
    final String id;
    final String name;
    final TransitOperator operator;
    final String originStopId;
    final String originStopName;
    final String destStopId;
    final String destStopName;
    final String? routeId;
    final int? directionId;
    final bool widgetEnabled;
    final int sortOrder;
    final DateTime createdAt;
  }
  ```
  `SavedTripsScreen` combines `SavedTrip` with `metroRepository.getDepartures(stationId: originStopId)` to render the next upcoming train countdown on each card.

### 4. Database Schema Alignment
- Local SQLite Drift table `UserSavedTrips` matches `public.saved_trips` columns:
  - `id` (TEXT PK, UUID)
  - `user_id` (TEXT NOT NULL)
  - `name` (TEXT NOT NULL)
  - `operator` (TEXT NOT NULL)
  - `origin_stop_id` (TEXT NOT NULL)
  - `origin_stop_name` (TEXT NOT NULL)
  - `dest_stop_id` (TEXT NOT NULL)
  - `dest_stop_name` (TEXT NOT NULL)
  - `route_id` (TEXT NULL)
  - `direction_id` (INTEGER NULL)
  - `widget_enabled` (INTEGER NOT NULL 0/1)
  - `sort_order` (INTEGER NOT NULL)
  - `created_at` (TEXT NOT NULL)

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| Offline creation conflicts | Same trip saved offline on two devices | Upsert by ID; generate random client UUIDs (v4) preventing collision |
| User logs out | Saved trips from account might linger | On logout, clear cloud-owned trips from local SQLite or keep guest trips isolated |
| Origin station departures offline | Station departures not showing | Reuses compiled `transit.sqlite` offline database already downloaded by `ScheduleSyncService` |

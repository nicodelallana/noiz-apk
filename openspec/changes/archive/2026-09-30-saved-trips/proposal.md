# Proposal: saved-trips

## Why

Bizkaia Transit's core purpose is providing frictionless, at-a-glance departures for frequent daily commutes (such as Metro Bilbao L2 Bagatza ⇄ Kabiezes) without needing to search origin and destination repeatedly.
Implementing saved trips with local caching and cloud synchronization ensures trips are immediately accessible offline, synced across devices for authenticated users, and ready to feed future home screen widgets.

## What Changes

- Define pure domain entity `SavedTrip` and operator enumeration `TransitOperator`.
- Define `SavedTripsRepository` contract covering creation, retrieval, updating, deletion, and reordering of saved trips.
- Implement `SavedTripsRepositoryImpl` utilizing local SQLite storage (via Drift) for instant offline reads and bidirectional sync with Supabase Postgres `public.saved_trips` when authenticated.
- Provide guest / anonymous support (trips saved locally without login, seamlessly synced to Supabase upon sign-in).
- Add quick-save action in `MetroDeparturesScreen` to bookmark the currently viewed station as a trip with a single tap.
- Implement `SavedTripsScreen` displaying bookmarked journeys with live countdown departures, widget-enabled toggle, and swipe-to-delete.
- Implement Riverpod state providers managing saved trips reactive streams and mutations.

## Capabilities

### Modified Capabilities
- `saved-trips`: Refines saved trips specification with offline-first local cache fallback, anonymous guest persistence, and widget enablement flags.

## Impact

- **Database**: Relies on existing `public.saved_trips` table with Row Level Security (RLS) policies.
- **Local Database**: Adds `SavedTripsTable` to local Drift SQLite database for offline storage.
- **Domain Layer**: Adds `SavedTrip` entity and `SavedTripsRepository` contract.
- **Presentation Layer**: Adds `SavedTripsScreen`, `SaveTripDialog`, and integrates saved trips navigation.

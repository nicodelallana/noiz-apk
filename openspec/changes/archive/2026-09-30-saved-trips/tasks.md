# Tasks

## 1. Domain Models & Contracts

- [x] 1.1 Define pure domain models (`SavedTrip`, `TransitOperator`) in `lib/domain/models/saved_trip_models.dart` with immutability and equality operators
- [x] 1.2 Define `SavedTripsRepository` interface in `lib/domain/repositories/saved_trips_repository.dart` for offline-first CRUD, sync, and reordering

## 2. Local Database & Supabase Adapter

- [x] 2.1 Add `UserSavedTrips` table definition and typed query methods to `lib/data/local/app_database.dart`
- [x] 2.2 Implement `SavedTripsRepositoryImpl` in `lib/data/adapters/saved_trips_repository_impl.dart` with local Drift SQLite caching and Supabase Postgres sync
- [x] 2.3 Add unit tests in `test/unit/saved_trips_repository_test.dart` verifying local persistence, guest mode, and remote synchronization

## 3. Presentation Layer & State Management

- [x] 3.1 Implement Riverpod providers in `lib/presentation/providers/saved_trips_providers.dart` for saved trips reactive stream and mutations
- [x] 3.2 Implement `SaveTripDialog` in `lib/presentation/screens/saved_trips/save_trip_dialog.dart` to name and configure journeys
- [x] 3.3 Implement `SavedTripsScreen` in `lib/presentation/screens/saved_trips/saved_trips_screen.dart` with live countdown cards, widget toggle, and swipe deletion
- [x] 3.4 Connect favorite bookmark action in `MetroDeparturesScreen` and navigation tab to `SavedTripsScreen`

## 4. Verification & OpenSpec Validation

- [x] 4.1 Run `openspec validate saved-trips` to verify compliance with schema and specifications

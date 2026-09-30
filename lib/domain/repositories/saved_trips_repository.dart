import '../models/saved_trip_models.dart';

/// Contract for bookmarked journeys management.
/// Decoupled from SQLite storage and Supabase remote sync.
abstract interface class SavedTripsRepository {
  /// Reactive stream of saved journeys for the active user or local guest.
  /// Automatically emits updated lists when trips are added, modified, or reordered.
  Stream<List<SavedTrip>> watchSavedTrips({String? userId});

  /// Fetches current saved journeys snapshot.
  Future<List<SavedTrip>> getSavedTrips({String? userId});

  /// Retrieves a specific saved journey by its ID.
  Future<SavedTrip?> getSavedTripById(String id);

  /// Saves a new journey or updates an existing one in local cache and remote database.
  Future<void> saveTrip(SavedTrip trip);

  /// Deletes a saved journey by ID from both local storage and cloud.
  Future<void> deleteTrip(String tripId);

  /// Toggles whether this trip's next departure should be exported to the home-screen widget.
  Future<void> toggleWidgetEnabled(String tripId, bool enabled);

  /// Reorders saved journeys to update priority in "Mis viajes" and multi-trip widgets.
  Future<void> reorderTrips(List<String> orderedTripIds);

  /// Triggers background bidirectional synchronization with Supabase Postgres.
  Future<void> syncRemote();

  /// Migrates trips saved anonymously while in guest mode to an authenticated account.
  Future<void> migrateGuestTripsToUser(String userId);
}

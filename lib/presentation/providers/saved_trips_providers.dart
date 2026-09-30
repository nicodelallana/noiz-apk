import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/adapters/saved_trips_repository_impl.dart';
import '../../domain/models/saved_trip_models.dart';
import '../../domain/models/transit_models.dart';
import '../../domain/repositories/saved_trips_repository.dart';
import '../widgets/home_widget/widget_update_service.dart';
import 'auth_providers.dart';
import 'metro_providers.dart';

/// Provider exposing the saved trips repository.
final savedTripsRepositoryProvider = Provider<SavedTripsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = SavedTripsRepositoryImpl(database: db);

  // When user auth changes (e.g. guest signs in), trigger guest trips migration
  ref.listen(currentUserProfileProvider, (previous, next) {
    next.whenData((profile) {
      if (profile != null) {
        repo.migrateGuestTripsToUser(profile.id);
      }
    });
  });

  return repo;
});

/// Provider exposing the native widget update service.
final widgetUpdateServiceProvider = Provider<WidgetUpdateService>((ref) {
  final metroRepo = ref.watch(metroRepositoryProvider);
  final savedTripsRepo = ref.watch(savedTripsRepositoryProvider);
  return WidgetUpdateService(
    metroRepository: metroRepo,
    savedTripsRepository: savedTripsRepo,
  );
});

/// Reactive stream of saved journeys.
final savedTripsStreamProvider = StreamProvider<List<SavedTrip>>((ref) {
  final repo = ref.watch(savedTripsRepositoryProvider);
  return repo.watchSavedTrips();
});

/// Controller handling saved trip mutations.
class SavedTripsController extends StateNotifier<AsyncValue<void>> {
  SavedTripsController(this._repo, this._widgetService)
      : super(const AsyncValue.data(null));

  final SavedTripsRepository _repo;
  final WidgetUpdateService _widgetService;

  Future<void> saveTrip({
    required String name,
    required TransitOperator operator,
    required String originStopId,
    required String originStopName,
    required String destStopId,
    required String destStopName,
    String? routeId,
    int? directionId,
    bool widgetEnabled = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final trip = SavedTrip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '', // Repository resolves effective user
        name: name,
        operator: operator,
        originStopId: originStopId,
        originStopName: originStopName,
        destStopId: destStopId,
        destStopName: destStopName,
        routeId: routeId,
        directionId: directionId,
        widgetEnabled: widgetEnabled,
        sortOrder: 0,
        createdAt: DateTime.now(),
      );
      await _repo.saveTrip(trip);
      await _widgetService.update();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTrip(String tripId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteTrip(tripId);
      await _widgetService.update();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleWidget(String tripId, bool enabled) async {
    try {
      await _repo.toggleWidgetEnabled(tripId, enabled);
      await _widgetService.update();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncRemote() async {
    try {
      await _repo.syncRemote();
      await _widgetService.update();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final savedTripsControllerProvider =
    StateNotifierProvider<SavedTripsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(savedTripsRepositoryProvider);
  final widgetService = ref.watch(widgetUpdateServiceProvider);
  return SavedTripsController(repo, widgetService);
});

/// Future provider calculating next departure countdown for a specific saved trip.
final savedTripNextDepartureProvider =
    FutureProvider.family<Departure?, SavedTrip>((ref, trip) async {
  if (trip.operator != TransitOperator.metro) return null;

  final metroRepo = ref.watch(metroRepositoryProvider);
  final departures = await metroRepo.getDepartures(
    stationId: trip.originStopId,
    limit: 5,
  );

  if (departures.isEmpty) return null;

  // Filter by destination if headsign matches destination stop name
  final matching = departures.firstWhere(
    (d) => d.headsign.toLowerCase().contains(trip.destStopName.toLowerCase()),
    orElse: () => departures.first,
  );

  return matching;
});

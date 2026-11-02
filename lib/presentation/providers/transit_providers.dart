import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';
import 'package:bizkaia_transit/presentation/providers/metro_providers.dart';

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransitRepositoryImpl(database: db);
});

/// Active territory filter: Euskadi (all) | Bizkaia | Gipuzkoa | Araba
final selectedTerritoryProvider =
    StateProvider<TransitTerritory>((ref) => TransitTerritory.all);

/// Active operator filter within territory
final selectedOperatorProvider =
    StateProvider<TransitOperator>((ref) => TransitOperator.metro);

/// List of operators available under current territory
final operatorListProvider = Provider<List<TransitOperator>>((ref) {
  final territory = ref.watch(selectedTerritoryProvider);
  if (territory == TransitTerritory.all) {
    return TransitOperator.values;
  }
  return TransitOperator.values
      .where((op) => op.territory == territory)
      .toList();
});

/// User's current GPS location if location permission is granted
final userLocationProvider = StateProvider<UserLocation?>((ref) => null);

/// Active selected stop (origin) for departure display
final selectedTransitStopProvider = StateProvider<Stop?>((ref) => null);

/// Optional active destination stop filter ("de qué parada a qué parada")
final selectedDestinationStopProvider = StateProvider<Stop?>((ref) => null);

/// Stops for the currently selected operator
final stopsForActiveOperatorProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final operator = ref.watch(selectedOperatorProvider);
  final territory = ref.watch(selectedTerritoryProvider);

  final stops = await repo.getStops(
    operatorId: operator.id,
    territory: territory,
  );

  final current = ref.read(selectedTransitStopProvider);
  final userLoc = ref.read(userLocationProvider);

  if (stops.isNotEmpty &&
      (current == null || current.operatorId != operator.id)) {
    Stop bestStop = stops.first;
    if (userLoc != null) {
      bestStop = stops.reduce((a, b) {
        final aLat = a.latitude ?? 0.0;
        final aLon = a.longitude ?? 0.0;
        final bLat = b.latitude ?? 0.0;
        final bLon = b.longitude ?? 0.0;
        final da = (aLat - userLoc.latitude) * (aLat - userLoc.latitude) +
            (aLon - userLoc.longitude) * (aLon - userLoc.longitude);
        final db = (bLat - userLoc.latitude) * (bLat - userLoc.latitude) +
            (bLon - userLoc.longitude) * (bLon - userLoc.longitude);
        return da < db ? a : b;
      });
    }
    ref.read(selectedTransitStopProvider.notifier).state = bestStop;
    // Clear destination filter if switching operator
    ref.read(selectedDestinationStopProvider.notifier).state = null;
  }

  return stops;
});

/// Live departures for the actively selected stop, with optional destination filter
final departuresForActiveStopProvider =
    FutureProvider<List<Departure>>((ref) async {
  var stop = ref.watch(selectedTransitStopProvider);
  final destStop = ref.watch(selectedDestinationStopProvider);
  final repo = ref.watch(transitRepositoryProvider);
  final op = ref.watch(selectedOperatorProvider);

  if (stop == null || stop.operatorId != op.id) {
    final stops = await ref.watch(stopsForActiveOperatorProvider.future);
    if (stops.isEmpty) return [];
    stop = stops.first;
    Future.microtask(() {
      ref.read(selectedTransitStopProvider.notifier).state = stops.first;
    });
  }

  return repo.getDepartures(
    stopId: stop.id,
    destinationStopId: destStop?.id,
    operatorId: op.id,
  );
});

/// Nearby transit stops within walking distance, centered on user GPS if allowed
final nearbyStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final userLoc = ref.watch(userLocationProvider);
  final lat = userLoc?.latitude ?? 43.2630;
  final lon = userLoc?.longitude ?? -2.9347;

  return repo.getNearbyStops(
    latitude: lat,
    longitude: lon,
    radiusKm: 3.0,
  );
});

/// Service alerts across Euskadi filtered by territory
final serviceAlertsProvider =
    FutureProvider<List<ServiceAlert>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final territory = ref.watch(selectedTerritoryProvider);
  return repo.getServiceAlerts(territory: territory);
});

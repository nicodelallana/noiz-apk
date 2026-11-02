import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Active selected stop for departure display
final selectedTransitStopProvider = StateProvider<Stop?>((ref) => null);

/// Stops for the currently selected operator
final stopsForActiveOperatorProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final operator = ref.watch(selectedOperatorProvider);
  final territory = ref.watch(selectedTerritoryProvider);

  final stops = await repo.getStops(
    operatorId: operator.id,
    territory: territory,
  );

  // Auto-select first stop if none selected or if active stop belongs to another operator
  final current = ref.read(selectedTransitStopProvider);
  if (stops.isNotEmpty &&
      (current == null || current.operatorId != operator.id)) {
    ref.read(selectedTransitStopProvider.notifier).state = stops.first;
  }

  return stops;
});

/// Live departures for the actively selected stop
final departuresForActiveStopProvider =
    FutureProvider<List<Departure>>((ref) async {
  final stop = ref.watch(selectedTransitStopProvider);
  if (stop == null) return [];

  final repo = ref.watch(transitRepositoryProvider);
  final op = ref.watch(selectedOperatorProvider);

  return repo.getDepartures(
    stopId: stop.id,
    operatorId: op.id,
  );
});

/// Nearby transit stops within walking distance
final nearbyStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  // Default centered around Moyua Plaza / Bilbao core (supports real GPS if location allowed)
  return repo.getNearbyStops(
    latitude: 43.2630,
    longitude: -2.9347,
    radiusKm: 2.5,
  );
});

/// Service alerts across Euskadi filtered by territory
final serviceAlertsProvider =
    FutureProvider<List<ServiceAlert>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final territory = ref.watch(selectedTerritoryProvider);
  return repo.getServiceAlerts(territory: territory);
});

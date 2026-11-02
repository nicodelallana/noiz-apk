import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/constants/transit_constants.dart';
import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/core/utils/geo.dart';
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

/// Resolves the user's position once per session: shows only the system
/// permission dialog and, if it is denied or no fix arrives, silently falls
/// back to Plaza Moyúa (Bilbao) instead of surfacing an error.
final resolvedUserLocationProvider = FutureProvider<UserLocation>((ref) async {
  final service = ref.watch(locationServiceProvider);
  final granted =
      await service.hasPermission() || await service.requestPermission();
  if (granted) {
    final loc = await service.getCurrentLocation();
    if (loc != null) {
      ref.read(userLocationProvider.notifier).state = loc;
      return loc;
    }
  }
  return const UserLocation(
    latitude: TransitConstants.defaultLatitude,
    longitude: TransitConstants.defaultLongitude,
  );
});

/// Stops (all operators) within `radiusKm` of a point, for the map's first load.
final stopsAroundProvider = FutureProvider.family<List<Stop>,
    ({double lat, double lon, double radiusKm})>((ref, area) {
  final repo = ref.watch(transitRepositoryProvider);
  // 1° latitude ≈ 111 km; widen longitude by cos(lat) for the bounding box.
  final dLat = area.radiusKm / 111;
  final dLon = area.radiusKm / (111 * math.cos(area.lat * math.pi / 180));
  return repo
      .getStopsInBounds(
        minLat: area.lat - dLat,
        maxLat: area.lat + dLat,
        minLon: area.lon - dLon,
        maxLon: area.lon + dLon,
      )
      .then(
        (stops) => stops
            .where(
              (s) =>
                  haversineKm(area.lat, area.lon, s.latitude!, s.longitude!) <=
                  area.radiusKm,
            )
            .toList(),
      );
});

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

/// Upcoming departures for any stop, independent of the home screen selection
/// (map sheet, stop detail screen).
final departuresForStopProvider =
    FutureProvider.autoDispose.family<List<Departure>, Stop>((ref, stop) {
  return ref.watch(transitRepositoryProvider).getDepartures(
        stopId: stop.id,
        operatorId: stop.operatorId,
      );
});

/// Nearby transit stops within walking distance, centered on user GPS if allowed
final nearbyStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final userLoc = ref.watch(userLocationProvider);
  final lat = userLoc?.latitude ?? TransitConstants.defaultLatitude;
  final lon = userLoc?.longitude ?? TransitConstants.defaultLongitude;

  return repo.getNearbyStops(
    latitude: lat,
    longitude: lon,
    radiusKm: 3.0,
  );
});

/// Service alerts across all of Euskadi.
final serviceAlertsProvider =
    FutureProvider<List<ServiceAlert>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getServiceAlerts();
});

/// An alert paired with its closest affected stop and that stop's distance
/// (km) to the user; both null when no affected stop has coordinates.
typedef RankedAlert = ({
  ServiceAlert alert,
  Stop? nearestStop,
  double? distanceKm,
});

/// Alerts ranked by proximity: the closest affected stop of each alert is
/// measured against the user's position (or Plaza Moyúa as fallback).
final rankedServiceAlertsProvider =
    FutureProvider<List<RankedAlert>>((ref) async {
  final alerts = await ref.watch(serviceAlertsProvider.future);
  final here = await ref.watch(resolvedUserLocationProvider.future);
  final repo = ref.watch(transitRepositoryProvider);

  final ranked = <RankedAlert>[];
  for (final alert in alerts) {
    double? best;
    Stop? bestStop;
    for (final stopId in alert.affectedStopIds) {
      final stop = await repo.getStopById(stopId);
      if (stop?.latitude == null || stop?.longitude == null) continue;
      final d = haversineKm(
        here.latitude,
        here.longitude,
        stop!.latitude!,
        stop.longitude!,
      );
      if (best == null || d < best) {
        best = d;
        bestStop = stop;
      }
    }
    ranked.add((alert: alert, nearestStop: bestStop, distanceKm: best));
  }
  ranked.sort(
    (a, b) => (a.distanceKm ?? double.infinity)
        .compareTo(b.distanceKm ?? double.infinity),
  );
  return ranked;
});

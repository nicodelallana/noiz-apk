import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/constants/transit_constants.dart';
import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/core/utils/geo.dart';
import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/data/live/live_alerts.dart';
import 'package:bizkaia_transit/data/live/live_departures.dart';
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
/// Emits at every wall-clock minute, so countdowns stay true while a screen
/// is open (departures are recomputed and the minutes roll down).
final minuteTickProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;
  void tick() {
    final now = DateTime.now();
    controller.add(now);
    timer = Timer(
      Duration(milliseconds: 60000 - now.second * 1000 - now.millisecond),
      tick,
    );
  }

  tick();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

final liveDeparturesServiceProvider =
    Provider<LiveDeparturesService>((ref) => LiveDeparturesService());

final liveAlertsServiceProvider =
    Provider<LiveAlertsService>((ref) => LiveAlertsService());

/// Live departures first (Metro, Euskotren, trams: official GTFS-RT
/// predictions), the timetable otherwise. The live feed can't filter by
/// destination, so with a destination set the timetable answers.
Future<List<Departure>> _departuresFor(
  Ref ref,
  Stop stop, {
  required String operatorId,
  Stop? destination,
}) async {
  if (destination == null && LiveDeparturesService.supports(operatorId)) {
    final live =
        await ref.read(liveDeparturesServiceProvider).fetch(stop, operatorId);
    if (live != null) return live;
  }
  return ref.read(transitRepositoryProvider).getDepartures(
        stopId: stop.id,
        destinationStopId: destination?.id,
        operatorId: operatorId,
      );
}

final departuresForActiveStopProvider =
    FutureProvider<List<Departure>>((ref) async {
  ref.watch(minuteTickProvider);
  var stop = ref.watch(selectedTransitStopProvider);
  final destStop = ref.watch(selectedDestinationStopProvider);
  ref.watch(transitRepositoryProvider);
  final op = ref.watch(selectedOperatorProvider);

  if (stop == null || stop.operatorId != op.id) {
    final stops = await ref.watch(stopsForActiveOperatorProvider.future);
    if (stops.isEmpty) return [];
    stop = stops.first;
    Future.microtask(() {
      ref.read(selectedTransitStopProvider.notifier).state = stops.first;
    });
  }

  return _departuresFor(ref, stop, operatorId: op.id, destination: destStop);
});

/// Upcoming departures for any stop, independent of the home screen selection
/// (map sheet, stop detail screen).
final departuresForStopProvider =
    FutureProvider.autoDispose.family<List<Departure>, Stop>((ref, stop) {
  ref.watch(minuteTickProvider);
  ref.watch(transitRepositoryProvider);
  return _departuresFor(ref, stop, operatorId: stop.operatorId);
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
/// Official incidents in force (GTFS-RT Alerts), refreshed every 3 minutes
/// while watched. Failures surface as errors — never as "no incidents".
final liveAlertsProvider = FutureProvider<LiveAlerts>((ref) async {
  final timer = Timer(const Duration(minutes: 3), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(liveAlertsServiceProvider).fetch();
});

final serviceAlertsProvider =
    FutureProvider<List<ServiceAlert>>((ref) async {
  return (await ref.watch(liveAlertsProvider.future)).alerts;
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
    // Official alerts name their places; link the closest one to an app
    // stop within 400 m for "Ver parada".
    AlertLocation? bestPlace;
    for (final place in alert.locations) {
      final d = haversineKm(
        here.latitude,
        here.longitude,
        place.latitude,
        place.longitude,
      );
      if (best == null || d < best) {
        best = d;
        bestPlace = place;
      }
    }
    if (bestPlace != null) {
      const dDeg = 0.004;
      final candidates = await repo.getStopsInBounds(
        minLat: bestPlace.latitude - dDeg,
        maxLat: bestPlace.latitude + dDeg,
        minLon: bestPlace.longitude - dDeg,
        maxLon: bestPlace.longitude + dDeg,
      );
      var closest = 0.4;
      for (final s in candidates) {
        if (s.latitude == null || s.longitude == null) continue;
        final d = haversineKm(
          bestPlace.latitude,
          bestPlace.longitude,
          s.latitude!,
          s.longitude!,
        );
        if (d < closest) {
          closest = d;
          bestStop = s;
        }
      }
    }
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

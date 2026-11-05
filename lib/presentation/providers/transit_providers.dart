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

/// Active territory filter: Bizkaia | Gipuzkoa | Araba
final selectedTerritoryProvider =
    StateProvider<TransitTerritory>((ref) => TransitTerritory.bizkaia);

/// Active operator filter within territory
final selectedOperatorProvider =
    StateProvider<TransitOperator>((ref) => TransitOperator.metro);

/// List of operators available under current territory
final operatorListProvider = Provider<List<TransitOperator>>((ref) {
  final territory = ref.watch(selectedTerritoryProvider);
  return TransitOperator.byTerritory(territory);
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
      final current = ref.read(selectedTransitStopProvider);
      if (current == null) {
        final territory = TransitTerritory.territoryFromCoordinates(
          loc.latitude,
          loc.longitude,
        );
        ref.read(selectedTerritoryProvider.notifier).state = territory;
        final op = TransitTerritory.defaultOperatorFor(territory);
        ref.read(selectedOperatorProvider.notifier).state = op;
        final repo = ref.read(transitRepositoryProvider);
        final stops = await repo.getStops(operatorId: op.id);
        if (stops.isNotEmpty) {
          final best = stops.reduce((a, b) {
            final aLat = a.latitude ?? 0.0;
            final aLon = a.longitude ?? 0.0;
            final bLat = b.latitude ?? 0.0;
            final bLon = b.longitude ?? 0.0;
            final da = (aLat - loc.latitude) * (aLat - loc.latitude) +
                (aLon - loc.longitude) * (aLon - loc.longitude);
            final db = (bLat - loc.latitude) * (bLat - loc.latitude) +
                (bLon - loc.longitude) * (bLon - loc.longitude);
            return da < db ? a : b;
          });
          ref.read(selectedTransitStopProvider.notifier).state = best;
        }
      }
      return loc;
    }
  }
  const fallbackLoc = UserLocation(
    latitude: TransitConstants.defaultLatitude,
    longitude: TransitConstants.defaultLongitude,
  );
  if (ref.read(selectedTransitStopProvider) == null) {
    const op = TransitOperator.metro;
    ref.read(selectedTerritoryProvider.notifier).state = TransitTerritory.bizkaia;
    ref.read(selectedOperatorProvider.notifier).state = op;
    final repo = ref.read(transitRepositoryProvider);
    final stops = await repo.getStops(operatorId: op.id);
    if (stops.isNotEmpty) {
      final best = stops.reduce((a, b) {
        final aLat = a.latitude ?? 0.0;
        final aLon = a.longitude ?? 0.0;
        final bLat = b.latitude ?? 0.0;
        final bLon = b.longitude ?? 0.0;
        final da = (aLat - fallbackLoc.latitude) * (aLat - fallbackLoc.latitude) +
            (aLon - fallbackLoc.longitude) * (aLon - fallbackLoc.longitude);
        final db = (bLat - fallbackLoc.latitude) * (bLat - fallbackLoc.latitude) +
            (bLon - fallbackLoc.longitude) * (bLon - fallbackLoc.longitude);
        return da < db ? a : b;
      });
      ref.read(selectedTransitStopProvider.notifier).state = best;
    }
  }
  return fallbackLoc;
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

  return repo.getStops(
    operatorId: operator.id,
    territory: territory,
  );
});

/// Reachable destination stops from the active origin stop.
/// Only returns stops that can be reached on a direct trip on the same line.
final reachableDestinationsProvider = FutureProvider<List<Stop>>((ref) async {
  final origin = ref.watch(selectedTransitStopProvider);
  if (origin == null) return [];
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getReachableDestinations(originStopId: origin.id);
});

/// Search results across all operators by name, stop code, line code or synonyms
final globalStopSearchResultsProvider =
    FutureProvider.family<List<Stop>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getStops(searchQuery: trimmed);
});

/// Direct destinations from active origin matching a search query
final reachableDestinationsSearchProvider =
    FutureProvider.family<List<Stop>, String>((ref, query) async {
  final origin = ref.watch(selectedTransitStopProvider);
  if (origin == null) return const [];
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getReachableDestinations(
    originStopId: origin.id,
    searchQuery: query.trim().isEmpty ? null : query.trim(),
  );
});

/// Switches the active operator and resets selections according to business rules:
/// - Destination is always reset to null ("Todas las direcciones").
/// - If user GPS location is known, resolves and selects the closest stop of [newOperator].
/// - If no GPS location, resets origin stop to null so the user picks their stop cleanly.
Future<void> switchOperator(WidgetRef ref, TransitOperator newOperator) async {
  await _switchOperatorInternal(
    read: ref.read,
    newOperator: newOperator,
  );
}

Future<void> switchOperatorWithRef(Ref ref, TransitOperator newOperator) async {
  await _switchOperatorInternal(
    read: ref.read,
    newOperator: newOperator,
  );
}

Future<void> switchOperatorWithContainer(
    ProviderContainer container, TransitOperator newOperator) async {
  await _switchOperatorInternal(
    read: container.read,
    newOperator: newOperator,
  );
}

Future<void> _switchOperatorInternal({
  required T Function<T>(ProviderListenable<T>) read,
  required TransitOperator newOperator,
}) async {
  read(selectedOperatorProvider.notifier).state = newOperator;
  read(selectedDestinationStopProvider.notifier).state = null;

  final userLoc = read(userLocationProvider);
  if (userLoc != null) {
    final repo = read(transitRepositoryProvider);
    final stops = await repo.getStops(operatorId: newOperator.id);
    if (stops.isNotEmpty) {
      final best = stops.reduce((a, b) {
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
      read(selectedTransitStopProvider.notifier).state = best;
      return;
    }
  }
  read(selectedTransitStopProvider.notifier).state = null;
}

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
  final stop = ref.watch(selectedTransitStopProvider);
  final destStop = ref.watch(selectedDestinationStopProvider);
  ref.watch(transitRepositoryProvider);
  final op = ref.watch(selectedOperatorProvider);

  if (stop == null || stop.operatorId != op.id) {
    return [];
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

final serviceAlertsProvider = FutureProvider<List<ServiceAlert>>((ref) async {
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

// ── Map Hierarchy Providers (Modo → Operador → Línea) ──────────────────────

/// Active transit mode on the map: defaults to metro (fast load, no heavy 'all' query)
final mapSelectedModeProvider =
    StateProvider<TransitModeType?>((ref) => TransitModeType.metro);

/// Active operator filter on the map
final mapSelectedOperatorProvider =
    StateProvider<TransitOperator?>((ref) => TransitOperator.metro);

/// Active selected route on the map: null = no specific route selected
final mapSelectedRouteProvider = StateProvider<TransitRoute?>((ref) => null);

/// Operators matching the actively selected mode and territory
final mapFilteredOperatorsProvider = Provider<List<TransitOperator>>((ref) {
  final mode = ref.watch(mapSelectedModeProvider);
  final territory = ref.watch(selectedTerritoryProvider);

  var ops = TransitOperator.byTerritory(territory);
  if (mode != null) {
    ops = ops.where((o) => o.mode == mode).toList();
  }
  return ops;
});

/// Available routes for the actively selected operator / mode
final mapAvailableRoutesProvider =
    FutureProvider<List<TransitRoute>>((ref) async {
  final op = ref.watch(mapSelectedOperatorProvider);
  final mode = ref.watch(mapSelectedModeProvider);
  final territory = ref.watch(selectedTerritoryProvider);
  final repo = ref.watch(transitRepositoryProvider);

  return repo.getRoutes(
    operatorId: op?.id,
    mode: mode?.id,
    territory: territory,
  );
});

/// Shape coordinates [lon, lat] for the actively selected route
final mapRouteShapeProvider = FutureProvider<List<List<double>>>((ref) async {
  final route = ref.watch(mapSelectedRouteProvider);
  if (route == null) return [];
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getRouteShape(route.id);
});

/// Stops along the actively selected route
final mapRouteStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final route = ref.watch(mapSelectedRouteProvider);
  if (route == null) return [];
  final repo = ref.watch(transitRepositoryProvider);
  return repo.getStopsForRoute(route.id);
});

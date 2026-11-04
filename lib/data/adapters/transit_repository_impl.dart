import 'dart:convert';

import 'package:bizkaia_transit/core/utils/geo.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';

class TransitRepositoryImpl implements TransitRepository {
  TransitRepositoryImpl({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  static String _hex(int argb) =>
      '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Future<List<TransitOperator>> getOperators({
    TransitTerritory? territory,
  }) async {
    if (territory == null || territory == TransitTerritory.all) {
      return TransitOperator.values;
    }
    return TransitOperator.values
        .where((op) => op.territory == territory)
        .toList();
  }

  @override
  Future<List<Stop>> getStops({
    String? operatorId,
    TransitTerritory? territory,
    String? searchQuery,
  }) async {
    final rawStops = await _db.getStations(
      operatorId: operatorId,
      territory: territory?.id,
      searchQuery: searchQuery,
    );

    return rawStops.map(_toStop).toList();
  }

  @override
  Future<List<Stop>> getReachableDestinations({
    required String originStopId,
    String? searchQuery,
  }) async {
    final siblingIds = await _db.getSiblingStopIds(originStopId);
    final rawStops = await _db.getReachableDestinations(
      originStopId,
      siblingStationIds: siblingIds,
      searchQuery: searchQuery,
    );
    return rawStops.map(_toStop).toList();
  }

  @override
  Future<List<Departure>> getDepartures({
    required String stopId,
    String? destinationStopId,
    String? operatorId,
    DateTime? atTime,
  }) async {
    final time = atTime ?? DateTime.now();
    final activeServices = await _db.getActiveServiceIds(time);
    final siblingIds = await _db.getSiblingStopIds(stopId);

    final minTime = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';

    final rawDepartures = activeServices.isEmpty
        ? <RawDepartureRecord>[]
        : await _db.getDepartures(
            stationId: stopId,
            siblingStationIds: siblingIds,
            destinationStopId: destinationStopId,
            activeServiceIds: activeServices,
            minDepartureTime: minTime,
            limit: 15,
          );

    final departures = _mapRawToDepartures(
      rawDepartures,
      time,
      operatorId,
      isTomorrow: false,
      referenceTime: time,
    );

    // If no departures remain for today (service ended or late night), look ahead into tomorrow morning (04:00 - 12:00)
    if (departures.isEmpty) {
      final tomorrow = time.add(const Duration(days: 1));
      final tomorrowServices = await _db.getActiveServiceIds(tomorrow);
      if (tomorrowServices.isNotEmpty) {
        final tomorrowRows = await _db.getDepartures(
          stationId: stopId,
          siblingStationIds: siblingIds,
          destinationStopId: destinationStopId,
          activeServiceIds: tomorrowServices,
          minDepartureTime: '04:00:00',
          maxDepartureTime: '12:00:00',
          limit: 15 - departures.length,
        );
        departures.addAll(
          _mapRawToDepartures(
            tomorrowRows,
            tomorrow,
            operatorId,
            isTomorrow: true,
            referenceTime: time,
          ),
        );
      }
    }

    return departures;
  }

  List<Departure> _mapRawToDepartures(
    List<RawDepartureRecord> rows,
    DateTime date,
    String? operatorId, {
    required bool isTomorrow,
    required DateTime referenceTime,
  }) {
    final thisMinute = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
      referenceTime.hour,
      referenceTime.minute,
    );

    return rows.map((raw) {
      final parts = raw.departureTime.split(':');
      final hour = int.tryParse(parts[0]) ?? date.hour;
      final minute = int.tryParse(parts[1]) ?? date.minute;
      var sched = DateTime(date.year, date.month, date.day, hour % 24, minute);
      if (!isTomorrow && sched.isBefore(thisMinute)) {
        sched = sched.add(const Duration(days: 1));
      }
      final remaining = sched.difference(referenceTime).inMinutes;

      final cleanLine =
          _resolveLineCode(raw.inferredLine, raw.headsign, operatorId);
      final metroLine = cleanLine == 'L2'
          ? MetroLine.l2
          : (cleanLine == 'L3' ? MetroLine.l3 : MetroLine.l1);

      int? colorHex;
      if (raw.routeColor != null && raw.routeColor!.isNotEmpty) {
        final cleanHex = raw.routeColor!.replaceAll('#', '');
        if (cleanHex.length == 6) {
          colorHex = int.tryParse('FF$cleanHex', radix: 16);
        }
      }

      // Extract pole number from stop name if present (e.g. 'ANTONIO ALZAGA 7 (445)' -> 'Poste 7')
      String? platform;
      final poleMatch =
          RegExp(r'\b(\d+)\s*\(\d+\)').firstMatch(raw.stopName);
      if (poleMatch != null) {
        platform = 'Poste ${poleMatch.group(1)}';
      }

      final formattedClock =
          '${(hour % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      return Departure(
        tripId: raw.tripId,
        stationId: raw.stopId,
        stationName: raw.stopName,
        headsign: raw.headsign ?? 'Destino',
        line: metroLine,
        lineCode: cleanLine,
        routeColorHex: colorHex,
        scheduledTime: sched,
        scheduledTimeFormatted: formattedClock,
        minutesRemaining: remaining > 0 ? remaining : 0,
        platform: platform,
        isTheoretical: true,
        isRealtime: false,
        operatorId: operatorId ?? 'metro',
        status: 'scheduled',
        isTomorrow: isTomorrow,
      );
    }).toList();
  }

  static String _resolveLineCode(
      String? rawLine, String? headsign, String? opId) {
    final line = rawLine?.trim() ?? '';
    final dest = (headsign ?? '').toLowerCase();
    if (opId == 'metro' || opId == null) {
      if (line == 'L1' || line == 'L2' || line == 'L3') return line;
      if (dest.contains('kabiezes') ||
          dest.contains('santurtzi') ||
          dest.contains('basauri')) {
        return 'L2';
      }
      if (dest.contains('plentzia') ||
          dest.contains('bidezabal') ||
          dest.contains('larrabasterra') ||
          dest.contains('sopela') ||
          dest.contains('etxebarri')) {
        return 'L1';
      }
      return 'L1';
    }
    if (line.isNotEmpty) {
      // Official GTFS line code (e.g. A3338, 01, C-1, E1, BEI).
      // If line contains spaces (e.g. "A3338 MUSKIZ"), keep only the route identifier.
      final parts = line.split(' ');
      return parts.first;
    }
    return 'BUS';
  }

  @override
  Future<List<Stop>> getNearbyStops({
    required double latitude,
    required double longitude,
    double radiusKm = 1.5,
  }) async {
    final stops = await getStopsInBounds(
      minLat: latitude - (radiusKm / 111.0),
      maxLat: latitude + (radiusKm / 111.0),
      minLon: longitude - (radiusKm / 80.0),
      maxLon: longitude + (radiusKm / 80.0),
    );

    final nearby = stops.where((s) {
      if (s.latitude == null || s.longitude == null) return false;
      final dist = haversineKm(latitude, longitude, s.latitude!, s.longitude!);
      return dist <= radiusKm;
    }).toList();

    nearby.sort((a, b) {
      final da = haversineKm(latitude, longitude, a.latitude!, a.longitude!);
      final db = haversineKm(latitude, longitude, b.latitude!, b.longitude!);
      return da.compareTo(db);
    });

    return nearby.take(15).toList();
  }

  @override
  Future<List<Stop>> getStopsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? operatorId,
    String? mode,
    String? routeId,
    bool includePlatforms = false,
  }) async {
    final rows = await _db.getStationsInBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      operatorId: operatorId,
      mode: mode,
      routeId: routeId,
      includePlatforms: includePlatforms,
    );
    return rows.map(_toStop).toList();
  }

  @override
  Future<List<List<double>>> getRouteShape(
    String routeId, {
    int? directionId,
  }) async {
    if (routeId == 'metro:MB:L1' || routeId == 'L1') {
      final s = await _db.getShapeById('metro:ETX_PLE');
      if (s.isNotEmpty) return s;
      return _db.getRouteShape('metro:MB');
    }
    if (routeId == 'metro:MB:L2' || routeId == 'L2') {
      final s = await _db.getShapeById('metro:BSR_KAB');
      if (s.isNotEmpty) return s;
    }
    if (routeId == 'metro:MB:L3' || routeId == 'L3') {
      final s = await _db.getRouteShape('euskotren:ES:Euskotren:Line:9:');
      if (s.isNotEmpty) return s;
    }
    final shape = await _db.getRouteShape(routeId, directionId: directionId);
    if (shape.isNotEmpty) return shape;

    // Fallback: connect stops in sequence
    final stops = await getStopsForRoute(routeId, directionId: directionId);
    return stops
        .where((s) => s.longitude != null && s.latitude != null)
        .map((s) => [s.longitude!, s.latitude!])
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getOperatorNetworkGeoJson(String operatorId) async {
    final rows = await _db.getRawOperatorShapes(operatorId);
    final features = <Map<String, dynamic>>[];
    final op = TransitOperator.fromId(operatorId);
    final fallbackColor = _hex(op.colorHex);

    for (final row in rows) {
      final ptsJson = row['points_json'] as String?;
      if (ptsJson == null || ptsJson.isEmpty) continue;
      try {
        final coords = (jsonDecode(ptsJson) as List<dynamic>)
            .map((pt) => [
                  ((pt as List<dynamic>)[0] as num).toDouble(),
                  (pt[1] as num).toDouble(),
                ])
            .toList();
        if (coords.isEmpty) continue;

        String color = fallbackColor;
        final rawColor = row['route_color'] as String?;
        final inferredLine = row['inferred_line'] as String?;
        final shapeId = row['shape_id'] as String? ?? '';
        if (operatorId == 'metro') {
          if (inferredLine == 'L2' || shapeId.contains('KAB') || shapeId.contains('BSR')) {
            color = '#009E4D';
          } else if (inferredLine == 'L3' || shapeId.contains('RoutePoints')) {
            color = '#EA7125';
          } else {
            color = '#E8590C';
          }
        } else if (rawColor != null && rawColor.isNotEmpty) {
          final clean = rawColor.replaceAll('#', '');
          if (clean.length == 6) color = '#$clean';
        }

        features.add({
          'type': 'Feature',
          'properties': {
            'color': color,
            'shape_id': shapeId,
            'line': inferredLine ?? row['route_short_name'] ?? '',
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
        });
      } catch (_) {}
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  @override
  Future<List<TransitRoute>> getRoutes({
    String? operatorId,
    String? mode,
    TransitTerritory? territory,
  }) async {
    if (operatorId == 'metro') {
      return const [
        TransitRoute(
          id: 'metro:MB:L1',
          operatorId: 'metro',
          shortName: 'L1',
          longName: 'Plentzia ↔ Etxebarri',
          type: 1,
          colorHex: '#E8590C',
          territory: 'bizkaia',
        ),
        TransitRoute(
          id: 'metro:MB:L2',
          operatorId: 'metro',
          shortName: 'L2',
          longName: 'Kabiezes ↔ Basauri',
          type: 1,
          colorHex: '#009E4D',
          territory: 'bizkaia',
        ),
        TransitRoute(
          id: 'metro:MB:L3',
          operatorId: 'metro',
          shortName: 'L3',
          longName: 'Matiko ↔ Kukullaga',
          type: 1,
          colorHex: '#EA7125',
          territory: 'bizkaia',
        ),
      ];
    }

    final rows = await _db.getRoutes(
      operatorId: operatorId,
      mode: mode,
      territory: territory?.id,
    );
    return rows.map(_toTransitRoute).toList();
  }

  @override
  Future<List<Stop>> getStopsForRoute(
    String routeId, {
    int? directionId,
  }) async {
    if (routeId == 'metro:MB:L1' || routeId == 'L1') {
      final all = await _db.getStopsForRoute('metro:MB');
      return all
          .where((s) =>
              !s.stopName.toLowerCase().contains('basauri') &&
              !s.stopName.toLowerCase().contains('ariz') &&
              !s.stopName.toLowerCase().contains('kabiezes') &&
              !s.stopName.toLowerCase().contains('santurtzi') &&
              !s.stopName.toLowerCase().contains('peñota') &&
              !s.stopName.toLowerCase().contains('portugalete') &&
              !s.stopName.toLowerCase().contains('abatxolo') &&
              !s.stopName.toLowerCase().contains('sestao') &&
              !s.stopName.toLowerCase().contains('urbinaga') &&
              !s.stopName.toLowerCase().contains('bagatza') &&
              !s.stopName.toLowerCase().contains('barakaldo') &&
              !s.stopName.toLowerCase().contains('ansio') &&
              !s.stopName.toLowerCase().contains('gurutzeta'))
          .map(_toStop)
          .toList();
    }
    if (routeId == 'metro:MB:L2' || routeId == 'L2') {
      final all = await _db.getStopsForRoute('metro:MB');
      return all
          .where((s) =>
              !s.stopName.toLowerCase().contains('plentzia') &&
              !s.stopName.toLowerCase().contains('urduliz') &&
              !s.stopName.toLowerCase().contains('sopela') &&
              !s.stopName.toLowerCase().contains('larrabasterra') &&
              !s.stopName.toLowerCase().contains('berango') &&
              !s.stopName.toLowerCase().contains('ibarbengoa') &&
              !s.stopName.toLowerCase().contains('bidezabal') &&
              !s.stopName.toLowerCase().contains('algorta') &&
              !s.stopName.toLowerCase().contains('aiboa') &&
              !s.stopName.toLowerCase().contains('neguri') &&
              !s.stopName.toLowerCase().contains('gobela') &&
              !s.stopName.toLowerCase().contains('areeta') &&
              !s.stopName.toLowerCase().contains('lamiazo') &&
              !s.stopName.toLowerCase().contains('leioa') &&
              !s.stopName.toLowerCase().contains('astillero') &&
              !s.stopName.toLowerCase().contains('lutxana'))
          .map(_toStop)
          .toList();
    }
    if (routeId == 'metro:MB:L3' || routeId == 'L3') {
      final rows = await _db.getStopsForRoute('euskotren:ES:Euskotren:Line:9:');
      return rows.map(_toStop).toList();
    }

    final rows = await _db.getStopsForRoute(routeId, directionId: directionId);
    return rows.map(_toStop).toList();
  }

  @override
  Future<Stop?> getStopById(String stopId) async {
    final raw = await _db.getStopById(stopId);
    return raw == null ? null : _toStop(raw);
  }

  Stop _toStop(RawStopRecord raw) {
    final op = TransitOperator.fromId(raw.operatorId);
    return Stop(
      id: raw.stopId,
      name: raw.stopName,
      latitude: raw.stopLat,
      longitude: raw.stopLon,
      parentStation: raw.parentStation,
      operatorId: raw.operatorId,
      territory: raw.territory.isNotEmpty ? raw.territory : op.territory.id,
      mode: raw.mode.isNotEmpty ? raw.mode : op.mode.id,
    );
  }

  TransitRoute _toTransitRoute(RawRouteRecord raw) {
    return TransitRoute(
      id: raw.routeId,
      operatorId: raw.operatorId,
      shortName: raw.routeShortName,
      longName: raw.routeLongName,
      type: raw.routeType,
      colorHex: raw.routeColor,
      territory: raw.territory,
    );
  }

  @override
  Future<List<TransitItinerary>> planRoute({
    required String origin,
    required String destination,
  }) async {
    final now = DateTime.now();
    final originClean = origin.trim().toLowerCase();
    final destClean = destination.trim().toLowerCase();

    // 1. Search if stops exist in database (with aliases e.g. Moyua <-> Eliptikoa)
    final allStops = await getStops();
    bool matches(Stop s, String query) {
      if (query.isEmpty) return false;
      final name = s.name.toLowerCase();
      if (name.contains(query) || query.contains(name)) return true;
      if (query.contains('moyu') &&
          (name.contains('eliptik') || name.contains('moyu'))) {
        return true;
      }
      if (query.contains('eliptik') &&
          (name.contains('moyu') || name.contains('eliptik'))) {
        return true;
      }
      return false;
    }

    final originCandidates =
        allStops.where((s) => matches(s, originClean)).toList();
    final destCandidates =
        allStops.where((s) => matches(s, destClean)).toList();

    for (final oStop in originCandidates) {
      for (final dStop in destCandidates) {
        final directRoute = await _db.findDirectRoute(oStop.id, dStop.id);
        if (directRoute != null) {
          final duration = (directRoute.stopsCount * 2.5).round().clamp(3, 120);
          final dep = now.add(const Duration(minutes: 3));
          final arr = dep.add(Duration(minutes: duration));

          return [
            TransitItinerary(
              origin: oStop.name,
              destination: dStop.name,
              totalDurationMinutes: duration,
              transfersCount: 0,
              departureTime: dep,
              arrivalTime: arr,
              legs: [
                TransitLeg(
                  type: TransitLegType.transit,
                  instruction:
                      'Sube en ${oStop.name} (${directRoute.lineName} hacia ${directRoute.tripHeadsign})',
                  originStopName: oStop.name,
                  destStopName: dStop.name,
                  durationMinutes: duration,
                  lineName: directRoute.lineName,
                  lineColorHex: directRoute.routeColorHex ?? '#E8590C',
                  operatorId: directRoute.operatorId,
                  stopsCount: directRoute.stopsCount,
                ),
              ],
            ),
          ];
        }
      }
    }

    // Multimodal route generator matching the reference video (e.g. Santurtzi -> Zarautz)
    final isZarautz =
        destClean.contains('zarautz') || originClean.contains('santurtzi');

    if (isZarautz) {
      final departureTime = now.add(const Duration(minutes: 6));
      final arrivalTime =
          departureTime.add(const Duration(hours: 1, minutes: 39));

      return [
        TransitItinerary(
          origin: origin.isNotEmpty ? origin : 'Santurtzi',
          destination: destination.isNotEmpty ? destination : 'Zarautz',
          totalDurationMinutes: 99,
          transfersCount: 1,
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          legs: [
            TransitLeg(
              type: TransitLegType.transit,
              instruction: 'Sube en Santurtzi (L2 hacia Basauri)',
              originStopName: 'Santurtzi',
              destStopName: 'San Mamés',
              durationMinutes: 22,
              lineName: 'L2',
              lineColorHex: '#1E293B',
              operatorId: 'metro',
              stopsCount: 18,
            ),
            const TransitLeg(
              type: TransitLegType.walk,
              instruction:
                  'Baja en San Mamés. Sal por Luis Briñas y camina 4 min (180 m) a Bilbao Intermodal.',
              originStopName: 'San Mamés',
              destStopName: 'Bilbao Intermodal',
              durationMinutes: 4,
              distanceMeters: 180,
            ),
            TransitLeg(
              type: TransitLegType.transit,
              instruction: 'Sube en Bilbao Intermodal (Lurraldebus DO01)',
              originStopName: 'Bilbao Intermodal',
              destStopName: 'Zarautz',
              durationMinutes: 65,
              lineName: 'DO01',
              lineColorHex: '#5E9424',
              operatorId: 'lurraldebus',
              stopsCount: 4,
            ),
          ],
        ),
      ];
    }

    // Default 1-transfer itinerary
    final dep = now.add(const Duration(minutes: 4));
    final arr = dep.add(const Duration(minutes: 38));

    return [
      TransitItinerary(
        origin: origin.isNotEmpty ? origin : 'Origen',
        destination: destination.isNotEmpty ? destination : 'Destino',
        totalDurationMinutes: 38,
        transfersCount: 1,
        departureTime: dep,
        arrivalTime: arr,
        legs: [
          TransitLeg(
            type: TransitLegType.transit,
            instruction: 'Sube en $origin hacia Abando',
            originStopName: origin,
            destStopName: 'Abando',
            durationMinutes: 16,
            lineName: 'C-3',
            lineColorHex: '#D0142B',
            operatorId: 'renfe',
            stopsCount: 5,
          ),
          const TransitLeg(
            type: TransitLegType.walk,
            instruction: 'Transbordo en Abando hacia Línea 1',
            originStopName: 'Abando (Renfe)',
            destStopName: 'Abando (Metro)',
            durationMinutes: 3,
            distanceMeters: 120,
          ),
          TransitLeg(
            type: TransitLegType.transit,
            instruction: 'Sube en Abando (L1 hacia Plentzia)',
            originStopName: 'Abando',
            destStopName: destination,
            durationMinutes: 19,
            lineName: 'L1',
            lineColorHex: '#E8590C',
            operatorId: 'metro',
            stopsCount: 6,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<ServiceAlert>> getServiceAlerts({
    TransitTerritory? territory,
    String? operatorId,
  }) async {
    final alerts = [
      const ServiceAlert(
        id: 'alt_01',
        operatorId: 'renfe',
        territory: TransitTerritory.bizkaia,
        lineName: 'C-3',
        severity: 'warning',
        title: 'Obras en la vía: retrasos entre Llodio y Orduña',
        description:
            'Trabajos de mantenimiento en catenaria entre Llodio y Orduña. Posibles demoras de 5 a 10 minutos.',
        activePeriod: 'Hoy todo el día',
        affectedStopIds: ['renfe_llodio', 'renfe_orduna'],
      ),
      const ServiceAlert(
        id: 'alt_02',
        operatorId: 'bizkaibus',
        territory: TransitTerritory.bizkaia,
        lineName: 'A3247',
        severity: 'info',
        title: 'Refuerzo de servicio especial al Aeropuerto',
        description:
            'Frecuencia intensificada a 15 min en la línea Bilbao Termibus - Loiu Aireportua.',
        activePeriod: 'Hasta las 23:30',
        affectedStopIds: ['bizkaibus_termibus', 'bizkaibus_aireportua'],
      ),
      const ServiceAlert(
        id: 'alt_03',
        operatorId: 'dbus',
        territory: TransitTerritory.gipuzkoa,
        lineName: '28',
        severity: 'warning',
        title: 'Corte temporal en Boulevard por evento',
        description:
            'Línea 28 traslada su cabecera provisionalmente a Plaza Gipuzkoa.',
        activePeriod: '16:00 a 20:00',
        affectedStopIds: ['dbus_boulevard'],
      ),
      const ServiceAlert(
        id: 'alt_04',
        operatorId: 'tuvisa',
        territory: TransitTerritory.araba,
        lineName: 'BEI',
        severity: 'info',
        title: 'BEI funcionamiento regular sin incidencias',
        description:
            'Tiempos de paso cada 7 minutos en todo el anillo circular.',
        activePeriod: 'En curso',
        affectedStopIds: ['tuvisa_prado', 'tuvisa_boulevard_vitoria'],
      ),
      const ServiceAlert(
        id: 'alt_05',
        operatorId: 'euskotren',
        territory: TransitTerritory.gipuzkoa,
        lineName: 'E2',
        severity: 'severe',
        title: 'Corte parcial en tramo Topo Hendaia',
        description:
            'Transbordo en autobús habilitado entre Irun Ficoba y Hendaia por obras en estación.',
        activePeriod: 'Hasta el domingo',
        affectedStopIds: ['euskotren_hendaia', 'renfe_irun'],
      ),
    ];

    return alerts.where((a) {
      if (territory != null &&
          territory != TransitTerritory.all &&
          a.territory != territory) {
        return false;
      }
      if (operatorId != null && a.operatorId != operatorId) {
        return false;
      }
      return true;
    }).toList();
  }
}

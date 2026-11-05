import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';

import 'transit_database_accuracy_test.dart';

class FakeTransitRepository implements TransitRepository {
  FakeTransitRepository({
    this.stopsToReturn = const [],
    this.reachableToReturn = const [],
  });

  final List<Stop> stopsToReturn;
  final List<Stop> reachableToReturn;

  @override
  Future<List<Stop>> getReachableDestinations({
    required String originStopId,
    String? searchQuery,
    String? lineFilter,
  }) async {
    return reachableToReturn;
  }

  @override
  Future<List<Stop>> getStops({
    String? operatorId,
    TransitTerritory? territory,
    String? searchQuery,
  }) async {
    return stopsToReturn;
  }

  @override
  Future<List<Departure>> getDepartures({
    required String stopId,
    String? destinationStopId,
    String? operatorId,
    DateTime? atTime,
    String? lineFilter,
  }) async =>
      [];

  @override
  Future<List<String>> getServedLinesForStation(String stationId) async => [];

  @override
  Future<List<List<List<double>>>> getRouteShapes(String routeId,
          {int? directionId}) async =>
      [];

  @override
  Future<List<Stop>> getNearbyStops({
    required double latitude,
    required double longitude,
    double radiusKm = 1.5,
  }) async =>
      [];

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
  }) async =>
      [];

  @override
  Future<List<List<double>>> getRouteShape(String routeId,
          {int? directionId}) async =>
      [];

  @override
  Future<List<TransitRoute>> getRoutes({
    String? operatorId,
    String? mode,
    TransitTerritory? territory,
  }) async =>
      [];

  @override
  Future<List<Stop>> getStopsForRoute(String routeId,
          {int? directionId}) async =>
      [];

  @override
  Future<Stop?> getStopById(String stopId) async => null;

  @override
  Future<Map<String, dynamic>> getOperatorNetworkGeoJson(
          String operatorId) async =>
      {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

  @override
  Future<List<TransitItinerary>> planRoute({
    required String origin,
    required String destination,
  }) async =>
      [];

  @override
  Future<List<ServiceAlert>> getServiceAlerts({
    TransitTerritory? territory,
    String? operatorId,
  }) async =>
      [];

  @override
  Future<List<TransitOperator>> getOperators(
          {TransitTerritory? territory}) async =>
      TransitOperator.values;
}

void main() {
  group('Smart Reachable Destinations & Query Tests', () {
    test('getReachableDestinations executes SQL matching direct trips only',
        () async {
      String? executedSql;
      List<Object?>? executedArgs;

      final db = AppDatabase(
        executor: MockQueryExecutor(
          customSelectHandler: (sql, args) async {
            executedSql = sql;
            executedArgs = args;
            return [
              {
                'stop_id': 'metro:9',
                'operator_id': 'metro',
                'stop_name': 'Abando',
                'stop_lat': 43.261,
                'stop_lon': -2.927,
                'zone_id': '1',
                'parent_station': null,
                'territory': 'bizkaia',
                'mode': 'metro',
                'location_type': 1,
              },
            ];
          },
        ),
      );

      final results = await db.getReachableDestinations('metro:8');
      expect(results, hasLength(1));
      expect(results.first.stopName, equals('Abando'));
      expect(executedSql, contains('stop_sequence > st1.stop_sequence'));
      expect(executedSql, contains('parent.stop_id != s1.stop_id'));
      expect(executedArgs, equals(['metro:8', 'metro:8']));
    });

    test(
        'TransitRepositoryImpl getReachableDestinations maps raw records to domain Stop',
        () async {
      final db = AppDatabase(
        executor: MockQueryExecutor(
          customSelectHandler: (sql, args) async => [
            {
              'stop_id': 'bizkaibus:1067',
              'operator_id': 'bizkaibus',
              'stop_name': 'El Crucero',
              'stop_lat': 43.32,
              'stop_lon': -3.12,
              'zone_id': '3',
              'parent_station': null,
              'territory': 'bizkaia',
              'mode': 'bus',
              'location_type': 0,
            },
          ],
        ),
      );

      final repo = TransitRepositoryImpl(database: db);
      final reachable =
          await repo.getReachableDestinations(originStopId: 'bizkaibus:1066');

      expect(reachable, hasLength(1));
      expect(reachable.first.id, equals('bizkaibus:1067'));
      expect(reachable.first.name, equals('El Crucero'));
      expect(reachable.first.operatorId, equals('bizkaibus'));
    });
  });

  group('Operator Switch & Automatic Selection Reset Tests', () {
    test(
        'switchOperator resets destination and sets origin to closest stop when GPS fix exists',
        () async {
      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(
            FakeTransitRepository(
              stopsToReturn: const [
                Stop(
                  id: 'bizkaibus:stop1',
                  name: 'Far Stop',
                  latitude: 43.50,
                  longitude: -3.00,
                  operatorId: 'bizkaibus',
                ),
                Stop(
                  id: 'bizkaibus:stop2',
                  name: 'Near Stop',
                  latitude: 43.26,
                  longitude: -2.93,
                  operatorId: 'bizkaibus',
                ),
              ],
            ),
          ),
          userLocationProvider.overrideWith(
            (ref) => const UserLocation(latitude: 43.261, longitude: -2.931),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-set some old selection
      container.read(selectedTransitStopProvider.notifier).state = const Stop(
        id: 'metro:8',
        name: 'Moyua',
        operatorId: 'metro',
      );
      container.read(selectedDestinationStopProvider.notifier).state =
          const Stop(
        id: 'metro:9',
        name: 'Abando',
        operatorId: 'metro',
      );

      // Switch to Bizkaibus
      await switchOperatorWithContainer(container, TransitOperator.bizkaibus);

      expect(container.read(selectedOperatorProvider),
          equals(TransitOperator.bizkaibus));
      // Destination is always reset to null ("Todas las direcciones")
      expect(container.read(selectedDestinationStopProvider), isNull);
      // Origin is automatically set to the closest stop of the new operator
      expect(
          container.read(selectedTransitStopProvider)?.id, equals('bizkaibus:stop2'));
    });

    test(
        'switchOperator resets destination and sets origin to null when no GPS fix exists',
        () async {
      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(
            FakeTransitRepository(
              stopsToReturn: const [
                Stop(
                  id: 'bizkaibus:stop1',
                  name: 'Far Stop',
                  latitude: 43.50,
                  longitude: -3.00,
                  operatorId: 'bizkaibus',
                ),
              ],
            ),
          ),
          // User location is null (no GPS)
          userLocationProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      // Pre-set old selection
      container.read(selectedTransitStopProvider.notifier).state = const Stop(
        id: 'metro:8',
        name: 'Moyua',
        operatorId: 'metro',
      );
      container.read(selectedDestinationStopProvider.notifier).state =
          const Stop(
        id: 'metro:9',
        name: 'Abando',
        operatorId: 'metro',
      );

      // Switch to Bizkaibus without GPS
      await switchOperatorWithContainer(container, TransitOperator.bizkaibus);

      expect(container.read(selectedOperatorProvider),
          equals(TransitOperator.bizkaibus));
      expect(container.read(selectedDestinationStopProvider), isNull);
      expect(container.read(selectedTransitStopProvider), isNull);
    });
  });

  group('Official Line Codes & No Improvised Abbreviations Tests', () {
    test(
        'getDepartures returns official route_short_name without artificial truncation',
        () async {
      final db = AppDatabase(
        executor: MockQueryExecutor(
          customSelectHandler: (sql, args) async {
            if (sql.contains('FROM calendar')) {
              return [
                {'service_id': 'srv_1'},
              ];
            }
            if (sql.contains('FROM stop_times st')) {
              expect(sql, contains('JOIN routes r ON t.route_id = r.route_id'));
              return [
                {
                  'trip_id': 'bizkaibus:trp_1',
                  'departure_time': '12:30:00',
                  'stop_id': 'bizkaibus:1066',
                  'stop_name': 'Muskiz',
                  'trip_headsign': 'BILBAO (Termibus)',
                  'inferred_line': 'A3338',
                  'parent_station': null,
                  'route_color': '#2E9E4F',
                },
              ];
            }
            return [];
          },
        ),
      );

      final repo = TransitRepositoryImpl(database: db);
      final deps = await repo.getDepartures(
        stopId: 'bizkaibus:1066',
        operatorId: 'bizkaibus',
        atTime: DateTime(2026, 11, 4, 12, 0),
      );

      expect(deps, hasLength(1));
      final dep = deps.first;
      // Must be the official line code A3338, never "MUSK" or truncated
      expect(dep.lineCode, equals('A3338'));
      expect(dep.headsign, equals('BILBAO (Termibus)'));
      expect(dep.operatorId, equals('bizkaibus'));
      expect(dep.routeColorHex, equals(0xFF2E9E4F));
    });
  });
}

import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class MockQueryExecutor extends QueryExecutor {
  MockQueryExecutor({this.customSelectHandler});

  final Future<List<Map<String, Object?>>> Function(
    String sql,
    List<Object?> args,
  )? customSelectHandler;

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    if (customSelectHandler != null) {
      return customSelectHandler!(statement, args);
    }
    return [];
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;
}

void main() {
  group('Transit Database Accuracy & Query Tests', () {
    test('getStationsInBounds builds query with routeId, operator and mode filters', () async {
      String? capturedSql;
      List<Object?>? capturedArgs;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          capturedSql = sql;
          capturedArgs = args;
          return [
            {
              'stop_id': 'bizkaibus:1001',
              'operator_id': 'bizkaibus',
              'stop_name': 'Gran Vía 45',
              'stop_lat': 43.2625,
              'stop_lon': -2.9360,
              'zone_id': '1',
              'parent_station': null,
              'territory': 'bizkaia',
              'mode': 'bus',
              'location_type': 0,
            }
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);

      final stops = await db.getStationsInBounds(
        minLat: 43.2,
        maxLat: 43.3,
        minLon: -3.0,
        maxLon: -2.9,
        routeId: 'bizkaibus:A3115',
      );

      expect(stops.length, 1);
      expect(stops.first.stopId, 'bizkaibus:1001');
      expect(stops.first.mode, 'bus');
      expect(capturedSql, contains('JOIN trips t ON st.trip_id = t.trip_id'));
      expect(capturedSql, contains('WHERE t.route_id = ?'));
      expect(capturedArgs, contains('bizkaibus:A3115'));
    });

    test('getRouteShape decodes json polyline coordinates correctly', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          return [
            {
              'points_json': '[[-2.935, 43.262], [-2.936, 43.263], [-2.937, 43.264]]',
            }
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final coords = await db.getRouteShape('metro:L1', directionId: 0);

      expect(coords.length, 3);
      expect(coords[0], [-2.935, 43.262]);
      expect(coords[2], [-2.937, 43.264]);
    });

    test('getRoutes returns parsed RawRouteRecord list', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          return [
            {
              'route_id': 'metro:L1',
              'operator_id': 'metro',
              'route_short_name': 'L1',
              'route_long_name': 'Plentzia - Etxebarri',
              'route_type': 1,
              'route_color': '#E2001A',
              'territory': 'bizkaia',
            }
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final routes = await db.getRoutes(operatorId: 'metro', mode: 'metro');

      expect(routes.length, 1);
      expect(routes.first.routeShortName, 'L1');
      expect(routes.first.routeColor, '#E2001A');
    });

    test('getStopsForRoute orders by stop_sequence and deduplicates', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          return [
            {
              'stop_id': 'metro:1',
              'operator_id': 'metro',
              'stop_name': 'Etxebarri',
              'stop_lat': 43.245,
              'stop_lon': -2.898,
              'stop_sequence': 1,
            },
            {
              'stop_id': 'metro:1',
              'operator_id': 'metro',
              'stop_name': 'Etxebarri',
              'stop_lat': 43.245,
              'stop_lon': -2.898,
              'stop_sequence': 1,
            },
            {
              'stop_id': 'metro:2',
              'operator_id': 'metro',
              'stop_name': 'Bolueta',
              'stop_lat': 43.249,
              'stop_lon': -2.903,
              'stop_sequence': 2,
            },
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final stops = await db.getStopsForRoute('metro:L1');

      expect(stops.length, 2);
      expect(stops[0].stopName, 'Etxebarri');
      expect(stops[1].stopName, 'Bolueta');
    });

    test('TransitRepositoryImpl returns empty list without synthetic fallback when no departures exist', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          // Calendar active query
          if (sql.contains('FROM calendar')) {
            return [
              {'service_id': 'metro:regular'}
            ];
          }
          // No departures remaining
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = TransitRepositoryImpl(database: db);

      final departures = await repo.getDepartures(
        stopId: 'metro:6',
        operatorId: 'metro',
      );

      // Must be empty, never inventing fake 06:00 departures
      expect(departures, isEmpty);
    });
  });
}

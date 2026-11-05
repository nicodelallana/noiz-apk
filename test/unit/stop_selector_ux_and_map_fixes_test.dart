import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';

import 'smart_destinations_and_overhaul_test.dart';
import 'transit_database_accuracy_test.dart';

void main() {
  group('Stop Selector UX & Strict Operator Scoping Tests', () {
    test('getStations does not search by numeric stop_id or stop code', () async {
      String? executedSql;
      List<Object?>? executedArgs;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          executedSql = sql;
          executedArgs = args;
          return [
            {
              'stop_id': 'bizkaibus:1065',
              'operator_id': 'bizkaibus',
              'stop_name': 'El Campillo',
              'stop_lat': 43.32,
              'stop_lon': -3.12,
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
      await db.getStations(
        operatorId: 'bizkaibus',
        searchQuery: '1065',
      );

      expect(executedSql, isNotNull);
      // Ensure stop_id LIKE ? is not in the SQL query
      expect(executedSql!.contains('s.stop_id LIKE ?'), isFalse);
      expect(executedSql!.contains('sib.stop_id LIKE ?'), isFalse);
    });

    test('stopsForActiveOperatorSearchProvider scopes query strictly to active operator', () async {
      String? capturedOperatorId;
      String? capturedQuery;

      final fakeRepo = _ScopingFakeTransitRepository(
        onGetStops: ({operatorId, territory, searchQuery}) async {
          capturedOperatorId = operatorId;
          capturedQuery = searchQuery;
          return [
            const Stop(
              id: 'bizkaibus:1065',
              name: 'El Campillo (Muskiz)',
              operatorId: 'bizkaibus',
            ),
          ];
        },
      );

      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(fakeRepo),
          selectedOperatorProvider.overrideWith((ref) => TransitOperator.bizkaibus),
          selectedTerritoryProvider.overrideWith((ref) => TransitTerritory.bizkaia),
        ],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        stopsForActiveOperatorSearchProvider('Muskiz').future,
      );

      expect(results.length, 1);
      expect(results.first.operatorId, 'bizkaibus');
      expect(capturedOperatorId, 'bizkaibus');
      expect(capturedQuery, 'Muskiz');
    });

    test('getServedLinesForStation returns lines serving the station', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('SELECT DISTINCT COALESCE')) {
            return [
              {'line_name': 'A2336'},
              {'line_name': 'A3336'},
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final lines = await db.getServedLinesForStation('bizkaibus:1065');

      expect(lines, containsAll(['A2336', 'A3336']));
    });

    test('getRouteShapes retrieves all distinct shape paths for route', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('FROM trips t') && sql.contains('JOIN shapes s')) {
            return [
              {
                'points_json': '[[ -3.12, 43.32 ], [ -3.11, 43.31 ]]',
              },
              {
                'points_json': '[[ -3.11, 43.31 ], [ -3.12, 43.32 ]]',
              },
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final shapes = await db.getRouteShapes('bizkaibus:3336');

      expect(shapes.length, 2);
      expect(shapes[0].length, 2);
      expect(shapes[1].length, 2);
    });

    test('switchOperator clears active line filter', () async {
      final container = ProviderContainer(
        overrides: [
          transitRepositoryProvider.overrideWithValue(FakeTransitRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Set active line filter
      container.read(selectedLineFilterProvider.notifier).state = 'A3336';
      expect(container.read(selectedLineFilterProvider), 'A3336');

      // Switch operator to metro
      await switchOperatorWithContainer(container, TransitOperator.metro);

      // Line filter should be reset to null
      expect(container.read(selectedLineFilterProvider), isNull);
    });
  });
}

class _ScopingFakeTransitRepository extends FakeTransitRepository {
  _ScopingFakeTransitRepository({required this.onGetStops});

  final Future<List<Stop>> Function({
    String? operatorId,
    TransitTerritory? territory,
    String? searchQuery,
  }) onGetStops;

  @override
  Future<List<Stop>> getStops({
    String? operatorId,
    TransitTerritory? territory,
    String? searchQuery,
  }) {
    return onGetStops(
      operatorId: operatorId,
      territory: territory,
      searchQuery: searchQuery,
    );
  }
}

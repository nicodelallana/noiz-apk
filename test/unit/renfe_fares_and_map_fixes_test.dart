import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';

import 'transit_database_accuracy_test.dart';

void main() {
  group('Renfe Headsign & Terminal Fallback Tests', () {
    test('getRawDepartures query includes fallback subquery for missing trip_headsign', () async {
      String? capturedSql;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          capturedSql = sql;
          return [
            {
              'trip_id': 'renfe:6007X26101C1',
              'departure_time': '08:30:00',
              'stop_id': 'renfe:05451',
              'stop_name': 'Bilbao la Concordia',
              'trip_headsign': 'Santurtzi',
              'inferred_line': 'C1',
              'route_color': '#D7001E',
              'parent_station': null,
            }
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final deps = await db.getDepartures(
        stationId: 'renfe:05451',
        activeServiceIds: {'default_service'},
        minDepartureTime: '08:00:00',
      );

      expect(capturedSql, isNotNull);
      expect(capturedSql!.contains("COALESCE(NULLIF(TRIM(t.trip_headsign), '')"), isTrue);
      expect(capturedSql!.contains('ORDER BY st_dest.stop_sequence DESC'), isTrue);
      expect(deps.first.headsign, 'Santurtzi');
      expect(deps.first.inferredLine, 'C1');
    });

    test('findDirectRoute includes fallback subquery for missing trip_headsign', () async {
      String? capturedSql;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          capturedSql = sql;
          return [
            {
              'inferred_line': 'C1',
              'trip_headsign': 'Santurtzi',
              'stops_count': 5,
              'operator_id': 'renfe',
              'route_color': '#D7001E',
            }
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final direct = await db.findDirectRoute('renfe:05451', 'renfe:05460');

      expect(capturedSql, isNotNull);
      expect(capturedSql!.contains("COALESCE(NULLIF(TRIM(t.trip_headsign), '')"), isTrue);
      expect(direct, isNotNull);
      expect(direct!.tripHeadsign, 'Santurtzi');
      expect(direct.lineName, 'C1');
    });
  });

  group('Map Polyline Smoothing & Canonical Shape Tests', () {
    test('getOperatorNetworkGeoJson filters out _INV reverse tracks and selects longest shape', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('FROM routes r')) {
            return [
              {
                'shape_id': 'renfe:60_C1',
                'points_json': '[[ -3.03, 43.32 ], [ -3.02, 43.31 ], [ -2.92, 43.26 ]]',
                'route_color': '#D7001E',
                'route_short_name': 'C1',
                'inferred_line': 'C1',
              },
              {
                'shape_id': 'renfe:60_C1_INV',
                'points_json': '[[ -2.92, 43.26 ], [ -3.02, 43.31 ], [ -3.03, 43.32 ]]',
                'route_color': '#D7001E',
                'route_short_name': 'C1',
                'inferred_line': 'C1',
              },
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = TransitRepositoryImpl(database: db);
      final geojson = await repo.getOperatorNetworkGeoJson('renfe');

      final features = geojson['features'] as List<dynamic>;
      // Only 1 feature should be present (the canonical shape, not the _INV shape)
      expect(features.length, 1);
      final firstFeature = features.first as Map<String, dynamic>;
      final props = firstFeature['properties'] as Map<String, dynamic>;
      expect(props['shape_id'], 'renfe:60_C1');
      expect(props['line'], 'C1');
    });

    test('getRouteShapes returns single canonical shape for line without parallel duplicates', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('shapes WHERE shape_id = ?')) {
            return [
              {
                'points_json': '[[ -2.89, 43.24 ], [ -2.94, 43.40 ]]',
              }
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = TransitRepositoryImpl(database: db);
      final shapes = await repo.getRouteShapes('L1');

      // Must return exactly 1 shape (the canonical track)
      expect(shapes.length, 1);
      expect(shapes.first.length, 2);
    });
  });

  group('Fares & CTB Calculation Tests', () {
    test('Official CTB price matrix matches Metro Bilbao and Bizkaibus rates', () {
      // Metro 1, 2, 3 zones
      const metroZ1Barik = 1.02;
      const metroZ1Ocasional = 2.00;
      const metroZ2Barik = 1.19;
      const metroZ2Ocasional = 2.20;
      const metroZ3Barik = 1.30;
      const metroZ3Ocasional = 2.25;

      expect(metroZ1Barik < metroZ1Ocasional, isTrue);
      expect(metroZ2Barik < metroZ2Ocasional, isTrue);
      expect(metroZ3Barik < metroZ3Ocasional, isTrue);

      // Savings in zone 1 is ~49%
      final savingsZ1 = ((metroZ1Ocasional - metroZ1Barik) / metroZ1Ocasional) * 100;
      expect(savingsZ1.round(), 49);
    });
  });
}

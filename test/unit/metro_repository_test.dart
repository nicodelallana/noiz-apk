import 'package:bizkaia_transit/data/adapters/metro_repository_impl.dart';
import 'package:bizkaia_transit/data/gtfs/schedule_sync_service.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class MockQueryExecutor extends QueryExecutor {
  MockQueryExecutor({
    this.customSelectHandler,
  });

  final Future<List<Map<String, Object?>>> Function(String sql, List<Object?> args)?
      customSelectHandler;

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

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

class FakeScheduleSyncService extends ScheduleSyncService {
  FakeScheduleSyncService({this.isReady = true})
      : super(
          storageBaseUrl: 'http://localhost',
          documentsDirectoryProvider: () async => throw UnimplementedError(),
        );

  final bool isReady;

  @override
  Future<bool> isDatabasePresent() async => isReady;
}

void main() {
  group('MetroRepositoryImpl - Timezone & Rollover Tests', () {
    test('toMadridTime accurately calculates UTC+2 during daylight saving time (September)', () {
      // 2026-09-30 06:00:00 UTC -> 08:00:00 Madrid (CEST, UTC+2)
      final utcTime = DateTime.utc(2026, 9, 30, 6, 0, 0);
      final madridTime = MetroRepositoryImpl.toMadridTime(utcTime);

      expect(madridTime.hour, 8);
      expect(madridTime.minute, 0);
      expect(madridTime.day, 30);
    });

    test('toMadridTime accurately calculates UTC+1 during standard time (December)', () {
      // 2026-12-15 06:00:00 UTC -> 07:00:00 Madrid (CET, UTC+1)
      final utcTime = DateTime.utc(2026, 12, 15, 6, 0, 0);
      final madridTime = MetroRepositoryImpl.toMadridTime(utcTime);

      expect(madridTime.hour, 7);
      expect(madridTime.minute, 0);
    });

    test('getStations performs accent-insensitive and case-insensitive search', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('FROM stops')) {
            return [
              {
                'stop_id': '35',
                'operator_id': 'metro',
                'stop_name': 'Bagatza',
                'stop_lat': 43.2988,
                'stop_lon': -2.9926,
                'zone_id': 'B2',
                'parent_station': '',
              },
              {
                'stop_id': '20',
                'operator_id': 'metro',
                'stop_name': 'San Mamés',
                'stop_lat': 43.2612,
                'stop_lon': -2.9498,
                'zone_id': 'A',
                'parent_station': '',
              },
            ];
          } else if (sql.contains('SELECT DISTINCT t.inferred_line')) {
            return [
              {'inferred_line': 'L2'},
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = MetroRepositoryImpl(
        database: db,
        syncService: FakeScheduleSyncService(),
      );

      // Search with accent
      final result1 = await repo.getStations(searchQuery: 'Mamés');
      expect(result1.length, 1);
      expect(result1.first.name, 'San Mamés');

      // Search without accent and lowercase
      final result2 = await repo.getStations(searchQuery: 'mames');
      expect(result2.length, 1);
      expect(result2.first.name, 'San Mamés');
    });

    test('getDepartures handles active service query and converts GTFS minutes correctly', () async {
      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('FROM stops') && sql.contains('WHERE stop_id = ?')) {
            return [
              {
                'stop_id': '35',
                'operator_id': 'metro',
                'stop_name': 'Bagatza',
                'stop_lat': 43.2988,
                'stop_lon': -2.9926,
                'zone_id': 'B2',
                'parent_station': '',
              }
            ];
          } else if (sql.contains('FROM stops')) {
            return [
              {
                'stop_id': '35',
                'operator_id': 'metro',
                'stop_name': 'Bagatza',
                'stop_lat': 43.2988,
                'stop_lon': -2.9926,
                'zone_id': 'B2',
                'parent_station': '',
              }
            ];
          } else if (sql.contains('FROM calendar')) {
            return [
              {'service_id': 'service_weekday'}
            ];
          } else if (sql.contains('FROM calendar_dates')) {
            return [];
          } else if (sql.contains('FROM stop_times')) {
            return [
              {
                'trip_id': 'trip_101',
                'departure_time': '10:15:00',
                'stop_id': '35.0',
                'stop_name': 'Bagatza',
                'trip_headsign': 'Kabiezes',
                'inferred_line': 'L2',
                'parent_station': '35',
              },
              {
                'trip_id': 'trip_102',
                'departure_time': '10:25:00',
                'stop_id': '35.0',
                'stop_name': 'Bagatza',
                'trip_headsign': 'Basauri',
                'inferred_line': 'L2',
                'parent_station': '35',
              },
            ];
          } else if (sql.contains('SELECT DISTINCT t.inferred_line')) {
            return [
              {'inferred_line': 'L2'}
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = MetroRepositoryImpl(
        database: db,
        syncService: FakeScheduleSyncService(),
      );

      // Baseline time: 10:05:00 Madrid
      final refTime = DateTime(2026, 9, 30, 10, 5, 0);

      final departures = await repo.getDepartures(
        stationId: '35',
        referenceTime: refTime,
      );

      expect(departures.length, 2);
      expect(departures[0].headsign, 'Kabiezes');
      expect(departures[0].line, MetroLine.l2);
      expect(departures[0].minutesRemaining, 10);
      expect(departures[0].scheduledTimeFormatted, '10:15');

      expect(departures[1].headsign, 'Basauri');
      expect(departures[1].line, MetroLine.l2);
      expect(departures[1].minutesRemaining, 20);
      expect(departures[1].scheduledTimeFormatted, '10:25');
    });

    test('getDepartures in midnight madrugada queries rollover trips from yesterday', () async {
      var queriedRollover = false;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          if (sql.contains('FROM calendar')) {
            return [
              {'service_id': 'svc_1'}
            ];
          } else if (sql.contains('FROM calendar_dates')) {
            return [];
          } else if (sql.contains('FROM stop_times')) {
            // Check if rollover hour > 24 was queried
            if (args.any((a) => a is String && a.startsWith('24:'))) {
              queriedRollover = true;
              return [
                {
                  'trip_id': 'night_trip_1',
                  'departure_time': '24:20:00',
                  'stop_id': '35.0',
                  'stop_name': 'Bagatza',
                  'trip_headsign': 'Kabiezes',
                  'inferred_line': 'L2',
                  'parent_station': '35',
                }
              ];
            }
            return [];
          } else if (sql.contains('FROM stops')) {
            return [
              {
                'stop_id': '35',
                'operator_id': 'metro',
                'stop_name': 'Bagatza',
                'stop_lat': 43.2988,
                'stop_lon': -2.9926,
                'zone_id': 'B2',
                'parent_station': '',
              }
            ];
          } else if (sql.contains('SELECT DISTINCT t.inferred_line')) {
            return [
              {'inferred_line': 'L2'}
            ];
          }
          return [];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = MetroRepositoryImpl(
        database: db,
        syncService: FakeScheduleSyncService(),
      );

      // Baseline time: 00:10:00 Madrid (current hour = 0 < 6)
      final refTime = DateTime(2026, 9, 30, 0, 10, 0);

      final departures = await repo.getDepartures(
        stationId: '35',
        referenceTime: refTime,
      );

      expect(queriedRollover, isTrue);
      expect(departures.length, 1);
      expect(departures.first.minutesRemaining, 10);
      expect(departures.first.scheduledTimeFormatted, '00:20');
    });
  });
}

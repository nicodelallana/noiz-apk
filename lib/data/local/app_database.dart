import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/transit_constants.dart';

/// Drift table definition for public transit operators.
@DataClassName('OperatorRecord')
class Operators extends Table {
  TextColumn get operatorId => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {operatorId};
}

/// Drift table definition for transit routes.
@DataClassName('RouteRecord')
class Routes extends Table {
  TextColumn get routeId => text()();
  TextColumn get operatorId => text()();
  TextColumn get routeShortName => text()();
  TextColumn get routeLongName => text()();
  IntColumn get routeType => integer()();
  TextColumn get routeColor => text().nullable()();

  @override
  Set<Column> get primaryKey => {routeId};
}

/// Drift table definition for physical stops and parent stations.
@DataClassName('StopRecord')
class Stops extends Table {
  TextColumn get stopId => text()();
  TextColumn get operatorId => text()();
  TextColumn get stopName => text()();
  RealColumn get stopLat => real()();
  RealColumn get stopLon => real()();
  TextColumn get zoneId => text().nullable()();
  TextColumn get parentStation => text().nullable()();

  @override
  Set<Column> get primaryKey => {stopId};
}

/// Drift table definition for trips.
@DataClassName('TripRecord')
class Trips extends Table {
  TextColumn get tripId => text()();
  TextColumn get routeId => text()();
  TextColumn get serviceId => text()();
  TextColumn get tripHeadsign => text().nullable()();
  IntColumn get directionId => integer().nullable()();
  TextColumn get inferredLine => text().nullable()();

  @override
  Set<Column> get primaryKey => {tripId};
}

/// Drift table definition for scheduled stop times.
@DataClassName('StopTimeRecord')
class StopTimes extends Table {
  TextColumn get tripId => text()();
  TextColumn get stopId => text()();
  IntColumn get stopSequence => integer()();
  TextColumn get arrivalTime => text()();
  TextColumn get departureTime => text()();

  @override
  Set<Column> get primaryKey => {tripId, stopSequence};
}

/// Drift table definition for regular weekly calendars.
@DataClassName('CalendarRecord')
class Calendar extends Table {
  TextColumn get serviceId => text()();
  IntColumn get monday => integer()();
  IntColumn get tuesday => integer()();
  IntColumn get wednesday => integer()();
  IntColumn get thursday => integer()();
  IntColumn get friday => integer()();
  IntColumn get saturday => integer()();
  IntColumn get sunday => integer()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();

  @override
  Set<Column> get primaryKey => {serviceId};
}

/// Drift table definition for calendar exception dates.
@DataClassName('CalendarDateRecord')
class CalendarDates extends Table {
  TextColumn get serviceId => text()();
  TextColumn get date => text()();
  IntColumn get exceptionType => integer()();

  @override
  Set<Column> get primaryKey => {serviceId, date};
}

/// Raw record representation of a stop/station in SQLite.
class RawStopRecord {
  const RawStopRecord({
    required this.stopId,
    required this.operatorId,
    required this.stopName,
    required this.stopLat,
    required this.stopLon,
    this.zoneId,
    this.parentStation,
  });

  factory RawStopRecord.fromMap(Map<String, Object?> map) {
    return RawStopRecord(
      stopId: map['stop_id']! as String,
      operatorId: map['operator_id']! as String,
      stopName: map['stop_name']! as String,
      stopLat: (map['stop_lat']! as num).toDouble(),
      stopLon: (map['stop_lon']! as num).toDouble(),
      zoneId: map['zone_id'] as String?,
      parentStation: map['parent_station'] as String?,
    );
  }

  final String stopId;
  final String operatorId;
  final String stopName;
  final double stopLat;
  final double stopLon;
  final String? zoneId;
  final String? parentStation;
}

/// Raw record representation of a departure query result.
class RawDepartureRecord {
  const RawDepartureRecord({
    required this.tripId,
    required this.departureTime,
    required this.stopId,
    required this.stopName,
    this.headsign,
    this.inferredLine,
    this.parentStation,
  });

  factory RawDepartureRecord.fromMap(Map<String, Object?> map) {
    return RawDepartureRecord(
      tripId: map['trip_id']! as String,
      departureTime: map['departure_time']! as String,
      stopId: map['stop_id']! as String,
      stopName: map['stop_name']! as String,
      headsign: map['trip_headsign'] as String?,
      inferredLine: map['inferred_line'] as String?,
      parentStation: map['parent_station'] as String?,
    );
  }

  final String tripId;
  final String departureTime;
  final String stopId;
  final String stopName;
  final String? headsign;
  final String? inferredLine;
  final String? parentStation;
}

/// SQLite Database client managing transit schedules.
/// Compatible with pre-populated `transit.sqlite` generated by gtfs-pipeline.
class AppDatabase {
  AppDatabase({
    QueryExecutor? executor,
    File? databaseFile,
  }) : _executor = executor ?? _createDefaultExecutor(databaseFile);

  final QueryExecutor _executor;
  bool _isOpen = false;

  static QueryExecutor _createDefaultExecutor(File? file) {
    if (file != null) {
      return NativeDatabase.createInBackground(file);
    }
    return LazyDatabase(() async {
      final docs = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(docs.path, TransitConstants.sqliteFileName));
      return NativeDatabase.createInBackground(dbFile);
    });
  }

  Future<void> _ensureOpen() async {
    if (!_isOpen) {
      await _executor.ensureOpen(
        GeneratedDatabase.fromExecutor(
          _executor,
        ),
      );
      _isOpen = true;
    }
  }

  /// Resolves active GTFS `service_id`s for a given calendar date (`YYYYMMDD`).
  ///
  /// Combines regular day-of-week active flags from `calendar` with exceptions
  /// in `calendar_dates` (1 = added, 2 = removed).
  Future<Set<String>> getActiveServiceIds(DateTime date) async {
    await _ensureOpen();

    final dateStr = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';

    final weekday = date.weekday;
    final dayColumn = switch (weekday) {
      DateTime.monday => 'monday',
      DateTime.tuesday => 'tuesday',
      DateTime.wednesday => 'wednesday',
      DateTime.thursday => 'thursday',
      DateTime.friday => 'friday',
      DateTime.saturday => 'saturday',
      DateTime.sunday => 'sunday',
      _ => 'monday',
    };

    // 1. Regular active services from calendar
    final calSql = '''
      SELECT service_id FROM calendar
      WHERE start_date <= ? AND end_date >= ? AND $dayColumn = 1
    ''';
    final calRows = await _executor.runSelect(calSql, [dateStr, dateStr]);
    final activeServices = <String>{
      for (final row in calRows) row['service_id']! as String,
    };

    // 2. Exception dates from calendar_dates
    final exceptionsSql = '''
      SELECT service_id, exception_type FROM calendar_dates
      WHERE date = ?
    ''';
    final exceptionRows = await _executor.runSelect(exceptionsSql, [dateStr]);
    for (final row in exceptionRows) {
      final serviceId = row['service_id']! as String;
      final type = row['exception_type']! as int;
      if (type == 1) {
        activeServices.add(serviceId);
      } else if (type == 2) {
        activeServices.remove(serviceId);
      }
    }

    return activeServices;
  }

  /// Retrieves stations for an operator. Parent stations or stops without parent.
  Future<List<RawStopRecord>> getStations({
    String operatorId = 'metro',
    String? searchQuery,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT stop_id, operator_id, stop_name, stop_lat, stop_lon, zone_id, parent_station
      FROM stops
      WHERE operator_id = ?
        AND (parent_station IS NULL OR parent_station = '')
    ''');
    final args = <Object?>[operatorId];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql.write(' AND LOWER(stop_name) LIKE ?');
      args.add('%${searchQuery.trim().toLowerCase()}%');
    }

    sql.write(' ORDER BY stop_name COLLATE NOCASE ASC');

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawStopRecord.fromMap).toList();
  }

  /// Looks up a single station or platform stop by ID.
  Future<RawStopRecord?> getStopById(String stopId) async {
    await _ensureOpen();

    const sql = '''
      SELECT stop_id, operator_id, stop_name, stop_lat, stop_lon, zone_id, parent_station
      FROM stops
      WHERE stop_id = ?
      LIMIT 1
    ''';
    final rows = await _executor.runSelect(sql, [stopId]);
    if (rows.isEmpty) return null;
    return RawStopRecord.fromMap(rows.first);
  }

  /// Resolves which lines (L1, L2) serve a specific station.
  Future<Set<String>> getServedLinesForStation(String stationId) async {
    await _ensureOpen();

    const sql = '''
      SELECT DISTINCT t.inferred_line
      FROM stop_times st
      JOIN trips t ON st.trip_id = t.trip_id
      JOIN stops s ON st.stop_id = s.stop_id
      WHERE (s.stop_id = ? OR s.parent_station = ?)
        AND t.inferred_line IS NOT NULL
    ''';
    final rows = await _executor.runSelect(sql, [stationId, stationId]);
    return {
      for (final r in rows)
        if (r['inferred_line'] != null) r['inferred_line']! as String,
    };
  }

  /// Queries upcoming scheduled departures for a station.
  ///
  /// Supports:
  /// - Multiple active service IDs (today + yesterday's rollover if midnight).
  /// - Time threshold filtering (e.g. >= 14:30:00).
  /// - Line filtering (e.g. 'L1' or 'L2').
  Future<List<RawDepartureRecord>> getDepartures({
    required String stationId,
    required Set<String> activeServiceIds,
    required String minDepartureTime,
    String? lineFilter,
    String? maxDepartureTime,
    int limit = 20,
  }) async {
    if (activeServiceIds.isEmpty) return [];
    await _ensureOpen();

    final servicePlaceholders = List.filled(activeServiceIds.length, '?').join(',');

    final sql = StringBuffer('''
      SELECT 
        st.trip_id,
        st.departure_time,
        s.stop_id,
        s.stop_name,
        t.trip_headsign,
        t.inferred_line,
        s.parent_station
      FROM stop_times st
      JOIN trips t ON st.trip_id = t.trip_id
      JOIN stops s ON st.stop_id = s.stop_id
      WHERE (s.stop_id = ? OR s.parent_station = ?)
        AND t.service_id IN ($servicePlaceholders)
        AND st.departure_time >= ?
    ''');

    final args = <Object?>[
      stationId,
      stationId,
      ...activeServiceIds,
      minDepartureTime,
    ];

    if (maxDepartureTime != null) {
      sql.write(' AND st.departure_time <= ?');
      args.add(maxDepartureTime);
    }

    if (lineFilter != null && lineFilter.isNotEmpty) {
      sql.write(' AND t.inferred_line = ?');
      args.add(lineFilter);
    }

    sql.write(' ORDER BY st.departure_time ASC LIMIT ?');
    args.add(limit);

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawDepartureRecord.fromMap).toList();
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_isOpen) {
      await _executor.close();
      _isOpen = false;
    }
  }
}

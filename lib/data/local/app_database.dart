import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
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

/// Drift table definition for locally cached saved journeys.
@DataClassName('UserSavedTripRecord')
class UserSavedTrips extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get operatorId => text()();
  TextColumn get originStopId => text()();
  TextColumn get originStopName => text()();
  TextColumn get destStopId => text()();
  TextColumn get destStopName => text()();
  TextColumn get routeId => text().nullable()();
  IntColumn get directionId => integer().nullable()();
  IntColumn get widgetEnabled => integer()();
  IntColumn get sortOrder => integer()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
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

/// Raw record representation of a saved journey in SQLite.
class RawSavedTripRecord {
  const RawSavedTripRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.operatorId,
    required this.originStopId,
    required this.originStopName,
    required this.destStopId,
    required this.destStopName,
    this.routeId,
    this.directionId,
    required this.widgetEnabled,
    required this.sortOrder,
    required this.createdAt,
  });

  factory RawSavedTripRecord.fromMap(Map<String, Object?> map) {
    return RawSavedTripRecord(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      name: map['name']! as String,
      operatorId: map['operator']! as String,
      originStopId: map['origin_stop_id']! as String,
      originStopName: map['origin_stop_name']! as String,
      destStopId: map['dest_stop_id']! as String,
      destStopName: map['dest_stop_name']! as String,
      routeId: map['route_id'] as String?,
      directionId: map['direction_id'] as int?,
      widgetEnabled: (map['widget_enabled']! as int) == 1,
      sortOrder: map['sort_order']! as int,
      createdAt: map['created_at']! as String,
    );
  }

  final String id;
  final String userId;
  final String name;
  final String operatorId;
  final String originStopId;
  final String originStopName;
  final String destStopId;
  final String destStopName;
  final String? routeId;
  final int? directionId;
  final bool widgetEnabled;
  final int sortOrder;
  final String createdAt;
}

final class _AppDbUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

/// SQLite Database client managing transit schedules and saved trips.
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
      final dbFile = File(p.join(docs.path, TransitConstants.sqliteDbFileName));
      try {
        final data = await rootBundle.load('assets/db/transit.sqlite');
        if (!dbFile.existsSync() || dbFile.lengthSync() != data.lengthInBytes) {
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await dbFile.writeAsBytes(bytes, flush: true);
        }
      } catch (_) {
        if (!dbFile.existsSync() || dbFile.lengthSync() < 1024) {
          try {
            final data = await rootBundle.load('assets/db/transit.sqlite');
            final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            await dbFile.writeAsBytes(bytes, flush: true);
          } catch (_) {}
        }
      }
      return NativeDatabase.createInBackground(dbFile);
    });
  }

  Future<void> _ensureOpen() async {
    if (!_isOpen) {
      await _executor.ensureOpen(_AppDbUser());
      // Ensure user_saved_trips table exists in local database
      await _executor.runCustom('''
        CREATE TABLE IF NOT EXISTS user_saved_trips (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          operator TEXT NOT NULL,
          origin_stop_id TEXT NOT NULL,
          origin_stop_name TEXT NOT NULL,
          dest_stop_id TEXT NOT NULL,
          dest_stop_name TEXT NOT NULL,
          route_id TEXT,
          direction_id INTEGER,
          widget_enabled INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        );
      ''');
      await _executor.runCustom('''
        CREATE INDEX IF NOT EXISTS idx_user_saved_trips_order 
        ON user_saved_trips (user_id, sort_order);
      ''');
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
      final serviceId = row['service_id'] as String?;
      final type = (row['exception_type'] as num?)?.toInt();
      if (serviceId == null || type == null) continue;
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

  /// Queries upcoming scheduled departures for a station, with optional destination filtering.
  Future<List<RawDepartureRecord>> getDepartures({
    required String stationId,
    required Set<String> activeServiceIds,
    required String minDepartureTime,
    String? destinationStopId,
    String? lineFilter,
    String? maxDepartureTime,
    int limit = 20,
  }) async {
    if (activeServiceIds.isEmpty) return [];
    await _ensureOpen();

    final servicePlaceholders =
        List.filled(activeServiceIds.length, '?').join(',');

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

    if (destinationStopId != null && destinationStopId.isNotEmpty) {
      sql.write('''
        AND EXISTS (
          SELECT 1 FROM stop_times dest_st
          WHERE dest_st.trip_id = st.trip_id
            AND dest_st.stop_id = ?
            AND dest_st.stop_sequence > st.stop_sequence
        )
      ''');
      args.add(destinationStopId);
    }

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

  /// Searches for a direct transit connection between two stops.
  Future<DirectRouteRecord?> findDirectRoute(String originStopId, String destStopId) async {
    await _ensureOpen();
    final rows = await _executor.runSelect('''
      SELECT 
        t.inferred_line, 
        t.trip_headsign, 
        (s2.stop_sequence - s1.stop_sequence) as stops_count,
        r.operator_id,
        r.route_color
      FROM stop_times s1
      JOIN stop_times s2 ON s1.trip_id = s2.trip_id AND s1.stop_sequence < s2.stop_sequence
      JOIN trips t ON s1.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
      WHERE (s1.stop_id = ? OR s1.stop_id LIKE ?)
        AND (s2.stop_id = ? OR s2.stop_id LIKE ?)
      LIMIT 1;
    ''', [originStopId, '%$originStopId%', destStopId, '%$destStopId%']);
    if (rows.isEmpty) return null;
    return DirectRouteRecord.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Saved Trips Queries (Local SQLite)
  // ---------------------------------------------------------------------------

  /// Retrieves saved trips for a user (or 'guest'), sorted by sort_order.
  Future<List<RawSavedTripRecord>> getSavedTrips(String userId) async {
    await _ensureOpen();

    const sql = '''
      SELECT id, user_id, name, operator, origin_stop_id, origin_stop_name,
             dest_stop_id, dest_stop_name, route_id, direction_id,
             widget_enabled, sort_order, created_at
      FROM user_saved_trips
      WHERE user_id = ?
      ORDER BY sort_order ASC, created_at DESC
    ''';
    final rows = await _executor.runSelect(sql, [userId]);
    return rows.map(RawSavedTripRecord.fromMap).toList();
  }

  /// Retrieves a single saved trip by ID.
  Future<RawSavedTripRecord?> getSavedTripById(String id) async {
    await _ensureOpen();

    const sql = '''
      SELECT id, user_id, name, operator, origin_stop_id, origin_stop_name,
             dest_stop_id, dest_stop_name, route_id, direction_id,
             widget_enabled, sort_order, created_at
      FROM user_saved_trips
      WHERE id = ?
      LIMIT 1
    ''';
    final rows = await _executor.runSelect(sql, [id]);
    if (rows.isEmpty) return null;
    return RawSavedTripRecord.fromMap(rows.first);
  }

  /// Inserts or replaces a saved trip in local SQLite.
  Future<void> insertOrUpdateSavedTrip(RawSavedTripRecord trip) async {
    await _ensureOpen();

    const sql = '''
      INSERT OR REPLACE INTO user_saved_trips (
        id, user_id, name, operator, origin_stop_id, origin_stop_name,
        dest_stop_id, dest_stop_name, route_id, direction_id,
        widget_enabled, sort_order, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''';
    await _executor.runCustom(sql, [
      trip.id,
      trip.userId,
      trip.name,
      trip.operatorId,
      trip.originStopId,
      trip.originStopName,
      trip.destStopId,
      trip.destStopName,
      trip.routeId,
      trip.directionId,
      trip.widgetEnabled ? 1 : 0,
      trip.sortOrder,
      trip.createdAt,
    ]);
  }

  /// Deletes a saved trip from local SQLite by ID.
  Future<void> deleteSavedTrip(String id) async {
    await _ensureOpen();
    await _executor
        .runCustom('DELETE FROM user_saved_trips WHERE id = ?;', [id]);
  }

  /// Updates widget enablement for a specific trip.
  Future<void> toggleTripWidget(String id, bool enabled) async {
    await _ensureOpen();
    await _executor.runCustom(
      'UPDATE user_saved_trips SET widget_enabled = ? WHERE id = ?;',
      [enabled ? 1 : 0, id],
    );
  }

  /// Updates sort order for a list of trip IDs.
  Future<void> reorderSavedTrips(List<String> orderedIds) async {
    await _ensureOpen();
    for (var i = 0; i < orderedIds.length; i++) {
      await _executor.runCustom(
        'UPDATE user_saved_trips SET sort_order = ? WHERE id = ?;',
        [i, orderedIds[i]],
      );
    }
  }

  /// Migrates trips owned by [oldUserId] (e.g. 'guest') to [newUserId].
  Future<void> updateTripUserId(String oldUserId, String newUserId) async {
    await _ensureOpen();
    await _executor.runCustom(
      'UPDATE user_saved_trips SET user_id = ? WHERE user_id = ?;',
      [newUserId, oldUserId],
    );
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_isOpen) {
      await _executor.close();
      _isOpen = false;
    }
  }
}

class DirectRouteRecord {
  const DirectRouteRecord({
    required this.lineName,
    required this.tripHeadsign,
    required this.stopsCount,
    required this.operatorId,
    this.routeColorHex,
  });

  factory DirectRouteRecord.fromMap(Map<String, dynamic> map) {
    return DirectRouteRecord(
      lineName: (map['inferred_line'] as String?) ?? 'Línea',
      tripHeadsign: (map['trip_headsign'] as String?) ?? 'Destino',
      stopsCount: (map['stops_count'] as num?)?.toInt() ?? 1,
      operatorId: (map['operator_id'] as String?) ?? 'metro',
      routeColorHex: map['route_color'] as String?,
    );
  }

  final String lineName;
  final String tripHeadsign;
  final int stopsCount;
  final String operatorId;
  final String? routeColorHex;
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'connection/open_connection.dart';

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
    this.territory = 'bizkaia',
    this.mode = 'bus',
    this.locationType = 0,
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
      territory: (map['territory'] as String?) ?? 'bizkaia',
      mode: (map['mode'] as String?) ?? 'bus',
      locationType: (map['location_type'] as num?)?.toInt() ?? 0,
    );
  }

  final String stopId;
  final String operatorId;
  final String stopName;
  final double stopLat;
  final double stopLon;
  final String? zoneId;
  final String? parentStation;
  final String territory;
  final String mode;
  final int locationType;
}

/// Raw record representation of a transit route in SQLite.
class RawRouteRecord {
  const RawRouteRecord({
    required this.routeId,
    required this.operatorId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    this.routeColor,
    required this.territory,
  });

  factory RawRouteRecord.fromMap(Map<String, Object?> map) {
    return RawRouteRecord(
      routeId: map['route_id']! as String,
      operatorId: map['operator_id']! as String,
      routeShortName: (map['route_short_name'] as String?) ?? '',
      routeLongName: (map['route_long_name'] as String?) ?? '',
      routeType: (map['route_type'] as num?)?.toInt() ?? 3,
      routeColor: map['route_color'] as String?,
      territory: (map['territory'] as String?) ?? 'bizkaia',
    );
  }

  final String routeId;
  final String operatorId;
  final String routeShortName;
  final String routeLongName;
  final int routeType;
  final String? routeColor;
  final String territory;
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
    this.routeColor,
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
      routeColor: map['route_color'] as String?,
    );
  }

  final String tripId;
  final String departureTime;
  final String stopId;
  final String stopName;
  final String? headsign;
  final String? inferredLine;
  final String? parentStation;
  final String? routeColor;
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
  }) : _executor = executor ?? openTransitDatabase(file: databaseFile);

  final QueryExecutor _executor;
  bool _isOpen = false;

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
    String? operatorId = 'metro',
    String? mode,
    String? territory,
    String? searchQuery,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT stop_id, operator_id, stop_name, stop_lat, stop_lon, zone_id,
             parent_station, territory, mode, location_type
      FROM stops
      WHERE (location_type = 1 OR parent_station IS NULL OR parent_station = '')
    ''');
    final args = <Object?>[];

    if (operatorId != null && operatorId.isNotEmpty) {
      sql.write(' AND operator_id = ?');
      args.add(operatorId);
    }

    if (mode != null && mode.isNotEmpty) {
      sql.write(' AND mode = ?');
      args.add(mode);
    }

    if (territory != null && territory.isNotEmpty && territory != 'all') {
      sql.write(' AND territory = ?');
      args.add(territory);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql.write(' AND LOWER(stop_name) LIKE ?');
      args.add('%${searchQuery.trim().toLowerCase()}%');
    }

    sql.write(' ORDER BY stop_name COLLATE NOCASE ASC');

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawStopRecord.fromMap).toList();
  }

  /// Stations and stops inside a lat/lon bounding box (map viewport).
  ///
  /// Can optionally filter by [operatorId], [mode], or [routeId].
  /// When filtering by [routeId], returns only stops serving that route.
  Future<List<RawStopRecord>> getStationsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? operatorId,
    String? mode,
    String? routeId,
    bool includePlatforms = false,
    int? limit,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer();
    final args = <Object?>[];

    if (routeId != null && routeId.isNotEmpty) {
      sql.write('''
        SELECT DISTINCT s.stop_id, s.operator_id, s.stop_name, s.stop_lat, s.stop_lon,
               s.zone_id, s.parent_station, s.territory, s.mode, s.location_type
        FROM stops s
        JOIN stop_times st ON s.stop_id = st.stop_id
        JOIN trips t ON st.trip_id = t.trip_id
        WHERE t.route_id = ?
          AND s.stop_lat BETWEEN ? AND ?
          AND s.stop_lon BETWEEN ? AND ?
      ''');
      args.addAll([routeId, minLat, maxLat, minLon, maxLon]);
    } else {
      sql.write('''
        SELECT stop_id, operator_id, stop_name, stop_lat, stop_lon,
               zone_id, parent_station, territory, mode, location_type
        FROM stops
        WHERE stop_lat BETWEEN ? AND ?
          AND stop_lon BETWEEN ? AND ?
      ''');
      args.addAll([minLat, maxLat, minLon, maxLon]);

      if (!includePlatforms) {
        sql.write(
            " AND (location_type = 1 OR parent_station IS NULL OR parent_station = '')");
      }

      if (operatorId != null && operatorId.isNotEmpty) {
        sql.write(' AND operator_id = ?');
        args.add(operatorId);
      }

      if (mode != null && mode.isNotEmpty) {
        sql.write(' AND mode = ?');
        args.add(mode);
      }
    }

    if (limit != null && limit > 0) {
      sql.write(' LIMIT ?');
      args.add(limit);
    }

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawStopRecord.fromMap).toList();
  }

  /// Looks up a single station or platform stop by ID.
  Future<RawStopRecord?> getStopById(String stopId) async {
    await _ensureOpen();

    const sql = '''
      SELECT stop_id, operator_id, stop_name, stop_lat, stop_lon,
             zone_id, parent_station, territory, mode, location_type
      FROM stops
      WHERE stop_id = ?
      LIMIT 1
    ''';
    final rows = await _executor.runSelect(sql, [stopId]);
    if (rows.isEmpty) return null;
    return RawStopRecord.fromMap(rows.first);
  }

  /// Retrieves the geographic shape (ordered list of [lon, lat] points) for a given [routeId].
  /// If [directionId] is provided, selects the shape corresponding to that direction.
  Future<List<List<double>>> getRouteShape(
    String routeId, {
    int? directionId,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT s.points_json
      FROM trips t
      JOIN shapes s ON t.shape_id = s.shape_id
      WHERE t.route_id = ?
    ''');
    final args = <Object?>[routeId];

    if (directionId != null) {
      sql.write(' AND t.direction_id = ?');
      args.add(directionId);
    }

    sql.write(' LIMIT 1');

    final rows = await _executor.runSelect(sql.toString(), args);
    if (rows.isEmpty) return [];

    final rawJson = rows.first['points_json'] as String?;
    if (rawJson == null || rawJson.isEmpty) return [];

    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map<List<double>>((pt) {
        final pair = pt as List<dynamic>;
        return [
          (pair[0] as num).toDouble(),
          (pair[1] as num).toDouble(),
        ];
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retrieves transit routes, with optional filtering by [operatorId], [mode], or [territory].
  Future<List<RawRouteRecord>> getRoutes({
    String? operatorId,
    String? mode,
    String? territory,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT r.route_id, r.operator_id, r.route_short_name, r.route_long_name,
             r.route_type, r.route_color, r.territory
      FROM routes r
    ''');
    final conditions = <String>[];
    final args = <Object?>[];

    if (operatorId != null && operatorId.isNotEmpty) {
      conditions.add('r.operator_id = ?');
      args.add(operatorId);
    }

    if (territory != null && territory.isNotEmpty && territory != 'all') {
      conditions.add('r.territory = ?');
      args.add(territory);
    }

    if (mode != null && mode.isNotEmpty) {
      // In GTFS: 0=tram, 1=metro, 2=rail, 3=bus, 7=funicular
      final routeType = switch (mode.toLowerCase()) {
        'tram' => 0,
        'metro' => 1,
        'train' || 'rail' => 2,
        'bus' => 3,
        'funicular' => 7,
        _ => null,
      };
      if (routeType != null) {
        conditions.add('r.route_type = ?');
        args.add(routeType);
      }
    }

    if (conditions.isNotEmpty) {
      sql.write(' WHERE ${conditions.join(' AND ')}');
    }

    sql.write(' ORDER BY r.route_short_name ASC, r.route_long_name ASC');

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawRouteRecord.fromMap).toList();
  }

  /// Retrieves ordered stops along a specific route and direction.
  Future<List<RawStopRecord>> getStopsForRoute(
    String routeId, {
    int? directionId,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT DISTINCT s.stop_id, s.operator_id, s.stop_name, s.stop_lat, s.stop_lon,
             s.zone_id, s.parent_station, s.territory, s.mode, s.location_type,
             st.stop_sequence
      FROM stops s
      JOIN stop_times st ON s.stop_id = st.stop_id
      JOIN trips t ON st.trip_id = t.trip_id
      WHERE t.route_id = ?
    ''');
    final args = <Object?>[routeId];

    if (directionId != null) {
      sql.write(' AND t.direction_id = ?');
      args.add(directionId);
    }

    sql.write(' ORDER BY st.stop_sequence ASC');

    final rows = await _executor.runSelect(sql.toString(), args);
    final seen = <String>{};
    final result = <RawStopRecord>[];
    for (final row in rows) {
      final stop = RawStopRecord.fromMap(row);
      if (seen.add(stop.stopId)) {
        result.add(stop);
      }
    }
    return result;
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
        COALESCE(NULLIF(r.route_short_name, ''), t.inferred_line, 'BUS') AS inferred_line,
        r.route_color,
        s.parent_station
      FROM stop_times st
      JOIN trips t ON st.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
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
          JOIN stops dest_s ON dest_st.stop_id = dest_s.stop_id
          WHERE dest_st.trip_id = st.trip_id
            AND (dest_s.stop_id = ? OR dest_s.parent_station = ?)
            AND dest_st.stop_sequence > st.stop_sequence
        )
      ''');
      args.addAll([destinationStopId, destinationStopId]);
    }

    if (maxDepartureTime != null) {
      sql.write(' AND st.departure_time <= ?');
      args.add(maxDepartureTime);
    }

    if (lineFilter != null && lineFilter.isNotEmpty) {
      sql.write('''
        AND (
          t.inferred_line = ? OR
          r.route_short_name = ?
        )
      ''');
      args.addAll([lineFilter, lineFilter]);
    }

    sql.write(' ORDER BY st.departure_time ASC LIMIT ?');
    args.add(limit);

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawDepartureRecord.fromMap).toList();
  }

  /// Retrieves all reachable destination stops from a given [originStopId]
  /// that can be reached on a direct trip (same line and trip with stop_sequence > origin).
  Future<List<RawStopRecord>> getReachableDestinations(
    String originStopId, {
    String? searchQuery,
  }) async {
    await _ensureOpen();

    final sql = StringBuffer('''
      SELECT DISTINCT 
        COALESCE(parent.stop_id, s2.stop_id) AS stop_id,
        COALESCE(parent.operator_id, s2.operator_id) AS operator_id,
        COALESCE(parent.stop_name, s2.stop_name) AS stop_name,
        COALESCE(parent.stop_lat, s2.stop_lat) AS stop_lat,
        COALESCE(parent.stop_lon, s2.stop_lon) AS stop_lon,
        COALESCE(parent.zone_id, s2.zone_id) AS zone_id,
        parent.parent_station,
        COALESCE(parent.territory, s2.territory) AS territory,
        COALESCE(parent.mode, s2.mode) AS mode,
        COALESCE(parent.location_type, s2.location_type) AS location_type
      FROM stop_times st1
      JOIN stop_times st2 ON st1.trip_id = st2.trip_id AND st2.stop_sequence > st1.stop_sequence
      JOIN stops s1 ON st1.stop_id = s1.stop_id
      JOIN stops s2 ON st2.stop_id = s2.stop_id
      LEFT JOIN stops parent ON s2.parent_station = parent.stop_id
      WHERE (s1.stop_id = ? OR s1.parent_station = ?)
        AND (parent.stop_id IS NULL OR (parent.stop_id != s1.stop_id AND parent.stop_id != s1.parent_station))
        AND (s2.stop_id != s1.stop_id AND (s1.parent_station IS NULL OR s2.stop_id != s1.parent_station))
    ''');
    final args = <Object?>[originStopId, originStopId];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql.write(' AND LOWER(COALESCE(parent.stop_name, s2.stop_name)) LIKE ?');
      args.add('%${searchQuery.trim().toLowerCase()}%');
    }

    sql.write(' ORDER BY stop_name COLLATE NOCASE ASC');

    final rows = await _executor.runSelect(sql.toString(), args);
    return rows.map(RawStopRecord.fromMap).toList();
  }

  /// Searches for a direct transit connection between two stops.
  Future<DirectRouteRecord?> findDirectRoute(
      String originStopId, String destStopId) async {
    await _ensureOpen();
    final rows = await _executor.runSelect('''
      SELECT 
        t.inferred_line, 
        t.trip_headsign, 
        (s2.stop_sequence - s1.stop_sequence) as stops_count,
        r.operator_id,
        r.route_color
      FROM stop_times s1
      JOIN stops st1 ON s1.stop_id = st1.stop_id
      JOIN stop_times s2 ON s1.trip_id = s2.trip_id AND s1.stop_sequence < s2.stop_sequence
      JOIN stops st2 ON s2.stop_id = st2.stop_id
      JOIN trips t ON s1.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
      WHERE (st1.stop_id = ? OR st1.parent_station = ?)
        AND (st2.stop_id = ? OR st2.parent_station = ?)
      LIMIT 1;
    ''', [originStopId, originStopId, destStopId, destStopId]);
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

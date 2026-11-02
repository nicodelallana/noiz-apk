import '../../domain/models/transit_models.dart';
import '../../domain/repositories/metro_repository.dart';
import '../gtfs/schedule_sync_service.dart';
import '../local/app_database.dart';

/// Metro Bilbao implementation of [MetroRepository].
///
/// Handles GTFS schedule lookups, 24:00+ rollover resolution for midnight services,
/// and line categorization (L1 vs L2).
class MetroRepositoryImpl implements MetroRepository {
  MetroRepositoryImpl({
    required AppDatabase database,
    required ScheduleSyncService syncService,
  })  : _db = database,
        _syncService = syncService;

  final AppDatabase _db;
  final ScheduleSyncService _syncService;

  // Station cache for fast repeated queries
  List<Stop>? _cachedStations;

  @override
  Future<bool> isScheduleReady() async {
    return _syncService.isDatabasePresent();
  }

  @override
  Future<List<Stop>> getStations({String? searchQuery}) async {
    if (_cachedStations == null) {
      final rawStops = await _db.getStations(operatorId: 'metro');
      final stops = <Stop>[];

      for (final raw in rawStops) {
        final servedLines = await _db.getServedLinesForStation(raw.stopId);
        final lines = <MetroLine>[];
        if (servedLines.contains('L1')) lines.add(MetroLine.l1);
        if (servedLines.contains('L2')) lines.add(MetroLine.l2);

        // Fallback for terminal / newly opened stops if inferred_line is unassigned
        if (lines.isEmpty) {
          lines.add(MetroLine.l1);
          lines.add(MetroLine.l2);
        }

        stops.add(
          Stop(
            id: raw.stopId,
            name: raw.stopName,
            latitude: raw.stopLat,
            longitude: raw.stopLon,
            parentStation: raw.parentStation,
            isParent: raw.parentStation == null || raw.parentStation!.isEmpty,
            lines: lines,
          ),
        );
      }
      _cachedStations = stops;
    }

    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return _cachedStations!;
    }

    final query = _normalizeString(searchQuery.trim());
    return _cachedStations!
        .where((stop) => _normalizeString(stop.name).contains(query))
        .toList();
  }

  @override
  Future<Stop?> getStationById(String stationId) async {
    final stations = await getStations();
    for (final s in stations) {
      if (s.id == stationId) return s;
    }
    // Check raw stop if it is a platform stop
    final raw = await _db.getStopById(stationId);
    if (raw == null) return null;

    final servedLines = await _db.getServedLinesForStation(raw.stopId);
    final lines = <MetroLine>[];
    if (servedLines.contains('L1')) lines.add(MetroLine.l1);
    if (servedLines.contains('L2')) lines.add(MetroLine.l2);
    if (lines.isEmpty) lines.addAll([MetroLine.l1, MetroLine.l2]);

    return Stop(
      id: raw.stopId,
      name: raw.stopName,
      latitude: raw.stopLat,
      longitude: raw.stopLon,
      parentStation: raw.parentStation,
      isParent: raw.parentStation == null || raw.parentStation!.isEmpty,
      lines: lines,
    );
  }

  @override
  Future<List<Departure>> getDepartures({
    required String stationId,
    MetroLine? lineFilter,
    String? destinationStopId,
    int limit = 15,
    DateTime? referenceTime,
  }) async {
    final station = await getStationById(stationId);
    final stationName = station?.name ?? 'Metro Bilbao';

    // 1. Resolve current time in Europe/Madrid timezone
    final nowMadrid = toMadridTime(referenceTime ?? DateTime.now());
    final currentHour = nowMadrid.hour;
    final currentTimeStr =
        _formatTime(nowMadrid.hour, nowMadrid.minute, nowMadrid.second);

    final departures = <Departure>[];

    // 2. Identify active service IDs for today
    final activeServicesToday = await _db.getActiveServiceIds(nowMadrid);

    // 3. Query today's regular departures (departure_time >= currentTimeStr)
    if (activeServicesToday.isNotEmpty) {
      final todayRows = await _db.getDepartures(
        stationId: stationId,
        activeServiceIds: activeServicesToday,
        minDepartureTime: currentTimeStr,
        maxDepartureTime: '23:59:59',
        destinationStopId: destinationStopId,
        lineFilter: lineFilter?.id,
        limit: limit,
      );

      for (final row in todayRows) {
        final departureTime = _parseGtfsTime(row.departureTime, nowMadrid);
        final diffMinutes = departureTime.difference(nowMadrid).inMinutes;

        // Skip departures in the past
        if (diffMinutes < 0) continue;

        departures.add(
          Departure(
            tripId: row.tripId,
            stationId: stationId,
            stationName: stationName,
            headsign: row.headsign ?? 'Metro Bilbao',
            line: row.inferredLine == 'L2' ? MetroLine.l2 : MetroLine.l1,
            scheduledTime: departureTime,
            scheduledTimeFormatted: _formatDisplayTime(departureTime),
            minutesRemaining: diffMinutes,
            platform: row.stopId,
            isTheoretical: true,
          ),
        );
      }
    }

    // 4. Midnight service rollover check (madrugada: 00:00:00 to 05:59:59)
    // In GTFS, trips running past midnight belong to yesterday's service_id with departure_time >= 24:00:00
    if (currentHour < 6) {
      final yesterday = nowMadrid.subtract(const Duration(days: 1));
      final activeServicesYesterday = await _db.getActiveServiceIds(yesterday);

      if (activeServicesYesterday.isNotEmpty) {
        // e.g. 00:30:00 -> 24:30:00; 01:15:00 -> 25:15:00
        final rolloverHour = currentHour + 24;
        final rolloverTimeStr =
            _formatTime(rolloverHour, nowMadrid.minute, nowMadrid.second);

        final rolloverRows = await _db.getDepartures(
          stationId: stationId,
          activeServiceIds: activeServicesYesterday,
          minDepartureTime: rolloverTimeStr,
          destinationStopId: destinationStopId,
          lineFilter: lineFilter?.id,
          limit: limit,
        );

        for (final row in rolloverRows) {
          final departureTime = _parseGtfsTime(row.departureTime, yesterday);
          final diffMinutes = departureTime.difference(nowMadrid).inMinutes;

          if (diffMinutes < 0) continue;

          departures.add(
            Departure(
              tripId: row.tripId,
              stationId: stationId,
              stationName: stationName,
              headsign: row.headsign ?? 'Metro Bilbao',
              line: row.inferredLine == 'L2' ? MetroLine.l2 : MetroLine.l1,
              scheduledTime: departureTime,
              scheduledTimeFormatted: _formatDisplayTime(departureTime),
              minutesRemaining: diffMinutes,
              platform: row.stopId,
              isTheoretical: true,
            ),
          );
        }
      }
    }

    // 5. Sort departures chronologically by scheduled time
    departures.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    if (departures.length > limit) {
      return departures.sublist(0, limit);
    }
    return departures;
  }

  /// Converts any DateTime to Europe/Madrid local time.
  static DateTime toMadridTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year;

    // Last Sunday of March
    final lastSundayMarch = _lastSundayOfMonth(year, 3);
    final dstStart =
        DateTime.utc(year, 3, lastSundayMarch, 1, 0); // 01:00 UTC = 02:00 CET

    // Last Sunday of October
    final lastSundayOctober = _lastSundayOfMonth(year, 10);
    final dstEnd = DateTime.utc(
        year, 10, lastSundayOctober, 1, 0); // 01:00 UTC = 03:00 CEST

    // Daylight Saving Time (CEST) is UTC+2, standard time (CET) is UTC+1
    final isDst = utc.isAfter(dstStart) && utc.isBefore(dstEnd);
    final offsetHours = isDst ? 2 : 1;

    return utc.add(Duration(hours: offsetHours));
  }

  static int _lastSundayOfMonth(int year, int month) {
    // Start from last day of month and walk backwards to Sunday (weekday 7)
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    for (var day = lastDay; day >= 1; day--) {
      if (DateTime.utc(year, month, day).weekday == DateTime.sunday) {
        return day;
      }
    }
    return lastDay;
  }

  static String _formatTime(int h, int m, int s) {
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  static String _formatDisplayTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Parses GTFS time strings which may exceed 24 hours (e.g. '24:26:00' -> next day 00:26:00).
  static DateTime _parseGtfsTime(String gtfsTime, DateTime serviceBaseDate) {
    final parts = gtfsTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final second = parts.length > 2 ? int.parse(parts[2].split('.').first) : 0;

    final daysToAdd = hour ~/ 24;
    final normalizedHour = hour % 24;

    if (serviceBaseDate.isUtc) {
      final date = DateTime.utc(
        serviceBaseDate.year,
        serviceBaseDate.month,
        serviceBaseDate.day,
      ).add(Duration(days: daysToAdd));

      return DateTime.utc(
        date.year,
        date.month,
        date.day,
        normalizedHour,
        minute,
        second,
      );
    }

    final date = DateTime(
      serviceBaseDate.year,
      serviceBaseDate.month,
      serviceBaseDate.day,
    ).add(Duration(days: daysToAdd));

    return DateTime(
      date.year,
      date.month,
      date.day,
      normalizedHour,
      minute,
      second,
    );
  }

  /// Normalizes strings for accent-insensitive search (e.g. 'San Mamés' -> 'san mames').
  static String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}

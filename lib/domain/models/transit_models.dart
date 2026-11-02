/// Pure domain models representing transit stops, lines, and departures.
/// Independent of UI frameworks, SQLite databases, or network drivers.

enum MetroLine {
  l1(id: 'L1', name: 'Línea 1', colorHex: 0xFFE2001A),
  l2(id: 'L2', name: 'Línea 2', colorHex: 0xFF1D1D1B),
  l3(id: 'L3', name: 'Línea 3', colorHex: 0xFF025DA9);

  const MetroLine({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  final String id;
  final String name;
  final int colorHex;
}

class Stop {
  const Stop({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.parentStation,
    this.isParent = false,
    this.lines = const [],
    this.operatorId = 'metro',
    this.territory = 'bizkaia',
    this.mode = 'subway',
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? parentStation;
  final bool isParent;
  final List<MetroLine> lines;
  final String operatorId;
  final String territory;
  final String mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stop &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'Stop(id: $id, name: $name, parent: $parentStation)';
}

class Departure {
  const Departure({
    required this.tripId,
    required this.stationId,
    required this.stationName,
    required this.headsign,
    required this.line,
    required this.scheduledTime,
    required this.scheduledTimeFormatted,
    required this.minutesRemaining,
    this.isTheoretical = true,
    this.platform,
    this.operatorId = 'metro',
    this.lineCode = 'L1',
    this.routeColorHex,
    this.isRealtime = false,
    this.delaySeconds = 0,
    this.progress = 0.0,
    this.status = 'scheduled',
  });

  final String tripId;
  final String stationId;
  final String stationName;
  final String headsign;
  final MetroLine line;
  final DateTime scheduledTime;
  final String scheduledTimeFormatted;
  final int minutesRemaining;
  final bool isTheoretical;
  final String? platform;
  final String operatorId;
  final String lineCode;
  final int? routeColorHex;
  final bool isRealtime;
  final int delaySeconds;
  final double progress;
  final String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Departure &&
          runtimeType == other.runtimeType &&
          tripId == other.tripId &&
          stationId == other.stationId &&
          scheduledTime == other.scheduledTime;

  @override
  int get hashCode =>
      tripId.hashCode ^ stationId.hashCode ^ scheduledTime.hashCode;

  @override
  String toString() =>
      'Departure($line to $headsign at $scheduledTimeFormatted, in ${minutesRemaining}m)';
}

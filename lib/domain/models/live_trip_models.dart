/// Live transit trip state contract shared across Dart, Kotlin, Swift,
/// and backend push payloads.
///
/// Follows §2 of the Live Activities Kit specification.

enum LiveTripStatus {
  scheduled('scheduled'),
  tracking('tracking'),
  arriving('arriving'),
  atStop('at_stop'),
  delayed('delayed'),
  disrupted('disrupted'),
  ended('ended');

  const LiveTripStatus(this.value);
  final String value;

  static LiveTripStatus fromString(String val) {
    return LiveTripStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => LiveTripStatus.tracking,
    );
  }
}

class LiveTripState {
  const LiveTripState({
    required this.tripId,
    required this.operatorId,
    required this.mode,
    required this.lineId,
    required this.lineName,
    required this.lineColor,
    required this.origin,
    required this.destination,
    required this.currentStop,
    required this.nextStop,
    required this.stopsRemaining,
    required this.progress,
    required this.arrivalTime,
    required this.status,
    required this.isRealtime,
    required this.delaySeconds,
    this.transferInfo,
    this.instruction,
    required this.updatedAt,
  });

  final String tripId;
  final String operatorId;
  final String mode;
  final String lineId;
  final String lineName;
  final String lineColor;
  final String origin;
  final String destination;
  final String currentStop;
  final String nextStop;
  final int stopsRemaining;
  final double progress; // 0.0 .. 1.0
  final DateTime arrivalTime;
  final LiveTripStatus status;
  final bool isRealtime;
  final int delaySeconds;
  final String? transferInfo;
  final String? instruction;
  final DateTime updatedAt;

  int get minutesRemaining {
    final diff = arrivalTime.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  bool get isArrivingSoon => minutesRemaining <= 10;

  Map<String, dynamic> toNativePayload() => toJson();

  factory LiveTripState.fromNativePayload(Map<String, dynamic> payload) =>
      LiveTripState.fromJson(payload);

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'operatorId': operatorId,
        'mode': mode,
        'lineId': lineId,
        'lineName': lineName,
        'lineColor': lineColor,
        'origin': origin,
        'destination': destination,
        'currentStop': currentStop,
        'nextStop': nextStop,
        'stopsRemaining': stopsRemaining,
        'progress': progress,
        'arrivalTime': arrivalTime.toIso8601String(),
        'arrivalTimeEpochMs': arrivalTime.millisecondsSinceEpoch,
        'status': status.value,
        'isRealtime': isRealtime,
        'delaySeconds': delaySeconds,
        'transferInfo': transferInfo,
        'instruction': instruction,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LiveTripState.fromJson(Map<String, dynamic> json) {
    return LiveTripState(
      tripId: json['tripId'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? 'metro',
      mode: json['mode'] as String? ?? 'metro',
      lineId: json['lineId'] as String? ?? '',
      lineName: json['lineName'] as String? ?? '',
      lineColor: json['lineColor'] as String? ?? '#E2001A',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      currentStop: json['currentStop'] as String? ?? '',
      nextStop: json['nextStop'] as String? ?? '',
      stopsRemaining: (json['stopsRemaining'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      arrivalTime: json['arrivalTimeEpochMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['arrivalTimeEpochMs'] as int,
            )
          : DateTime.tryParse(json['arrivalTime'] as String? ?? '') ??
              DateTime.now(),
      status: LiveTripStatus.fromString(json['status'] as String? ?? 'tracking'),
      isRealtime: json['isRealtime'] as bool? ?? false,
      delaySeconds: (json['delaySeconds'] as num?)?.toInt() ?? 0,
      transferInfo: json['transferInfo'] as String?,
      instruction: json['instruction'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  LiveTripState copyWith({
    String? tripId,
    String? operatorId,
    String? mode,
    String? lineId,
    String? lineName,
    String? lineColor,
    String? origin,
    String? destination,
    String? currentStop,
    String? nextStop,
    int? stopsRemaining,
    double? progress,
    DateTime? arrivalTime,
    LiveTripStatus? status,
    bool? isRealtime,
    int? delaySeconds,
    String? transferInfo,
    String? instruction,
    DateTime? updatedAt,
  }) {
    return LiveTripState(
      tripId: tripId ?? this.tripId,
      operatorId: operatorId ?? this.operatorId,
      mode: mode ?? this.mode,
      lineId: lineId ?? this.lineId,
      lineName: lineName ?? this.lineName,
      lineColor: lineColor ?? this.lineColor,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      currentStop: currentStop ?? this.currentStop,
      nextStop: nextStop ?? this.nextStop,
      stopsRemaining: stopsRemaining ?? this.stopsRemaining,
      progress: progress ?? this.progress,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      status: status ?? this.status,
      isRealtime: isRealtime ?? this.isRealtime,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      transferInfo: transferInfo ?? this.transferInfo,
      instruction: instruction ?? this.instruction,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

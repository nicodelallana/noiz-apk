import 'package:dio/dio.dart';

/// How a vehicle's position was obtained — shown to the user as-is.
enum LivePositionKind {
  /// Real GPS fix (Bizkaibus).
  gps,

  /// Placed at the last station the train was detected at (Metro Bilbao,
  /// Renfe): underground or not, it is not a GPS position.
  station,
}

/// One live vehicle from the operators' GTFS-RT feeds, via the vehicle proxy
/// (tools/vehicle-proxy).
class LiveVehicle {
  const LiveVehicle({
    required this.id,
    required this.operatorId,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.line,
    required this.colorHex,
    required this.reportedAt,
    this.headsign,
    this.stopName,
    this.status,
  });

  factory LiveVehicle.fromJson(Map<String, dynamic> j) => LiveVehicle(
        id: j['id'] as String,
        operatorId: j['op'] as String,
        kind: j['kind'] == 'gps'
            ? LivePositionKind.gps
            : LivePositionKind.station,
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lon'] as num).toDouble(),
        line: j['line'] as String? ?? '',
        colorHex: j['color'] as String? ?? '#0A84FF',
        headsign: j['headsign'] as String?,
        stopName: j['stop'] as String?,
        status: j['status'] as String?,
        reportedAt: DateTime.fromMillisecondsSinceEpoch(
          ((j['ts'] as num?) ?? 0).toInt() * 1000,
        ),
      );

  final String id;

  /// 'bizkaibus' | 'metro' | 'renfe'.
  final String operatorId;
  final LivePositionKind kind;
  final double latitude;
  final double longitude;
  final String line;

  /// '#RRGGBB' from the operator's static GTFS.
  final String colorHex;
  final String? headsign;
  final String? stopName;

  /// 'incoming' | 'stopped' | 'in_transit' (GTFS-RT VehicleStopStatus).
  final String? status;
  final DateTime reportedAt;

  String get operatorName => switch (operatorId) {
        'bizkaibus' => 'Bizkaibus',
        'metro' => 'Metro Bilbao',
        'renfe' => 'Renfe Cercanías',
        _ => operatorId,
      };
}

/// One poll of the proxy: the vehicles plus per-feed health.
class LiveVehiclesSnapshot {
  const LiveVehiclesSnapshot({
    required this.vehicles,
    required this.fetchedAt,
    required this.attribution,
    required this.failedFeeds,
  });

  factory LiveVehiclesSnapshot.fromJson(Map<String, dynamic> j) {
    final sources = (j['sources'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return LiveVehiclesSnapshot(
      vehicles: (j['vehicles'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(LiveVehicle.fromJson)
          .toList(),
      fetchedAt: DateTime.now(),
      attribution: j['attribution'] as String? ?? '',
      failedFeeds: [
        for (final s in sources)
          if (s['ok'] != true) s['op'] as String,
      ],
    );
  }

  final List<LiveVehicle> vehicles;
  final DateTime fetchedAt;
  final String attribution;

  /// Operators whose feed failed on this poll (shown, not hidden).
  final List<String> failedFeeds;
}

/// Reads the vehicle proxy. The proxy (not the app) talks to the operators:
/// their feeds are protobuf without CORS, so the web build can't read them.
class LiveVehiclesService {
  LiveVehiclesService({Dio? dio, String? url})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
            )),
        _url = url ?? liveVehiclesUrl;

  /// Configurable per build (`--dart-define=LIVE_VEHICLES_URL=…`); when
  /// Nico's Supabase Edge Function exists only this URL changes.
  static const liveVehiclesUrl = String.fromEnvironment(
    'LIVE_VEHICLES_URL',
    defaultValue: 'https://noiz-glass-vista-previa.vercel.app/api/vehicles',
  );

  final Dio _dio;
  final String _url;

  Future<LiveVehiclesSnapshot> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>(_url);
    return LiveVehiclesSnapshot.fromJson(res.data ?? const {});
  }
}

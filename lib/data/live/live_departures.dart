import 'package:dio/dio.dart';

import 'package:bizkaia_transit/data/live/live_api.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';

/// Live departures from the operators' GTFS-RT TripUpdates, via the proxy's
/// /departures. Only operators whose feed carries per-stop predictions are
/// served: Metro Bilbao and Euskotren (trains, Topo and both trams). Renfe's
/// feed gives each train's next stop only, so it stays on the timetable.
class LiveDeparturesService {
  LiveDeparturesService({Dio? dio}) : _dio = dio ?? LiveApi.dio();

  final Dio _dio;

  // Several providers ask for the same stop as the home screen settles
  // (minute tick, stop selection…): share in-flight requests and keep each
  // answer 15 s, the same freshness the proxy's CDN cache gives.
  static const _fresh = Duration(seconds: 15);
  final _cache = <String, (DateTime, Future<List<Departure>?>)>{};

  /// App operator id → proxy operator.
  static const _feedFor = {
    'metro': 'metro',
    'euskotren': 'euskotren',
    'tranbia_bilbao': 'euskotren',
    'tranbia_gasteiz': 'euskotren',
  };

  static bool supports(String operatorId) => _feedFor.containsKey(operatorId);

  /// Next departures around [stop] for [operatorId], or null when the live
  /// feed can't answer (no nearby official stop, feed down, network error):
  /// the caller then falls back to the timetable.
  Future<List<Departure>?> fetch(Stop stop, String operatorId) {
    final key = '$operatorId|${stop.id}';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < _fresh) return hit.$2;
    final request = _fetch(stop, operatorId);
    _cache[key] = (DateTime.now(), request);
    return request;
  }

  Future<List<Departure>?> _fetch(Stop stop, String operatorId) async {
    final feed = _feedFor[operatorId];
    if (feed == null || stop.latitude == null || stop.longitude == null) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${LiveApi.base}/departures',
        queryParameters: {
          'op': feed,
          // Rounded so every user at this stop hits the same CDN cache entry.
          'lat': stop.latitude!.toStringAsFixed(4),
          'lon': stop.longitude!.toStringAsFixed(4),
        },
      );
      final body = res.data;
      if (body == null || body['ok'] != true) return null;
      final list = (body['departures'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      final now = DateTime.now();
      return [for (final d in list) _toDeparture(d, stop, operatorId, now)];
    } on DioException {
      return null;
    }
  }

  static Departure _toDeparture(
    Map<String, dynamic> d,
    Stop stop,
    String operatorId,
    DateTime now,
  ) {
    final time = DateTime.fromMillisecondsSinceEpoch(
      ((d['time'] as num?) ?? 0).toInt() * 1000,
    );
    final realtime = d['realtime'] == true;
    final delay = (d['delay'] as num?)?.toInt() ?? 0;
    final cancelled = d['cancelled'] == true;
    final lineCode = d['line'] as String? ?? '';
    final colorHex = int.tryParse(
      'FF${(d['color'] as String? ?? '').replaceFirst('#', '')}',
      radix: 16,
    );
    final minutes = time.difference(now).inSeconds ~/ 60;
    return Departure(
      tripId: d['tripId'] as String? ?? '',
      stationId: stop.id,
      stationName: stop.name,
      headsign: d['headsign'] as String? ?? 'Destino',
      line: switch (lineCode) {
        'L2' => MetroLine.l2,
        'L1' => MetroLine.l1,
        _ => MetroLine.l3,
      },
      lineCode: lineCode,
      routeColorHex: colorHex,
      // For live departures this is the predicted time.
      scheduledTime: time,
      scheduledTimeFormatted:
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      minutesRemaining: minutes < 0 ? 0 : minutes,
      isTheoretical: !realtime,
      isRealtime: realtime,
      delaySeconds: delay,
      operatorId: operatorId,
      status: cancelled
          ? 'cancelled'
          : !realtime
              ? 'scheduled'
              : (delay >= 60 ? 'delayed' : 'on_time'),
    );
  }
}

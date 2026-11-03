import 'package:dio/dio.dart';

import 'package:bizkaia_transit/data/live/live_api.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';

/// Official service incidents in force now (GTFS-RT Alerts of Metro Bilbao,
/// Bizkaibus, Euskotren and Renfe Cercanías Bilbao) via the proxy's /alerts.
class LiveAlertsService {
  LiveAlertsService({Dio? dio}) : _dio = dio ?? LiveApi.dio();

  final Dio _dio;

  /// Throws on network/proxy failure: the screen shows an error rather than
  /// pretending there are no incidents.
  Future<LiveAlerts> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('${LiveApi.base}/alerts');
    final body = res.data ?? const <String, dynamic>{};
    final sources = (body['sources'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return LiveAlerts(
      alerts: (body['alerts'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_toAlert)
          .toList(),
      attribution: body['attribution'] as String? ?? '',
      unavailable: [
        for (final s in sources)
          if (s['ok'] != true || s['stale'] == true) s['op'] as String,
      ],
    );
  }

  static ServiceAlert _toAlert(Map<String, dynamic> a) {
    final lines = (a['lines'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((l) => l['name'] as String)
        .toList();
    final op = a['op'] as String? ?? '';
    final to = (a['to'] as num?)?.toInt();
    return ServiceAlert(
      id: a['id'] as String,
      operatorId: op,
      territory: TransitTerritory.bizkaia,
      lineName: switch (lines.length) {
        0 => TransitOperator.fromId(op).name.split(' ').first,
        1 => lines.first,
        _ => '${lines.first} +${lines.length - 1}',
      },
      severity: a['severity'] as String? ?? 'info',
      title: a['title'] as String? ?? 'Incidencia',
      description: a['body'] as String? ?? '',
      activePeriod: to == null ? null : _until(to),
      locations: [
        for (final s in (a['stops'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          AlertLocation(
            name: s['name'] as String,
            latitude: (s['lat'] as num).toDouble(),
            longitude: (s['lon'] as num).toDouble(),
          ),
      ],
      networkWide: a['networkWide'] == true,
    );
  }

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// "Hasta las 18:30" today, "Hasta el 12 nov" otherwise. Null for the
  /// end-of-day cut-off: Bizkaibus re-issues long-running notices daily
  /// with a 23:59 expiry that says nothing about when they really end.
  static String? _until(int epochS) {
    final t = DateTime.fromMillisecondsSinceEpoch(epochS * 1000);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      if (t.hour == 23 && t.minute >= 59) return null;
      return 'Hasta las ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return 'Hasta el ${t.day} ${_months[t.month - 1]}';
  }
}

class LiveAlerts {
  const LiveAlerts({
    required this.alerts,
    required this.attribution,
    required this.unavailable,
  });

  final List<ServiceAlert> alerts;
  final String attribution;

  /// Operators whose feed failed or is stale on this fetch.
  final List<String> unavailable;
}

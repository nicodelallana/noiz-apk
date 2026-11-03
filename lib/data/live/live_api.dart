import 'package:dio/dio.dart';

/// The live-data proxy (tools/vehicle-proxy): /vehicles, /departures and
/// /alerts. Configurable per build (`--dart-define=LIVE_API_BASE=…`); when
/// it moves to Nico's Supabase only this changes.
abstract final class LiveApi {
  static const base = String.fromEnvironment(
    'LIVE_API_BASE',
    defaultValue: 'https://noiz-glass-vista-previa.vercel.app/api',
  );

  static Dio dio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
}

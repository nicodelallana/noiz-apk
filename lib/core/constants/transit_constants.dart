/// Global transit and network constants for Bizkaia Transit.
abstract final class TransitConstants {
  /// Base CDN URL for precompiled GTFS SQLite packages in Supabase Storage.
  static const String defaultStorageBucketUrl =
      'https://zbwrjtncyblaxaarbmsr.supabase.co/storage/v1/object/public/transit-packs';

  /// GTFS database and bundle file names.
  static const String manifestFileName = 'manifest.json';
  static const String compressedDbFileName = 'transit.sqlite.gz';
  static const String sqliteDbFileName = 'transit.sqlite';
  static const String manifestMetaFileName = 'transit_manifest.json';

  /// Primary timezone for service-day calculation and departures display.
  static const String localTimezone = 'Europe/Madrid';

  /// Network timeout standards adhering to resilience guidelines.
  static const Duration connectTimeout = Duration(milliseconds: 5000);
  static const Duration receiveTimeout = Duration(milliseconds: 10000);

  /// Polling interval for theoretical departures refresh (30 seconds).
  static const Duration departureRefreshInterval = Duration(seconds: 30);

  /// Reference Metro Bilbao parent station IDs.
  static const String stationBagatzaId = '35';
  static const String stationKabiezesId = '42';
  static const String stationSanIgnazioId = '13';
}

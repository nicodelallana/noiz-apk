import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/adapters/metro_repository_impl.dart';
import '../../data/gtfs/schedule_sync_service.dart';
import '../../data/local/app_database.dart';
import '../../domain/models/transit_models.dart';
import '../../domain/repositories/metro_repository.dart';

/// Provider for GTFS schedule sync service.
final scheduleSyncServiceProvider = Provider<ScheduleSyncService>((ref) {
  return ScheduleSyncService();
});

/// Provider for local SQLite transit database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for Metro Bilbao repository.
final metroRepositoryProvider = Provider<MetroRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(scheduleSyncServiceProvider);
  return MetroRepositoryImpl(
    database: db,
    syncService: sync,
  );
});

/// Provider that runs GTFS schedule sync and reports status.
final scheduleSyncStatusProvider = FutureProvider<SyncResult>((ref) async {
  final syncService = ref.watch(scheduleSyncServiceProvider);
  return syncService.sync();
});

/// Currently selected Metro station for departures consultation.
final selectedMetroStationProvider = StateProvider<Stop?>((ref) => null);

/// Line filter (null = all lines, L1, or L2).
final selectedMetroLineFilterProvider =
    StateProvider<MetroLine?>((ref) => null);

/// Search query for station filtering in modal.
final stationSearchQueryProvider = StateProvider<String>((ref) => '');

/// All Metro Bilbao stations.
final metroStationsProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(metroRepositoryProvider);
  final query = ref.watch(stationSearchQueryProvider);
  return repo.getStations(searchQuery: query);
});

/// Auto-refreshing departures stream for the selected station and line filter.
/// Updates every 30 seconds to maintain accurate countdown minutes.
final metroDeparturesStreamProvider =
    StreamProvider.autoDispose<List<Departure>>((ref) async* {
  final repo = ref.watch(metroRepositoryProvider);
  final station = ref.watch(selectedMetroStationProvider);
  final lineFilter = ref.watch(selectedMetroLineFilterProvider);

  if (station == null) {
    yield [];
    return;
  }

  // Periodic polling interval: 30 seconds
  final ticker = Stream.periodic(const Duration(seconds: 30), (i) => i);

  // Fetch initial departures immediately
  final initial = await repo.getDepartures(
    stationId: station.id,
    lineFilter: lineFilter,
  );
  yield initial;

  // Stream subsequent updates
  await for (final _ in ticker) {
    final updated = await repo.getDepartures(
      stationId: station.id,
      lineFilter: lineFilter,
    );
    yield updated;
  }
});

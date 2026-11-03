import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transit_models.dart';
import 'transit_providers.dart';

/// Bus stops across Bizkaibus & Bilbobus network loaded from official GTFS database.
final busStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final repo = ref.watch(transitRepositoryProvider);
  final bizkaibusStops = await repo.getStops(operatorId: 'bizkaibus');
  final bilbobusStops = await repo.getStops(operatorId: 'bilbobus');
  return [...bizkaibusStops, ...bilbobusStops];
});

/// Currently selected Bus stop.
final selectedBusStopProvider = StateProvider<Stop?>((ref) => null);

/// Selected Bus line filter (null = all lines).
final selectedBusLineFilterProvider = StateProvider<String?>((ref) => null);

/// Auto-refreshing Bus departures stream powered by official GTFS schedules.
final busDeparturesStreamProvider =
    StreamProvider.autoDispose<List<BusDeparture>>((ref) async* {
  final stop = ref.watch(selectedBusStopProvider);
  final lineFilter = ref.watch(selectedBusLineFilterProvider);
  final repo = ref.watch(transitRepositoryProvider);

  if (stop == null) {
    yield [];
    return;
  }

  Future<List<BusDeparture>> fetchDepartures() async {
    final departures = await repo.getDepartures(
      stopId: stop.id,
      operatorId: stop.operatorId,
    );

    final mapped = departures.map((d) {
      return BusDeparture(
        routeNumber: d.lineCode.isNotEmpty ? d.lineCode : d.line.name,
        destination: d.headsign,
        operatorName: stop.operatorId == 'bilbobus' ? 'Bilbobus' : 'Bizkaibus',
        minutesRemaining: d.minutesRemaining,
        scheduledTime: d.scheduledTime,
        isRealtime: d.isRealtime,
      );
    }).toList();

    if (lineFilter == null) return mapped;
    return mapped.where((d) => d.routeNumber == lineFilter).toList();
  }

  yield await fetchDepartures();

  final ticker = Stream<void>.periodic(const Duration(seconds: 30));
  await for (final _ in ticker) {
    yield await fetchDepartures();
  }
});

/// Entity for Bus line departure.
class BusDeparture {
  const BusDeparture({
    required this.routeNumber,
    required this.destination,
    required this.operatorName,
    required this.minutesRemaining,
    required this.scheduledTime,
    this.isRealtime = false,
  });

  final String routeNumber;
  final String destination;
  final String operatorName;
  final int minutesRemaining;
  final DateTime scheduledTime;
  final bool isRealtime;

  String get scheduledTimeFormatted {
    final h = scheduledTime.hour.toString().padLeft(2, '0');
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

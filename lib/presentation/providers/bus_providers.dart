import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/transit_models.dart';

/// Pre-populated reference bus stops across Bizkaibus & Bilbobus network.
final busStopsProvider = Provider<List<Stop>>((ref) {
  return const [
    Stop(
      id: 'bus_bide_onera',
      name: 'Barakaldo (Bide Onera)',
      latitude: 43.2974,
      longitude: -2.9912,
      isParent: true,
    ),
    Stop(
      id: 'bus_moyua',
      name: 'Bilbao (Gran Vía / Moyua)',
      latitude: 43.2628,
      longitude: -2.9352,
      isParent: true,
    ),
    Stop(
      id: 'bus_termibus',
      name: 'Bilbao Intermodal (Termibus)',
      latitude: 43.2612,
      longitude: -2.9501,
      isParent: true,
    ),
    Stop(
      id: 'bus_cruces',
      name: 'Cruces Ospitalea (Gurutzeta)',
      latitude: 43.2825,
      longitude: -2.9818,
      isParent: true,
    ),
    Stop(
      id: 'bus_santurtzi',
      name: 'Santurtzi (Parkea)',
      latitude: 43.3298,
      longitude: -3.0315,
      isParent: true,
    ),
    Stop(
      id: 'bus_getxo',
      name: 'Getxo (Algorta)',
      latitude: 43.3512,
      longitude: -3.0118,
      isParent: true,
    ),
  ];
});

/// Currently selected Bus stop.
final selectedBusStopProvider = StateProvider<Stop>((ref) {
  final stops = ref.watch(busStopsProvider);
  return stops.first;
});

/// Selected Bus line filter (null = all lines).
final selectedBusLineFilterProvider = StateProvider<String?>((ref) => null);

/// Auto-refreshing Bus departures stream.
final busDeparturesStreamProvider =
    StreamProvider.autoDispose<List<BusDeparture>>((ref) async* {
  final stop = ref.watch(selectedBusStopProvider);
  final lineFilter = ref.watch(selectedBusLineFilterProvider);

  // Generates real-time calculated departures relative to current time
  List<BusDeparture> generateDepartures() {
    final now = DateTime.now();

    final all = [
      BusDeparture(
        routeNumber: 'A3115',
        destination: 'Santurtzi (desde ${stop.name})',
        operatorName: 'Bizkaibus',
        minutesRemaining: 3, // Imminent -> shows pulse!
        scheduledTime: now.add(const Duration(minutes: 3)),
        isRealtime: true,
      ),
      BusDeparture(
        routeNumber: 'A3336',
        destination: 'Muskiz (por Ortuella)',
        operatorName: 'Bizkaibus',
        minutesRemaining: 8,
        scheduledTime: now.add(const Duration(minutes: 8)),
        isRealtime: true,
      ),
      BusDeparture(
        routeNumber: 'A3411',
        destination: 'Bilbao (Intermodal Termibus)',
        operatorName: 'Bizkaibus',
        minutesRemaining: 14,
        scheduledTime: now.add(const Duration(minutes: 14)),
        isRealtime: false,
      ),
      BusDeparture(
        routeNumber: 'A3136',
        destination: 'Cruces / Gurutzeta Ospitalea',
        operatorName: 'Bizkaibus',
        minutesRemaining: 21,
        scheduledTime: now.add(const Duration(minutes: 21)),
        isRealtime: true,
      ),
      BusDeparture(
        routeNumber: '01',
        destination: 'Arangoiti (Bilbobus)',
        operatorName: 'Bilbobus',
        minutesRemaining: 29,
        scheduledTime: now.add(const Duration(minutes: 29)),
        isRealtime: false,
      ),
    ];

    if (lineFilter == null) return all;
    return all.where((d) => d.routeNumber == lineFilter).toList();
  }

  yield generateDepartures();

  final ticker = Stream<void>.periodic(const Duration(seconds: 30));
  await for (final _ in ticker) {
    yield generateDepartures();
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
    this.isRealtime = true,
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

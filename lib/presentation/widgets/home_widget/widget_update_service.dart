import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../../domain/models/transit_models.dart';
import '../../../domain/repositories/metro_repository.dart';
import '../../../domain/repositories/saved_trips_repository.dart';

/// Precomputes and synchronizes upcoming departures with native home-screen widgets.
/// Writes versioned JSON and key-value entries to shared storage (SharedPreferences / UserDefaults).
class WidgetUpdateService {
  const WidgetUpdateService({
    required MetroRepository metroRepository,
    required SavedTripsRepository savedTripsRepository,
  })  : _metroRepository = metroRepository,
        _savedTripsRepository = savedTripsRepository;

  final MetroRepository _metroRepository;
  final SavedTripsRepository _savedTripsRepository;

  static const String dataKey = 'transit_widget_data';
  static const String androidWidgetProvider = 'TransitWidgetProvider';

  /// Precomputes upcoming 12-hour departures for all trips with widget_enabled = true
  /// and notifies the native widget provider to refresh.
  Future<void> update() async {
    try {
      final trips = await _savedTripsRepository.getSavedTrips();
      final enabledTrips = trips.where((t) => t.widgetEnabled).toList();

      final tripsPayload = <Map<String, dynamic>>[];

      for (final trip in enabledTrips) {
        List<Departure> departures = const [];
        try {
          departures = await _metroRepository.getDepartures(
            stationId: trip.originStopId,
            destinationStopId: trip.destStopId,
            limit: 8,
          );
        } catch (e) {
          debugPrint(
              'Error fetching departures for widget trip ${trip.id}: $e');
        }

        tripsPayload.add({
          'id': trip.id,
          'name': trip.name,
          'origin_id': trip.originStopId,
          'origin_name': trip.originStopName,
          'dest_id': trip.destStopId,
          'dest_name': trip.destStopName,
          'line': departures.isNotEmpty
              ? departures.first.line.name.toUpperCase()
              : 'METRO',
          'departures': departures
              .map(
                (d) => {
                  'trip_id': d.tripId,
                  'sched': d.scheduledTime.toUtc().toIso8601String(),
                  'formatted': d.scheduledTimeFormatted,
                  'mins': d.minutesRemaining,
                  'line': d.line.name.toUpperCase(),
                  'headsign': d.headsign,
                },
              )
              .toList(),
        });
      }

      final payload = {
        'v': 1,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'trip_count': enabledTrips.length,
        'trips': tripsPayload,
      };

      await HomeWidget.saveWidgetData<String>(dataKey, jsonEncode(payload));

      // Also persist top-level convenience keys for simple RemoteViews access
      if (enabledTrips.isNotEmpty && tripsPayload.isNotEmpty) {
        final firstTrip = tripsPayload.first;
        final departures = firstTrip['departures'] as List<dynamic>;

        await HomeWidget.saveWidgetData<String>(
            'top_trip_name', firstTrip['name'] as String);
        await HomeWidget.saveWidgetData<String>(
            'top_trip_origin', firstTrip['origin_name'] as String);
        await HomeWidget.saveWidgetData<String>(
            'top_trip_dest', firstTrip['dest_name'] as String);
        await HomeWidget.saveWidgetData<String>(
            'top_trip_line', firstTrip['line'] as String);

        if (departures.isNotEmpty) {
          final firstDep = departures.first as Map<String, dynamic>;
          final mins = firstDep['mins'] as int;
          await HomeWidget.saveWidgetData<String>(
            'top_trip_time',
            firstDep['formatted'] as String,
          );
          await HomeWidget.saveWidgetData<String>(
            'top_trip_countdown',
            mins <= 0 ? 'Ahora' : '$mins min',
          );
        } else {
          await HomeWidget.saveWidgetData<String>('top_trip_time', '--:--');
          await HomeWidget.saveWidgetData<String>(
              'top_trip_countdown', 'Sin salidas');
        }
      } else {
        await HomeWidget.saveWidgetData<String>(
            'top_trip_name', 'Sin viajes activos');
        await HomeWidget.saveWidgetData<String>('top_trip_origin', '');
        await HomeWidget.saveWidgetData<String>('top_trip_dest', '');
        await HomeWidget.saveWidgetData<String>('top_trip_line', 'METRO');
        await HomeWidget.saveWidgetData<String>('top_trip_time', '--:--');
        await HomeWidget.saveWidgetData<String>(
            'top_trip_countdown', 'Añadir en app');
      }

      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
    } catch (e, st) {
      debugPrint('WidgetUpdateService update failed: $e\n$st');
    }
  }
}

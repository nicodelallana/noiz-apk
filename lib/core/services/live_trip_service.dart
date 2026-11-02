import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/domain/models/live_trip_models.dart';

/// State of live lock-screen tracking in the application.
final activeLiveTripProvider =
    StateNotifierProvider<LiveTripNotifier, LiveTripState?>((ref) {
  return LiveTripNotifier(ref.watch(liveTripServiceProvider));
});

final liveTripServiceProvider = Provider<LiveTripService>((ref) {
  return LiveTripServiceImpl();
});

abstract class LiveTripService {
  Future<bool> isSupported();
  Future<bool> requestPermission();
  Future<bool> checkPermission();
  Future<void> startTrip(LiveTripState state);
  Future<void> updateTrip(LiveTripState state);
  Future<void> endTrip();
}

class LiveTripServiceImpl implements LiveTripService {
  static const MethodChannel _channel =
      MethodChannel('com.bizkaia.transit/live_trip');

  @override
  Future<bool> isSupported() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> checkPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> startTrip(LiveTripState state) async {
    try {
      await _channel.invokeMethod<void>('startTrip', state.toJson());
    } on Exception catch (e) {
      // Platform channel error logged gracefully without crashing app
      assert(() {
        // ignore: avoid_print
        print('LiveTripService error on startTrip: $e');
        return true;
      }());
    }
  }

  @override
  Future<void> updateTrip(LiveTripState state) async {
    try {
      await _channel.invokeMethod<void>('updateTrip', state.toJson());
    } on Exception catch (e) {
      assert(() {
        // ignore: avoid_print
        print('LiveTripService error on updateTrip: $e');
        return true;
      }());
    }
  }

  @override
  Future<void> endTrip() async {
    try {
      await _channel.invokeMethod<void>('endTrip');
    } on Exception catch (e) {
      assert(() {
        // ignore: avoid_print
        print('LiveTripService error on endTrip: $e');
        return true;
      }());
    }
  }
}

class LiveTripNotifier extends StateNotifier<LiveTripState?> {
  LiveTripNotifier(this._service) : super(null);

  final LiveTripService _service;

  Future<void> startTrip(LiveTripState trip) async {
    state = trip;
    await _service.requestPermission();
    await _service.startTrip(trip);
  }

  Future<void> updateTrip(LiveTripState updated) async {
    state = updated;
    await _service.updateTrip(updated);
  }

  Future<void> advanceProgress(double progressDelta) async {
    if (state == null) return;
    final current = state!;
    final newProgress = (current.progress + progressDelta).clamp(0.0, 1.0);
    final newStops = ((1.0 - newProgress) * 5).ceil();

    final newStatus = newProgress >= 1.0
        ? LiveTripStatus.ended
        : (newProgress >= 0.9 ? LiveTripStatus.atStop : current.status);

    final updated = current.copyWith(
      progress: newProgress,
      stopsRemaining: newStops,
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    await updateTrip(updated);
  }

  Future<void> endTrip() async {
    if (state != null) {
      final ended = state!.copyWith(
        status: LiveTripStatus.ended,
        progress: 1.0,
        stopsRemaining: 0,
        updatedAt: DateTime.now(),
      );
      await _service.updateTrip(ended);
    }
    state = null;
    await _service.endTrip();
  }
}

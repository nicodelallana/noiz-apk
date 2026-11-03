import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_location.dart';

class UserLocation {
  const UserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationServiceImpl();
});

abstract class LocationService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<UserLocation?> getCurrentLocation();
}

class LocationServiceImpl implements LocationService {
  static const MethodChannel _channel =
      MethodChannel('com.bizkaia.transit/live_trip');

  /// Web only: the fix obtained while asking for permission, so the prompt
  /// and the first position come from a single browser request.
  UserLocation? _webFix;

  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('hasLocationPermission');
      return granted ?? false;
    } on Exception {
      // PlatformException, or MissingPluginException where the native
      // channel is not implemented yet (iOS).
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final pos = await browserPosition();
      if (pos == null) return false;
      _webFix = UserLocation(latitude: pos.latitude, longitude: pos.longitude);
      return true;
    }
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestLocationPermission');
      return granted ?? false;
    } on Exception {
      // PlatformException, or MissingPluginException where the native
      // channel is not implemented yet (iOS).
      return false;
    }
  }

  @override
  Future<UserLocation?> getCurrentLocation() async {
    if (kIsWeb) {
      final cached = _webFix;
      if (cached != null) {
        _webFix = null;
        return cached;
      }
      final pos = await browserPosition();
      return pos == null
          ? null
          : UserLocation(latitude: pos.latitude, longitude: pos.longitude);
    }
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final map =
          await _channel.invokeMapMethod<String, dynamic>('getLocation');
      if (map != null &&
          map['latitude'] != null &&
          map['longitude'] != null) {
        return UserLocation(
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
        );
      }
      return null;
    } on Exception {
      // PlatformException, or MissingPluginException where the native
      // channel is not implemented yet (iOS).
      return null;
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('hasLocationPermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestLocationPermission');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<UserLocation?> getCurrentLocation() async {
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
    } on PlatformException {
      return null;
    }
  }
}

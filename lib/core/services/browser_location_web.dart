import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// One fix from the browser Geolocation API. The first call shows the
/// browser's permission prompt; denial, timeout or no fix return null.
Future<({double latitude, double longitude})?> browserPosition() {
  final completer = Completer<({double latitude, double longitude})?>();
  web.window.navigator.geolocation.getCurrentPosition(
    ((web.GeolocationPosition pos) {
      if (!completer.isCompleted) {
        completer.complete(
          (latitude: pos.coords.latitude, longitude: pos.coords.longitude),
        );
      }
    }).toJS,
    ((web.GeolocationPositionError _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
    web.PositionOptions(timeout: 8000, maximumAge: 120000),
  );
  return completer.future;
}

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// The device's position, resolved once per session and shown automatically on
/// every map. Widgets listen to [position]; each map calls [ensure] in its
/// `initState` (idempotent).
///
/// [resolver] is swapped out in tests — the `geolocator` plugin has no platform
/// implementation under `flutter test`.
class UserLocation {
  UserLocation._();

  /// `null` until resolved (or if location is off / denied / the fix failed).
  static final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  /// The strategy used by [ensure]. Override in tests.
  static Future<LatLng?> Function() resolver = _fromGeolocator;

  static Future<void>? _ensuring;

  /// Resolve the position once for the session. Safe to call from every map;
  /// updates [position] when the fix arrives. Never throws.
  static Future<void> ensure() => _ensuring ??= _run();

  static Future<void> _run() async {
    final fix = await resolver();
    if (fix != null) position.value = fix;
  }

  /// Test seam — forget the cached fix so the next [ensure] re-resolves.
  @visibleForTesting
  static void resetForTest() {
    _ensuring = null;
    position.value = null;
  }

  static Future<LatLng?> _fromGeolocator() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 12),
          ),
        );
        return LatLng(fix.latitude, fix.longitude);
      } catch (_) {
        // Emulators with no location set time out here — fall back to any
        // cached fix before giving up.
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : LatLng(last.latitude, last.longitude);
      }
    } catch (_) {
      return null;
    }
  }
}

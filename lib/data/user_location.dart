import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Resolves the device's current position for the `<지도>` "내 위치" button.
///
/// [resolver] is swapped out in tests — the `geolocator` plugin has no
/// platform implementation under `flutter test`, and this keeps the maps
/// testable without touching real location services.
class UserLocation {
  UserLocation._();

  /// The strategy used by [current]. Override in tests.
  static Future<LatLng?> Function() resolver = _fromGeolocator;

  /// The current position, or `null` when location is off, permission is
  /// denied, or the fix fails. Never throws.
  static Future<LatLng?> current() => resolver();

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
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 12),
          ),
        );
        return LatLng(position.latitude, position.longitude);
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

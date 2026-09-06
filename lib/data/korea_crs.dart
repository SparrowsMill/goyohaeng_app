import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'korea_map_geo.dart' show GeoRegion, GeoLabel;

/// A WGS84 geographic coordinate (EPSG:4326), in degrees.
///
/// Deliberately not tied to any map-SDK type — the real-map stage (Phase C)
/// converts this to the chosen SDK's coordinate class (`NLatLng` for
/// `flutter_naver_map`) right at the widget boundary.
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  String toString() =>
      'LatLng(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}

/// Inverse projection for the CRS the `assets/maps/` GeoJSON is stored in:
/// **EPSG:5179** (Korea 2000 / Unified CS) — a Transverse Mercator on GRS80.
///
/// proj4 string:
/// `+proj=tmerc +lat_0=38 +lon_0=127.5 +k=0.9996 +x_0=1000000 +y_0=2000000`
/// `+ellps=GRS80 +units=m +no_defs`
///
/// Only the inverse (projected metres → lat/lng) is implemented — that is all
/// the real-map stage needs (camera targets, marker positions). The standard
/// Snyder inverse-TM series is accurate to well under a metre across the
/// Korean peninsula, far tighter than any camera use needs, so pulling in a
/// full projection package (`proj4dart`) would only add a dependency.
class Epsg5179 {
  Epsg5179._();

  // GRS80 ellipsoid.
  static const double _a = 6378137.0;
  static const double _f = 1 / 298.257222101;
  static final double _e2 = _f * (2 - _f);
  static final double _ep2 = _e2 / (1 - _e2);

  // Projection parameters.
  static const double _k0 = 0.9996;
  static final double _lat0 = _deg2rad(38.0);
  static final double _lon0 = _deg2rad(127.5);
  static const double _x0 = 1000000.0;
  static const double _y0 = 2000000.0;

  static final double _m0 = _meridianArc(_lat0);

  /// Converts a raw source-CRS point (`GeoRegion` / `GeoLabel` coordinates) to
  /// WGS84 lat/lng. `xy.dx` is easting (metres), `xy.dy` is northing.
  static LatLng toLatLng(Offset xy) {
    final x = xy.dx - _x0;
    final y = xy.dy - _y0;

    final m = _m0 + y / _k0;
    final mu = m /
        (_a * (1 - _e2 / 4 - 3 * _e2 * _e2 / 64 - 5 * _e2 * _e2 * _e2 / 256));

    final e1 = (1 - math.sqrt(1 - _e2)) / (1 + math.sqrt(1 - _e2));
    final e1_2 = e1 * e1, e1_3 = e1_2 * e1, e1_4 = e1_3 * e1;
    final phi1 = mu +
        (3 * e1 / 2 - 27 * e1_3 / 32) * math.sin(2 * mu) +
        (21 * e1_2 / 16 - 55 * e1_4 / 32) * math.sin(4 * mu) +
        (151 * e1_3 / 96) * math.sin(6 * mu) +
        (1097 * e1_4 / 512) * math.sin(8 * mu);

    final sinPhi1 = math.sin(phi1);
    final cosPhi1 = math.cos(phi1);
    final tanPhi1 = math.tan(phi1);

    final c1 = _ep2 * cosPhi1 * cosPhi1;
    final t1 = tanPhi1 * tanPhi1;
    final n1 = _a / math.sqrt(1 - _e2 * sinPhi1 * sinPhi1);
    final r1 =
        _a * (1 - _e2) / math.pow(1 - _e2 * sinPhi1 * sinPhi1, 1.5).toDouble();
    final d = x / (n1 * _k0);
    final d2 = d * d, d3 = d2 * d, d4 = d3 * d, d5 = d4 * d, d6 = d5 * d;

    final lat = phi1 -
        (n1 * tanPhi1 / r1) *
            (d2 / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * _ep2) * d4 / 24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * _ep2 -
                        3 * c1 * c1) *
                    d6 /
                    720);
    final lon = _lon0 +
        (d -
                (1 + 2 * t1 + c1) * d3 / 6 +
                (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * _ep2 + 24 * t1 * t1) *
                    d5 /
                    120) /
            cosPhi1;

    return LatLng(_rad2deg(lat), _rad2deg(lon));
  }

  static double _meridianArc(double phi) =>
      _a *
      ((1 - _e2 / 4 - 3 * _e2 * _e2 / 64 - 5 * _e2 * _e2 * _e2 / 256) * phi -
          (3 * _e2 / 8 + 3 * _e2 * _e2 / 32 + 45 * _e2 * _e2 * _e2 / 1024) *
              math.sin(2 * phi) +
          (15 * _e2 * _e2 / 256 + 45 * _e2 * _e2 * _e2 / 1024) *
              math.sin(4 * phi) -
          (35 * _e2 * _e2 * _e2 / 3072) * math.sin(6 * phi));

  static double _deg2rad(double d) => d * math.pi / 180;
  static double _rad2deg(double r) => r * 180 / math.pi;
}

/// SW/NE corners of a lat/lng box — the shape a map SDK wants for a
/// "fit these bounds" camera update.
typedef LatLngBounds = ({LatLng southwest, LatLng northeast});

/// Converts a source-CRS bounding [Rect] to a lat/lng box. Transverse Mercator
/// is not affine, so all four corners are projected and the extremes taken —
/// not just the two `Rect` corner points.
LatLngBounds latLngBoundsOfCrsRect(Rect crsBounds) {
  final corners = [
    Epsg5179.toLatLng(crsBounds.topLeft),
    Epsg5179.toLatLng(crsBounds.topRight),
    Epsg5179.toLatLng(crsBounds.bottomLeft),
    Epsg5179.toLatLng(crsBounds.bottomRight),
  ];
  var minLat = corners.first.lat, maxLat = corners.first.lat;
  var minLng = corners.first.lng, maxLng = corners.first.lng;
  for (final c in corners.skip(1)) {
    minLat = math.min(minLat, c.lat);
    maxLat = math.max(maxLat, c.lat);
    minLng = math.min(minLng, c.lng);
    maxLng = math.max(maxLng, c.lng);
  }
  return (
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

extension GeoRegionLatLng on GeoRegion {
  /// Bounding-box centre in WGS84 — a good enough camera target for a region;
  /// pair it with [latLngBounds] to also fit the zoom.
  LatLng get centerLatLng => Epsg5179.toLatLng(bounds.center);

  /// This region's extent as a lat/lng box.
  LatLngBounds get latLngBounds => latLngBoundsOfCrsRect(bounds);
}

extension GeoLabelLatLng on GeoLabel {
  /// The place-name anchor in WGS84 — the intended centre for this region.
  LatLng get latLng => Epsg5179.toLatLng(point);
}

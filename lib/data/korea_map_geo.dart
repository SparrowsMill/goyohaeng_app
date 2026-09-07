import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Vector map data for `<지도>`, parsed from `assets/maps/`.
///
/// The source GeoJSON is in a projected CRS (metres, y increases north), so
/// coordinates are large numbers like `955018, 1950397` — **not** lat/lng.
/// We keep every point in that raw CRS and let [KoreaGeo.projector] map the
/// shared bounding box into widget space (flipping y) at paint time. The raw
/// values are deliberately preserved so a future "real map" stage can convert
/// a tapped region's coordinate for a map-SDK camera.
///
/// - 시도 (17) + their label points load eagerly (~166 KB).
/// - 시군구 (250) + their label points load lazily on first mid-zoom, parsed
///   in a background isolate (~440 KB) so the first pinch doesn't jank.
class GeoRegion {
  GeoRegion({required this.id, required this.title, required this.rings});

  /// 행정구역 코드. 시도 = 2자리 (`"11"`), 시군구 = 5자리 (`"11010"`); a
  /// 시군구 always starts with its 시도 code.
  final String id;
  final String title;

  /// Every closed ring — Polygon outer + holes, and each member of a
  /// MultiPolygon (mainland + islands) — in raw source-CRS coordinates.
  /// Rendered / hit-tested with even-odd fill so holes and islands both
  /// come out right.
  final List<List<Offset>> rings;

  Rect? _bounds;

  /// Bounding box of this region in raw source-CRS units.
  Rect get bounds => _bounds ??= _computeBounds(rings);

  /// 시도 code this region belongs to (its own id for a 시도).
  String get sidoId => id.length <= 2 ? id : id.substring(0, 2);
}

/// A place-name anchor (`sido_labels` / `sigungu_labels`), in raw source CRS.
class GeoLabel {
  GeoLabel({required this.id, required this.title, required this.point});

  final String id;
  final String title;
  final Offset point;

  String get sidoId => id.length <= 2 ? id : id.substring(0, 2);
}

/// Maps raw source-CRS points into a target box with a single uniform scale
/// (no stretch) and centres the result, so the map keeps its shape whatever
/// the box's aspect ratio is. The y axis is flipped (source y points north,
/// screen y points down).
///
/// [fill] interpolates the scale between *contain* (0 — the whole map fits,
/// slack becomes a letterbox margin) and *cover* (1 — the map fills the box,
/// the overflowing edges are clipped by the caller).
class MapProjector {
  MapProjector._(this.bounds, this.size, this._scale, this._dx, this._dy);

  factory MapProjector({
    required Rect bounds,
    required Size size,
    double fill = 0,
  }) {
    final sx = size.width / bounds.width;
    final sy = size.height / bounds.height;
    final scale = math.min(sx, sy) +
        (math.max(sx, sy) - math.min(sx, sy)) * fill.clamp(0.0, 1.0);
    return MapProjector._(
      bounds,
      size,
      scale,
      (size.width - bounds.width * scale) / 2,
      (size.height - bounds.height * scale) / 2,
    );
  }

  final Rect bounds;
  final Size size;
  final double _scale;
  final double _dx;
  final double _dy;

  /// Pixels per source-CRS unit the map is drawn at.
  double get scale => _scale;

  Offset call(Offset p) => Offset(
        _dx + (p.dx - bounds.left) * _scale,
        _dy + (bounds.bottom - p.dy) * _scale,
      );
}

class KoreaGeo {
  KoreaGeo._({
    required this.sido,
    required this.sidoLabels,
    required this.bounds,
  });

  /// The 17 시도 boundary polygons.
  final List<GeoRegion> sido;

  /// The 17 시도 label anchors, same order as [sido] is irrelevant — match by id.
  final List<GeoLabel> sidoLabels;

  /// Bounding box of every [sido] point, in raw source-CRS units — the whole
  /// country lays out from this one box.
  final Rect bounds;

  List<GeoRegion>? _sigungu;
  List<GeoLabel>? _sigunguLabels;
  Future<void>? _sigunguFuture;

  /// True once [ensureSigungu] has finished.
  bool get sigunguReady => _sigungu != null;

  /// The 250 시군구 polygons, or empty until [ensureSigungu] completes.
  List<GeoRegion> get sigungu => _sigungu ?? const [];

  /// The 250 시군구 label anchors, or empty until [ensureSigungu] completes.
  List<GeoLabel> get sigunguLabels => _sigunguLabels ?? const [];

  /// 시군구 belonging to one 시도.
  List<GeoRegion> sigunguOf(String sidoId) =>
      sigungu.where((r) => r.sidoId == sidoId).toList(growable: false);

  static Future<KoreaGeo>? _future;

  /// Loads (and caches) the 시도 layer. Cheap enough to parse on the main
  /// isolate.
  static Future<KoreaGeo> load() => _future ??= _load();

  static Future<KoreaGeo> _load() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/maps/sido_boundary.geojson.json'),
      rootBundle.loadString('assets/maps/sido_labels.geojson.json'),
    ]);
    final regions = _parseRegions(results[0]);
    final labels = _parseLabels(results[1]);

    var rect = regions.first.bounds;
    for (final r in regions.skip(1)) {
      rect = rect.expandToInclude(r.bounds);
    }

    return KoreaGeo._(sido: regions, sidoLabels: labels, bounds: rect);
  }

  /// Loads the 시군구 layer once, off the main isolate. Safe to call every
  /// frame — after the first call it returns the same in-flight / done future.
  Future<void> ensureSigungu() => _sigunguFuture ??= _loadSigungu();

  Future<void> _loadSigungu() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/maps/sigungu_boundary.geojson.json'),
      rootBundle.loadString('assets/maps/sigungu_labels.geojson.json'),
    ]);
    final parsed = await compute(_parseSigunguIsolate, results);
    _sigungu = parsed.$1;
    _sigunguLabels = parsed.$2;
  }
}

/// compute() entry point — `[boundaryJson, labelJson]` → (regions, labels).
(List<GeoRegion>, List<GeoLabel>) _parseSigunguIsolate(List<String> raw) =>
    (_parseRegions(raw[0]), _parseLabels(raw[1]));

List<GeoRegion> _parseRegions(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final out = <GeoRegion>[];
  for (final f in json['features'] as List) {
    final props = (f as Map<String, dynamic>)['properties'] as Map;
    final geom = f['geometry'] as Map<String, dynamic>;
    final rings = <List<Offset>>[];

    void addRing(List ring) {
      rings.add([
        for (final pt in ring)
          Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
      ]);
    }

    final coords = geom['coordinates'] as List;
    if (geom['type'] == 'Polygon') {
      for (final ring in coords) {
        addRing(ring as List);
      }
    } else {
      for (final polygon in coords) {
        for (final ring in polygon as List) {
          addRing(ring as List);
        }
      }
    }

    out.add(GeoRegion(
      id: props['id'] as String,
      title: props['title'] as String,
      rings: rings,
    ));
  }
  return out;
}

List<GeoLabel> _parseLabels(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final f in json['features'] as List)
      GeoLabel(
        id: (f['properties'] as Map)['id'] as String,
        title: (f['properties'] as Map)['title'] as String,
        point: Offset(
          ((f['geometry']['coordinates'] as List)[0] as num).toDouble(),
          ((f['geometry']['coordinates'] as List)[1] as num).toDouble(),
        ),
      ),
  ];
}

Rect _computeBounds(List<List<Offset>> rings) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final ring in rings) {
    for (final p in ring) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

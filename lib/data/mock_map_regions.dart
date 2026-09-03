import 'package:flutter/material.dart';

/// The six broad regions the `<지도>` screen divides the country into — a
/// coarser grouping than the ten sub-regions in `mock_regions.dart` (used by
/// the mill-home TOP 3 list). Each carries its average 갭지수 and the number
/// of tourist spots, shown over the watercolor map.
///
/// The map is assembled from six neutral watercolor cutouts
/// (`assets/illustrations/map/full_map/<key>_map.png`), each tinted at
/// runtime by its 갭지수 ([gapIndexColor]). Placeholder values until a real
/// backend exists; the numbers match the approved map mockup.
class MockMapRegion {
  const MockMapRegion({
    required this.key,
    required this.displayName,
    required this.avgGapIndex,
    required this.spotCount,
    required this.artSize,
    required this.artTopLeft,
    this.scale = 1.0,
    this.labelAlignment = Alignment.center,
    this.labelScale = 1.0,
  });

  /// Stable id passed to `<지역별 맵 페이지>` when the region is tapped; also
  /// the `full_map/<key>_map.png` filename stem.
  final String key;
  final String displayName;
  final int avgGapIndex;
  final int spotCount;

  /// Native pixel size of `full_map/<key>_map.png` — the source of truth for
  /// this region's aspect ratio. Only change it if the art is re-exported at
  /// a different size; to resize a region on the map, use [scale] instead.
  final Size artSize;

  /// Per-region size multiplier applied to [artSize], aspect ratio locked.
  /// This is the knob for "make 강원 a bit bigger / 제주 a bit smaller":
  /// 1.0 = native, 1.2 = 20% larger, 0.8 = 20% smaller.
  final double scale;

  /// Top-left of this cutout within the shared map composition, in the same
  /// (arbitrary) pixel units as [artSize]. These six offsets are the only
  /// hand-tuned layout values — nudge one to move a region. Everything else
  /// (overall map size, aspect ratio, each region's relative scale) follows
  /// from the art dimensions.
  final Offset artTopLeft;

  /// Where the text label (name + 갭지수/스팟 lines) sits inside the region's
  /// box. Values outside [-1, 1] float it beyond the box.
  final Alignment labelAlignment;

  /// Font-size multiplier for this region's label — the knob for "수도권 text
  /// too big / 경상 text too small". 1.0 = default, 0.8 = smaller, 1.3 = bigger.
  final double labelScale;

  String get asset => 'assets/illustrations/map/full_map/${key}_map.png';

  Rect get artRect => artTopLeft & (artSize * scale);
}

/// Ordered back-to-front (painted in this order; later regions win an
/// overlapping tap).
///
/// Per region, the tuning knobs:
///   - `scale`          → region size on the map (aspect ratio locked)
///   - `artTopLeft`     → region position within the composition
///   - `labelAlignment` → where the name/stats sit over the blob
///   - `labelScale`     → label font size for that region
/// `artSize` is the native export size and normally stays put. Values here
/// are rough starting points — expect an in-app tuning pass.
///
/// A getter, not a top-level `const`, so edits below show up on hot reload
/// (`r`) instead of only on hot restart (`R`). Do ONE hot restart after this
/// change to clear the previously-cached const, then `r` works. Switch back
/// to `const mockMapRegions = …` once the layout is settled.
List<MockMapRegion> get mockMapRegions => <MockMapRegion>[
  MockMapRegion(
    key: 'gangwon',
    displayName: '강원',
    avgGapIndex: 38,
    spotCount: 18,
    artSize: Size(508, 561),
    scale: 1.0,
    artTopLeft: Offset(655, 60),
    labelAlignment: Alignment(0.01, 0.08),
    labelScale: 0.8,
  ),
  MockMapRegion(
    key: 'chungcheong',
    displayName: '충청',
    avgGapIndex: 43,
    spotCount: 12,
    artSize: Size(609, 412),
    scale: 1.0,
    artTopLeft: Offset(230, 475),
    labelAlignment: Alignment(0.06, 0.13),
    labelScale: 0.8,
  ),
  MockMapRegion(
    key: 'gyeongsang',
    displayName: '경상',
    avgGapIndex: 67,
    spotCount: 21,
    artSize: Size(507, 653),
    scale: 1.0,
    artTopLeft: Offset(705, 540),
    labelAlignment: Alignment(-0.04, -0.05),
    labelScale: 0.8,
  ),
  MockMapRegion(
    key: 'jeolla',
    displayName: '전라',
    avgGapIndex: 58,
    spotCount: 16,
    artSize: Size(624, 546),
    scale: 1.0,
    artTopLeft: Offset(110, 810),
    labelAlignment: Alignment(0.30, -0.30),
    labelScale: 0.8,
  ),
  MockMapRegion(
    key: 'capital',
    displayName: '수도권',
    avgGapIndex: 24,
    spotCount: 15,
    artSize: Size(634, 527),
    scale: 1.0,
    artTopLeft: Offset(135, 90),
    labelAlignment: Alignment(0.25, 0.06),
    labelScale: 0.8,
  ),
  MockMapRegion(
    key: 'jeju',
    displayName: '제주',
    avgGapIndex: 74,
    spotCount: 9,
    artSize: Size(353, 170),
    scale: 1.0,
    artTopLeft: Offset(200, 1400),
    labelAlignment: Alignment(-0.28, -0.35),
    labelScale: 0.7,
  ),
];

/// Bounding box of the whole assembled map, in the same pixel units as each
/// region's [MockMapRegion.artRect].
Rect mapCompositionRect() {
  var rect = mockMapRegions.first.artRect;
  for (final region in mockMapRegions.skip(1)) {
    rect = rect.expandToInclude(region.artRect);
  }
  return rect;
}

/// 갭지수 values the color scale's two ends map to. Real data clusters in
/// roughly the 20–80 band, so anchoring the scale there (rather than a flat
/// 0–100) keeps neighbouring regions visibly distinct; values outside just
/// saturate to the end color. The legend runs pale cream ("낮음") → deep
/// olive ("높음").
const gapIndexScaleMin = 20;
const gapIndexScaleMax = 80;

/// Pale yellow-green end of the 갭지수 color scale.
const _gapLow = Color(0xFFEFE8C8);

/// Deep forest-olive end of the 갭지수 color scale.
const _gapHigh = Color(0xFF454B22);

/// Color for a given 갭지수 on the low→high scale used by the map and legend.
Color gapIndexColor(num gapIndex) {
  final t = ((gapIndex - gapIndexScaleMin) / (gapIndexScaleMax - gapIndexScaleMin))
      .clamp(0.0, 1.0);
  return Color.lerp(_gapLow, _gapHigh, t)!;
}

/// The full low→high gradient, for the legend bar.
const gapIndexGradient = LinearGradient(
  colors: [_gapLow, _gapHigh],
);

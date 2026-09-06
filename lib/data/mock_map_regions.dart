import 'package:flutter/material.dart';

/// Placeholder 갭지수 / 관광 스팟 수 for the `<지도>` screen, keyed by the
/// 행정구역 codes in `assets/maps/` (시도 = 2자리, 시군구 = 5자리).
///
/// The map is drawn from GeoJSON (`korea_map_geo.dart`); this file only
/// supplies the numbers each region is shaded and labelled by. Real values
/// come from the backend later — [mockSidoStats] is hand-set to match the
/// approved mockup, and the 250 시군구 fall back to [_deterministicStats] so
/// the mid-zoom view looks alive without authoring 250 rows by hand.
///
/// * TODO(backend): 지역별 평균 갭지수 / 스팟 수 API 연동
class RegionStats {
  const RegionStats({required this.avgGapIndex, required this.spotCount});
  final int avgGapIndex;
  final int spotCount;
}

/// 시도 code → stats. All 17 시도 present.
const mockSidoStats = <String, RegionStats>{
  '11': RegionStats(avgGapIndex: 22, spotCount: 14), // 서울특별시
  '21': RegionStats(avgGapIndex: 61, spotCount: 9), // 부산광역시
  '22': RegionStats(avgGapIndex: 58, spotCount: 7), // 대구광역시
  '23': RegionStats(avgGapIndex: 34, spotCount: 8), // 인천광역시
  '24': RegionStats(avgGapIndex: 55, spotCount: 6), // 광주광역시
  '25': RegionStats(avgGapIndex: 46, spotCount: 5), // 대전광역시
  '26': RegionStats(avgGapIndex: 52, spotCount: 5), // 울산광역시
  '29': RegionStats(avgGapIndex: 40, spotCount: 3), // 세종특별자치시
  '31': RegionStats(avgGapIndex: 27, spotCount: 19), // 경기도
  '32': RegionStats(avgGapIndex: 38, spotCount: 18), // 강원도
  '33': RegionStats(avgGapIndex: 44, spotCount: 10), // 충청북도
  '34': RegionStats(avgGapIndex: 43, spotCount: 12), // 충청남도
  '35': RegionStats(avgGapIndex: 54, spotCount: 11), // 전라북도
  '36': RegionStats(avgGapIndex: 62, spotCount: 16), // 전라남도
  '37': RegionStats(avgGapIndex: 66, spotCount: 15), // 경상북도
  '38': RegionStats(avgGapIndex: 64, spotCount: 13), // 경상남도
  '39': RegionStats(avgGapIndex: 74, spotCount: 9), // 제주특별자치도
};

/// 시군구 code → hand-set stats where real data exists; everything else uses
/// [_deterministicStats]. Keys match `mock_region_ranking.dart`.
const _sigunguOverrides = <String, RegionStats>{
  '36310': RegionStats(avgGapIndex: 78, spotCount: 4), // 담양군
  '36030': RegionStats(avgGapIndex: 82, spotCount: 3), // 순천시
  '36360': RegionStats(avgGapIndex: 76, spotCount: 2), // 보성군
  '36020': RegionStats(avgGapIndex: 68, spotCount: 3), // 여수시
  '36010': RegionStats(avgGapIndex: 47, spotCount: 2), // 목포시
  '35011': RegionStats(avgGapIndex: 61, spotCount: 2), // 전주시 완산구
  '35020': RegionStats(avgGapIndex: 54, spotCount: 2), // 군산시
};

/// Stats for any region code — 시도, 시군구, or an unknown key.
RegionStats statsForRegion(String code) {
  return mockSidoStats[code] ??
      _sigunguOverrides[code] ??
      _deterministicStats(code);
}

/// Stable pseudo-random stats derived from the code so a region always shades
/// the same way between launches, clustered in the 갭지수 20–80 band.
RegionStats _deterministicStats(String code) {
  var h = 2166136261;
  for (final unit in code.codeUnits) {
    h = (h ^ unit) * 16777619;
    h &= 0xFFFFFFFF;
  }
  return RegionStats(
    avgGapIndex: 20 + (h % 61), // 20..80
    spotCount: 2 + ((h >> 8) % 12), // 2..13
  );
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
  final t =
      ((gapIndex - gapIndexScaleMin) / (gapIndexScaleMax - gapIndexScaleMin))
          .clamp(0.0, 1.0);
  return Color.lerp(_gapLow, _gapHigh, t)!;
}

/// The full low→high gradient, for the legend bar.
const gapIndexGradient = LinearGradient(
  colors: [_gapLow, _gapHigh],
);

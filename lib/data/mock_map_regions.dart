import 'package:flutter/material.dart';

import '../api/api.dart';
import 'korea_map_geo.dart';

/// 갭지수 / 관광 스팟 수 for the `<지도>` screen, keyed by the 행정구역 codes
/// in `assets/maps/` (시도 = 2자리, 시군구 = 5자리).
///
/// The map is drawn from GeoJSON (`korea_map_geo.dart`); this file supplies
/// the numbers each region is shaded and labelled by. [loadRealRegionStats]
/// fetches `GET /regions/gap-scores`(서울만, 인증 불필요) once and matches
/// each 지역명을 GeoJSON 라벨 이름으로 대조해 실제 값을 덮어쓴다 — 서울은
/// 지금 25개 자치구뿐이라 이름이 전부 고유해서 행정코드 매핑 없이도 안전하게
/// 매칭된다([[category-taxonomy-alignment]]의 지역 코드 이슈와 별개).
/// 로드 전/실패 시, 또는 서울 밖 지역은 여전히 [mockSidoStats]/
/// [_deterministicStats] 목업으로 채운다.
class RegionStats {
  const RegionStats({required this.avgGapIndex, required this.spotCount});
  final int avgGapIndex;
  final int spotCount;
}

/// Short 시도 names for on-map labels, keyed by the GeoJSON's 행정구역 코드
/// (legacy 2-digit scheme). Falls back to the GeoJSON title if a code is new.
const kSidoShortName = <String, String>{
  '11': '서울', '21': '부산', '22': '대구', '23': '인천', '24': '광주',
  '25': '대전', '26': '울산', '29': '세종', '31': '경기', '32': '강원',
  '33': '충북', '34': '충남', '35': '전북', '36': '전남', '37': '경북',
  '38': '경남', '39': '제주',
};

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

/// `GET /regions/gap-scores`로 채워지는 실 통계 캐시. `null`이면 아직 로드
/// 전이거나 실패한 것 — 그 사이엔 [statsForRegion]이 기존 목업을 쓴다.
Map<String, RegionStats>? _realStats;
Future<void>? _realStatsLoading;

/// `<지도>` 등 진입 시 한 번 호출. 실패하면 다음 호출에서 재시도할 수 있게
/// 캐시를 비워두고 조용히 목업을 유지한다(인증 불필요 API라 로그인 여부와
/// 무관하게 호출 가능).
Future<void> loadRealRegionStats() =>
    _realStatsLoading ??= _loadRealRegionStats();

Future<void> _loadRealRegionStats() async {
  try {
    final results = await Future.wait([
      GapService().regionGapScores(),
      KoreaGeo.load().then((geo) async {
        await geo.ensureSigungu();
        return geo;
      }),
    ]);
    final scores = results[0] as List<RegionGapScore>;
    final geo = results[1] as KoreaGeo;

    final codeByName = <String, String>{
      for (final l in geo.sidoLabels) l.title: l.id,
      for (final l in geo.sigunguLabels) l.title: l.id,
    };

    final stats = <String, RegionStats>{};
    for (final s in scores) {
      final code = codeByName[s.regionName];
      if (code == null) continue;
      stats[code] =
          RegionStats(avgGapIndex: s.gapIndex, spotCount: s.placeCount);
    }
    _realStats = stats;
  } catch (_) {
    _realStatsLoading = null;
  }
}

/// Stats for any region code — 시도, 시군구, or an unknown key. [_realStats]에
/// 있으면 그 값을, 없으면(로드 전·실패·서울 밖 지역) 목업을 쓴다.
RegionStats statsForRegion(String code) {
  return _realStats?[code] ??
      mockSidoStats[code] ??
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
/// saturate to the end color.
///
/// The scale runs 붉은 흙빛 ("낮음") → 중립 회색 (중간) → 차분한 남청색
/// ("높음"), all muted to sit inside the warm storybook palette.
const gapIndexScaleMin = 20;
const gapIndexScaleMax = 80;

/// Muted terracotta — 갭지수가 낮은 쪽 (관심 대비 방문이 이미 많음).
const _gapLow = Color(0xFFB75E4D);

/// Neutral warm grey — the middle of the scale. Deliberately near-colourless
/// (balanced RGB) so it never reads as a third category and the red↔blue lerp
/// doesn't pass through a muddy green.
const _gapMid = Color(0xFFC9C5BF);

/// Muted slate blue — 갭지수가 높은 쪽 (숨은 명소).
const _gapHigh = Color(0xFF4C6B8A);

/// Color for a given 갭지수 on the low→mid→high scale used by the map, pins,
/// and legend.
Color gapIndexColor(num gapIndex) {
  final t =
      ((gapIndex - gapIndexScaleMin) / (gapIndexScaleMax - gapIndexScaleMin))
          .clamp(0.0, 1.0);
  return t < 0.5
      ? Color.lerp(_gapLow, _gapMid, t * 2)!
      : Color.lerp(_gapMid, _gapHigh, (t - 0.5) * 2)!;
}

/// [gapIndexColor] with its lightness clamped into a legible band — for using
/// the gap colour as *text* or a small *icon* on the light card surfaces, where
/// the raw pale middle of the scale would wash out. Same hue, just deep enough.
Color gapIndexAccent(num gapIndex) {
  final hsl = HSLColor.fromColor(gapIndexColor(gapIndex));
  return hsl.withLightness(hsl.lightness.clamp(0.34, 0.56)).toColor();
}

/// The full low→high gradient, for the legend bar.
const gapIndexGradient = LinearGradient(
  colors: [_gapLow, _gapMid, _gapHigh],
);

/// Soft watercolor sea behind the land on every Korea map (the `<지도>` vector
/// map and the mill-home mini map) — a muted sky blue that still sits inside
/// the warm storybook palette.
const kMapSeaColor = Color(0xFFAEC7D6);

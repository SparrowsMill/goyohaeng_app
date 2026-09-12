import 'package:flutter/foundation.dart' show immutable;

import 'gap_spots.dart';
import 'korea_map_geo.dart';
import 'mock_map_regions.dart' show statsForRegion;
import 'mock_region_ranking.dart';

/// 지역(시도/시군구)은 GeoJSON 행정구역에서, 장소는 실 GAP 데이터
/// (`GapSpots.instance.allSpotsWithRegion`)에서 인메모리 인덱스를 만든다.
/// GAP API/geo 로드가 실패하거나 빈 응답이면 `mock_region_ranking.dart`로
/// 폴백해 검색이 비지 않게 한다 (`GapSpots`의 다른 메서드들과 같은 패턴).
///
/// One hit from the `<지도>` search bar — either a region (시도/시군구) or a
/// mock 관광 스팟. Both resolve to a [regionCode] that opens `<지역별 랭킹>`;
/// a place hit also carries the [spot] so that screen can pre-select it
/// (pin + "자세히 보기").
@immutable
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.regionCode,
    required this.regionName,
    required this.title,
    required this.subtitle,
    required this.gapIndex,
    this.spot,
  });

  /// 행정구역 코드 — 시도 2자리 or 시군구 5자리.
  final String regionCode;

  /// Human name for that region, used as the `<지역별 랭킹>` app-bar title.
  final String regionName;

  /// Row title: the place name for a spot, the region name otherwise.
  final String title;

  /// Row subtitle: "$지역 · $spotType" for a spot, the parent 시도 for a region.
  final String subtitle;

  /// 갭지수 — the spot's own value, or the region's average.
  final int gapIndex;

  /// Non-null for a place hit → pre-select this spot in `<지역별 랭킹>`.
  final MockTouristSpot? spot;

  bool get isPlace => spot != null;
}

String _norm(String s) => s.replaceAll(' ', '').toLowerCase();

/// In-memory index over the 17 시도, 250 시군구, and every mock 관광 스팟.
/// Built once (GeoJSON is loaded + cached the same way [KoreaGeo] does it).
class PlaceSearchIndex {
  PlaceSearchIndex._(this._entries);

  final List<PlaceSearchResult> _entries;

  static Future<PlaceSearchIndex>? _future;

  /// Loads (and caches) the index. Safe to call repeatedly.
  static Future<PlaceSearchIndex> load() => _future ??= _load();

  static Future<PlaceSearchIndex> _load() async {
    final geo = await KoreaGeo.load();
    await geo.ensureSigungu();

    final names = <String, String>{
      for (final r in geo.sido) r.id: r.title,
      for (final r in geo.sigungu) r.id: r.title,
    };

    final entries = <PlaceSearchResult>[];

    for (final r in geo.sido) {
      entries.add(PlaceSearchResult(
        regionCode: r.id,
        regionName: r.title,
        title: r.title,
        subtitle: '시·도',
        gapIndex: statsForRegion(r.id).avgGapIndex,
      ));
    }
    for (final r in geo.sigungu) {
      final sido = names[r.sidoId] ?? '';
      entries.add(PlaceSearchResult(
        regionCode: r.id,
        regionName: r.title,
        title: r.title,
        subtitle: sido.isEmpty ? '시·군·구' : sido,
        gapIndex: statsForRegion(r.id).avgGapIndex,
      ));
    }

    final hits = await GapSpots.instance.allSpotsWithRegion();
    if (hits.isNotEmpty) {
      for (final hit in hits) {
        final spot = hit.spot;
        final typeLabel = spot.categoryName ?? spot.category.label;
        entries.add(PlaceSearchResult(
          regionCode: hit.regionCode,
          regionName: hit.regionName,
          title: spot.name,
          subtitle: '${hit.regionName} · $typeLabel',
          gapIndex: spot.gapIndex,
          spot: spot,
        ));
      }
    } else {
      // GAP API/geo 실패 또는 빈 응답 — 목업 스팟으로 폴백.
      for (final entry in mockRegionRankings.entries) {
        final code = entry.key;
        final regionName = names[code] ?? '';
        for (final spot in entry.value) {
          entries.add(PlaceSearchResult(
            regionCode: code,
            regionName: regionName.isEmpty ? spot.address : regionName,
            title: spot.name,
            subtitle: regionName.isEmpty
                ? spot.spotType
                : '$regionName · ${spot.spotType}',
            gapIndex: spot.gapIndex,
            spot: spot,
          ));
        }
      }
    }

    return PlaceSearchIndex._(entries);
  }

  /// Best matches for [rawQuery], most relevant first. A place matches on its
  /// own name or its region's name; a region matches on its name. Places rank
  /// ahead of regions within the same match quality.
  List<PlaceSearchResult> query(String rawQuery, {int limit = 20}) {
    final q = _norm(rawQuery);
    if (q.isEmpty) return const [];

    final scored = <({PlaceSearchResult r, int s})>[];
    for (final e in _entries) {
      final title = _norm(e.title);
      final matchesTitle = title.contains(q);
      final matchesRegion = e.isPlace && _norm(e.regionName).contains(q);
      if (!matchesTitle && !matchesRegion) continue;

      final int rank;
      if (title == q) {
        rank = 0;
      } else if (title.startsWith(q)) {
        rank = 1;
      } else if (matchesTitle) {
        rank = 2;
      } else {
        rank = 3; // region-name-only match
      }
      final tiebreak = (e.isPlace ? 0 : 500) + title.length;
      scored.add((r: e, s: rank * 100000 + tiebreak));
    }
    scored.sort((a, b) => a.s.compareTo(b.s));
    return [for (final x in scored.take(limit)) x.r];
  }
}

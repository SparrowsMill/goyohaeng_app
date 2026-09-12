import 'dart:ui' show Offset;

import '../api/api.dart';
import 'korea_crs.dart' show Epsg5179, LatLng;
import 'korea_map_geo.dart';
import 'mock_region_ranking.dart';

/// GAP Score 기반 관광지 데이터 소스 — `<지역별 랭킹>`이 목업(`mockRegionRankings`)
/// 대신 여기서 스팟을 읽는다.
///
/// 백엔드 `regions`에 앱의 전국 행정표준코드(시도 2·시군구 5)가 없어
/// `?regionId=` 필터를 못 쓴다 ([[gap-score-api]]). 대신 `GET /places/gap/map`
/// (필터 없이 전국, 좌표 포함)을 한 번 받아 캐시하고, 탭한 시군구의 GeoJSON
/// 폴리곤에 좌표가 들어오는 장소만 **클라측에서** 골라낸다.
///
/// 카테고리 필터는 `GET /categories`의 level 1(음식·숙박·관광지 …)로 구성한다
/// (앱의 식당/카페/액티비티 enum은 실 택소노미와 안 맞음).
class GapSpots {
  GapSpots._();

  static final GapSpots instance = GapSpots._();

  final GapService _gap = GapService();
  final CategoryService _categories = CategoryService();

  Future<_GapData>? _data;

  Future<_GapData> _load() => _data ??= _fetch();

  Future<_GapData> _fetch() async {
    final results = await Future.wait([
      _gap.map(),
      _categories.list().catchError((_) => <Category>[]),
      KoreaGeo.load().then((geo) async {
        await geo.ensureSigungu();
        return geo;
      }),
    ]);
    final map = results[0] as GapMapData;
    final cats = results[1] as List<Category>;
    final geo = results[2] as KoreaGeo;

    // leaf categoryId → 그 category의 level-1 조상.
    final byId = {for (final c in cats) c.id: c};
    Category? level1Of(int? id) {
      Category? cur = id == null ? null : byId[id];
      while (cur != null && cur.parentId != null) {
        final next = byId[cur.parentId];
        if (next == null) break;
        cur = next;
      }
      return cur;
    }

    final level1s = cats.where((c) => c.parentId == null && c.isActive).toList();

    return _GapData(
      geo: geo,
      places: map.items.where((p) => p.hasLocation).toList(),
      level1Categories: level1s,
      level1NameFor: {
        for (final p in map.items)
          if (p.categoryId != null) p.categoryId!: level1Of(p.categoryId)?.name,
      },
    );
  }

  /// 랭킹 필터 칩용 level-1 카테고리. 로드 전이면 빈 목록.
  Future<List<Category>> level1Categories() async =>
      (await _load()).level1Categories;

  /// 한 행정구역(시군구 5자리 정확 매칭, 또는 시도 2자리 → 하위 전체)에 좌표가
  /// 들어오는 GAP 스팟을 GAP Score 내림차순으로. API 실패/빈 응답이면 목업으로
  /// 폴백해 화면이 비지 않게 한다.
  Future<List<MockTouristSpot>> spotsInRegion(String regionCode) async {
    final _GapData data;
    try {
      data = await _load();
    } catch (_) {
      return rankingForRegion(regionCode);
    }

    final regions = [
      for (final r in data.geo.sigungu)
        if (regionCode.length >= 5
            ? r.id == regionCode
            : r.id.startsWith(regionCode))
          r,
    ];
    if (regions.isEmpty) return rankingForRegion(regionCode);

    final spots = <MockTouristSpot>[
      for (final p in data.places)
        if (_inAny(regions, Epsg5179.fromLatLng(LatLng(p.latitude!, p.longitude!))))
          _toSpot(p, data),
    ]..sort((a, b) => b.gapIndex.compareTo(a.gapIndex));

    return spots.isEmpty ? rankingForRegion(regionCode) : spots;
  }

  MockTouristSpot _toSpot(GapPlace p, _GapData data) =>
      gapPlaceToSpot(p, categoryName: data.level1NameFor[p.categoryId]);

  static bool _inAny(List<GeoRegion> regions, Offset pt) {
    for (final r in regions) {
      if (r.bounds.contains(pt) && _pointInRings(r.rings, pt)) return true;
    }
    return false;
  }

  /// 짝수-홀수(even-odd) 규칙: 모든 링에 대해 교차 횟수를 합산 — 구멍/섬 모두
  /// 올바르게 처리된다 (`GeoRegion`이 렌더링에 쓰는 규칙과 동일).
  static bool _pointInRings(List<List<Offset>> rings, Offset pt) {
    var inside = false;
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final a = ring[i], b = ring[j];
        if ((a.dy > pt.dy) != (b.dy > pt.dy)) {
          final x = a.dx + (pt.dy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx);
          if (pt.dx < x) inside = !inside;
        }
      }
    }
    return inside;
  }
}

/// `GapPlace`(랭킹·지도·추천 공용) → 화면 뷰모델 `MockTouristSpot`. GAP API가
/// 안 주는 필드(운영시간·주인 소개·트렌드 키워드·혜택 등)는 목업 기본값으로
/// 두고, placeId 진입 후 `<장소 정보>`가 `GET /places/{id}`로 채운다.
MockTouristSpot gapPlaceToSpot(GapPlace p, {String? categoryName}) =>
    MockTouristSpot(
      placeId: p.placeId,
      name: p.placeName ?? '이름 미상',
      category: SpotCategory.activity,
      categoryName: categoryName,
      gapIndex: p.gapIndex,
      visitVerifiable: true,
      ingredient: null,
      businessStatus: BusinessStatus.open,
      address: p.roadAddress ?? '주소 정보를 준비하고 있어요',
      lat: p.latitude,
      lng: p.longitude,
    );

class _GapData {
  _GapData({
    required this.geo,
    required this.places,
    required this.level1Categories,
    required this.level1NameFor,
  });

  final KoreaGeo geo;
  final List<GapPlace> places;
  final List<Category> level1Categories;

  /// leaf categoryId → level-1 category name.
  final Map<int, String?> level1NameFor;
}

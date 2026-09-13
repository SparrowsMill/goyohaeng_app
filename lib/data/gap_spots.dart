import 'dart:ui' show Offset;

import '../api/api.dart';
import 'korea_crs.dart' show Epsg5179, LatLng;
import 'korea_map_geo.dart';
import 'mock_region_ranking.dart';

/// GAP Score 기반 관광지 데이터 소스 — `<지역별 랭킹>`이 목업(`mockRegionRankings`)
/// 대신 여기서 스팟을 읽는다.
///
/// 백엔드 `regions`에 앱의 전국 지역 코드(시도 2·시군구 5, 통계청 SGIS
/// 행정구역코드 — 행정안전부 법정동코드/행정동코드와는 다른 별개 체계)가
/// 없어 전국 단위로는 `?regionId=` 필터를 못 쓴다([[gap-score-api]]). 기본
/// 경로는 `GET /places/gap/map`(지역 필터 없이 전국, 좌표 포함)을 받아
/// 캐시하고, 탭한 시군구의 GeoJSON 폴리곤에 좌표가 들어오는 장소만
/// **클라측에서** 골라내는 것이다.
///
/// **단, 서울 자치구는 예외**다. 백엔드 `Region` 테이블에 서울(시도 1 +
/// 자치구 25)이 이미 등록돼 있고, 그 `regionId`는 SGIS 코드와 무관하게 지금
/// 바로 쓸 수 있다(2026-09-13 확인, `docs/backend_requirements_pending.md`
/// §5-2). `_GapMeta.regionIdByDistrictName`이 GeoJSON 시군구 이름과 내부
/// `Region.name`을 대조해(서울 자치구는 이름이 고유해 안전) regionId를 찾으면, `GET
/// /places/gap/rankings?regionId=`를 직접 호출한다 — 좌표가 없는 장소도
/// 포함된 완전한 랭킹을 서버가 주므로, 좌표 있는 장소만 내려주는
/// `/places/gap/map` + 폴리곤 필터보다 더 정확하다. 매칭 실패/응답 실패 시
/// 기존 폴리곤 경로로 폴백한다.
///
/// 카테고리 필터는 `GET /categories`의 level 1(음식·숙박·관광지 …)로 구성하고
/// (앱의 식당/카페/액티비티 enum은 실 택소노미와 안 맞음), 실제 필터링은
/// `categoryId`를 그대로 넘겨 **서버 cascade**에 맡긴다 — 2026-09-12 배포로
/// `/places`, `/places/gap/rankings`, `/places/gap/map` 세 엔드포인트 모두
/// 상위 categoryId를 하위(leaf)까지 포함해서 필터링하는 것을 직접
/// 검증했다. 지역 필터와 달리 카테고리는 [_places]가 `categoryId`별로 별도
/// 캐시해 필터를 바꿀 때만 다시 받는다.
class GapSpots {
  GapSpots._();

  static final GapSpots instance = GapSpots._();

  final GapService _gap = GapService();
  final CategoryService _categories = CategoryService();
  final RegionService _regions = RegionService();

  Future<_GapMeta>? _meta;

  /// `categoryId`별 위치 있는 GAP 스팟 캐시. `null` 키 = 카테고리 필터 없음.
  final Map<int?, Future<List<GapPlace>>> _places = {};

  /// `(regionId, categoryId)`별 랭킹 캐시 — 서울 자치구 regionId 경로용.
  final Map<(int, int?), Future<List<GapPlace>?>> _regionRankings = {};

  Future<_GapMeta> _loadMeta() => _meta ??= _fetchMeta();

  Future<_GapMeta> _fetchMeta() async {
    final results = await Future.wait([
      _categories.list().catchError((_) => <Category>[]),
      KoreaGeo.load().then((geo) async {
        await geo.ensureSigungu();
        return geo;
      }),
      _regions.list().catchError((_) => <Region>[]),
    ]);
    final cats = results[0] as List<Category>;
    final geo = results[1] as KoreaGeo;
    final regions = results[2] as List<Region>;

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

    // 서울 자치구 이름 → 내부 regionId. 이름이 서울 안에서 고유해 코드 매핑
    // 없이도 안전하게 대응된다([[gap-score-api]]와 같은 방식).
    final districtIdByName = {
      for (final r in regions)
        if (r.regionType == 'DISTRICT') r.name: r.id,
    };

    return _GapMeta(
      geo: geo,
      level1Categories: level1s,
      level1Of: level1Of,
      regionIdByDistrictName: districtIdByName,
    );
  }

  /// [regionId] 기준 GAP 랭킹 전체(좌표 유무 무관) — 실패/데이터 없음이면
  /// `null`을 반환해 폴리곤 폴백을 쓰게 한다. 자치구 하나의 스팟 수는 많지
  /// 않다고 보고 첫 페이지(limit 100)만 받는다.
  Future<List<GapPlace>?> _loadRegionRankings(int regionId, int? categoryId) =>
      _regionRankings[(regionId, categoryId)] ??=
          _fetchRegionRankings(regionId, categoryId);

  Future<List<GapPlace>?> _fetchRegionRankings(
    int regionId,
    int? categoryId,
  ) async {
    try {
      final page = await _gap.rankings(
        regionId: regionId,
        categoryId: categoryId,
        limit: 100,
      );
      return page.items.isEmpty ? null : page.items;
    } catch (_) {
      return null;
    }
  }

  Future<List<GapPlace>> _loadPlaces(int? categoryId) =>
      _places[categoryId] ??= _fetchPlaces(categoryId);

  Future<List<GapPlace>> _fetchPlaces(int? categoryId) async {
    final map = await _gap.map(categoryId: categoryId);
    return map.items.where((p) => p.hasLocation).toList();
  }

  /// 랭킹 필터 칩용 level-1 카테고리. 로드 전이면 빈 목록.
  Future<List<Category>> level1Categories() async =>
      (await _loadMeta()).level1Categories;

  /// [GapPlace] → 화면 뷰모델, 같은 카테고리 이름 매핑을 적용해서. `<전체 랭킹>`처럼
  /// 위치·지역 필터 없이 `GapService.rankings`를 직접 페이지네이션해 부른
  /// 결과에도 [spotsInRegion]/[allSpots]와 같은 변환을 쓰고 싶을 때.
  Future<List<MockTouristSpot>> toSpots(List<GapPlace> places) async {
    final meta = await _loadMeta();
    return [for (final p in places) _toSpot(p, meta)];
  }

  /// 위치가 있는 전국 GAP 스팟 전체 — 지역 필터 없이. `<지도>`의 전국 검색처럼
  /// 한 지역에 묶이지 않는 화면용. API 실패 시 빈 목록(호출부가 자체 폴백 처리).
  Future<List<MockTouristSpot>> allSpots() async {
    try {
      final meta = await _loadMeta();
      final places = await _loadPlaces(null);
      return [for (final p in places) _toSpot(p, meta)];
    } catch (_) {
      return const [];
    }
  }

  /// 위치가 있는 전국 GAP 스팟 전체를, 좌표가 들어오는 시군구(코드+이름)와
  /// 짝지어 반환 — `<지도>` 검색(`PlaceSearchIndex`)이 스팟마다 `regionCode`를
  /// 필요로 하기 때문. [spotsInRegion]과 같은 점-다각형 판정을 반대 방향으로
  /// 쓴다 (스팟 → 그 안에 담는 시군구). 어떤 시군구 폴리곤에도 들지 않는
  /// 스팟(해안선 오차 등)은 제외. API/geo 실패 시 빈 목록.
  Future<List<GapSpotHit>> allSpotsWithRegion() async {
    try {
      final meta = await _loadMeta();
      final places = await _loadPlaces(null);
      final hits = <GapSpotHit>[];
      for (final p in places) {
        final pt = Epsg5179.fromLatLng(LatLng(p.latitude!, p.longitude!));
        for (final r in meta.geo.sigungu) {
          if (r.bounds.contains(pt) && _pointInRings(r.rings, pt)) {
            hits.add(GapSpotHit(
              spot: _toSpot(p, meta),
              regionCode: r.id,
              regionName: r.title,
            ));
            break;
          }
        }
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  /// 한 행정구역(시군구 5자리 정확 매칭, 또는 시도 2자리 → 하위 전체)에 좌표가
  /// 들어오는 GAP 스팟을 GAP Score 내림차순으로. [categoryId]를 주면 서버가
  /// 그 카테고리(+하위 categoryId까지 cascade)로 미리 걸러준 결과를 받는다.
  /// API 실패/빈 응답이면 목업으로 폴백해 화면이 비지 않게 한다.
  Future<List<MockTouristSpot>> spotsInRegion(
    String regionCode, {
    int? categoryId,
  }) async {
    final _GapMeta meta;
    try {
      meta = await _loadMeta();
    } catch (_) {
      return rankingForRegion(regionCode);
    }

    // 서울 자치구(시군구 5자리 정확 매칭)면 실 regionId로 서버 랭킹을 바로
    // 쓴다 — 좌표 없는 장소도 포함돼 아래 폴리곤 경로보다 완전하다.
    if (regionCode.length >= 5) {
      GeoRegion? district;
      for (final r in meta.geo.sigungu) {
        if (r.id == regionCode) {
          district = r;
          break;
        }
      }
      final regionId =
          district == null ? null : meta.regionIdByDistrictName[district.title];
      if (regionId != null) {
        final ranked = await _loadRegionRankings(regionId, categoryId);
        if (ranked != null && ranked.isNotEmpty) {
          return <MockTouristSpot>[for (final p in ranked) _toSpot(p, meta)]
            ..sort((a, b) => b.gapIndex.compareTo(a.gapIndex));
        }
      }
    }

    final List<GapPlace> places;
    try {
      places = await _loadPlaces(categoryId);
    } catch (_) {
      return rankingForRegion(regionCode);
    }

    final regions = [
      for (final r in meta.geo.sigungu)
        if (regionCode.length >= 5
            ? r.id == regionCode
            : r.id.startsWith(regionCode))
          r,
    ];
    if (regions.isEmpty) return rankingForRegion(regionCode);

    final spots = <MockTouristSpot>[
      for (final p in places)
        if (_inAny(regions, Epsg5179.fromLatLng(LatLng(p.latitude!, p.longitude!))))
          _toSpot(p, meta),
    ]..sort((a, b) => b.gapIndex.compareTo(a.gapIndex));

    return spots.isEmpty ? rankingForRegion(regionCode) : spots;
  }

  MockTouristSpot _toSpot(GapPlace p, _GapMeta meta) =>
      gapPlaceToSpot(p, categoryName: meta.level1Of(p.categoryId)?.name);

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

/// One [allSpotsWithRegion] result: a GAP spot plus the 시군구 its coordinates
/// fall inside.
class GapSpotHit {
  const GapSpotHit({
    required this.spot,
    required this.regionCode,
    required this.regionName,
  });

  final MockTouristSpot spot;

  /// 시군구 코드 (5자리).
  final String regionCode;
  final String regionName;
}

class _GapMeta {
  _GapMeta({
    required this.geo,
    required this.level1Categories,
    required this.level1Of,
    required this.regionIdByDistrictName,
  });

  final KoreaGeo geo;
  final List<Category> level1Categories;

  /// leaf categoryId → level-1 조상 category (또는 그 자신).
  final Category? Function(int? id) level1Of;

  /// GeoJSON 시군구 이름 → 내부 `Region.id` (서울 자치구만 채워짐).
  final Map<String, int> regionIdByDistrictName;
}

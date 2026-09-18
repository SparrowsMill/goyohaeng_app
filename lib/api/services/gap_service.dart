import '../api_client.dart';
import '../models.dart';

/// GAP Score 조회 (2026-09-11). 모든 값은 DB에 저장된 최신 `GapScoreRun`
/// 결과이며, 프론트에서 GAP Score를 직접 계산하지 않는다.
///
/// - `GET /places/{id}/gap` — 장소별 최신 GAP Score (인증 불필요 — 문서와
///   실제 컨트롤러 가드 불일치가 있었으나 2026-09-14 문서를 코드에 맞게 수정)
/// - `GET /places/gap/rankings` — GAP Score 랭킹 (run + items + pagination)
/// - `GET /places/gap/map` — 지도용 마커 (좌표 포함, 좌표 없는 장소 제외)
/// - `GET /places/{id}/recommendations` — 같은 지역·카테고리의 비슷한 GAP 장소
/// - `GET /regions/gap-scores` — 지역별 평균 GAP Score
///
/// [regionId] / [categoryId] 필터에 대한 백엔드 실측(2026-09-11, 2026-09-13,
/// 2026-09-14 갱신):
///
/// * `regionId` — `GET /regions`는 `{id, parentId, regionType, name}`만 준다
///   (지역 코드 필드 없음). `regionType`은 `PROVINCE`(서울 1개) /
///   `DISTRICT`(서울 자치구 25개) / `FOOD_REGION`(6개)뿐이라, 앱의 전국
///   GeoJSON(시도 2자리·시군구 5자리 — 통계청 SGIS 행정구역코드, 행정안전부
///   법정동코드/행정동코드와는 다른 별개 체계)과 매핑할 값이 DB에 없다.
///   `region_external_codes`의 코드는 TourAPI 순번(서울="1", 강남구="1"…)이지
///   SGIS 행정구역코드가 아니다.
///   **2026-09-13 백엔드 확인**: 이 `regionId`는 애초에 SGIS 코드가 아니라
///   내부 DB `Region.id`(bigint)이고, `GET /regions`에 SGIS 필드가 추가되는지
///   여부와 무관하게 지금 바로 쓸 수 있다(`docs/backend_requirements_pending.md`
///   §4). 다만 현재 `Region` 테이블엔 서울(PROVINCE 1 + DISTRICT 25) +
///   FOOD_REGION 6개만 있어 **서울 자치구 단위까지만** 이름 매칭으로 이
///   regionId를 알아낼 수 있고, 그 밖의 지역은 여전히 regionId 필터를 못
///   쓴다([[gap-score-api]] 참고, `GapSpots`가 이름 매칭 + 클라측 폴리곤
///   필터를 병행하는 이유). 필터 없이 호출하면 전국 기준으로 내려온다.
///   **2026-09-14 업데이트**: `GET /regions`에 `sgisCode`(문자열, 시군구
///   adm_cd 5자리) 필드가 추가됐다 — 요청했던 §4가 `RegionExternalCode`
///   임포트가 아니라 `Region` 행 자체에 필드를 더하는 방식으로 처리된 것.
///   하지만 `Region` 테이블 자체는 그대로 서울+FOOD_REGION뿐이라 그 외
///   지역은 `sgisCode: null`로 내려오고, 전국 regionId 필터가 열리는 건
///   아니다 — 서울 자치구는 이름 매칭이 이미 안전해 `sgisCode`로 바꿀
///   실익도 없다. `Region` 테이블이 전국으로 확장돼야 이 필드가 실제로
///   쓰인다.
/// * `categoryId` — `GET /categories`는 2레벨 15행 트리. level 1:
///   FOOD(음식)/STAY(숙박)/ATTRACTION(관광지)/CULTURE(문화)/FESTIVAL(축제·행사)/
///   LEISURE(레저·오락)/SHOPPING(쇼핑). CAFE는 FOOD의 하위(소분류)다. 앱의
///   식당/카페/액티비티 3분류와 1:1 대응이 없고(`users.ranking_category_filter`
///   CHECK도 `ALL/FOOD/CAFE/ACTIVITY`로 택소노미와 어긋나 있음), 백엔드 정합화
///   전까지 카테고리 필터는 보류.
class GapService {
  GapService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /places/{id}/gap` — 특정 장소의 최신 GAP Score. `{id}` = placeId.
  /// 인증 불필요(비로그인도 호출 가능, `docs/api_spec.md` §7.1 2026-09-14 정정).
  Future<PlaceGapScore> placeGap(int placeId) async {
    final res = await _client.get('/places/$placeId/gap');
    return PlaceGapScore.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/gap/rankings` — 최신 run 기준 GAP Score 높은 순. `regionId`/
  /// `categoryId`는 선택 필터, `page`(기본 1)·`limit`(기본 20)로 페이지네이션.
  Future<GapRankingPage> rankings({
    int? regionId,
    int? categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get('/places/gap/rankings', query: {
      'regionId': regionId,
      'categoryId': categoryId,
      'page': page,
      'limit': limit,
    });
    return GapRankingPage.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/gap/map` — 지도 마커용. `regionId`/`categoryId`는 선택 필터.
  /// 응답의 `items`(위도/경도 포함)를 그대로 마커로 사용한다.
  Future<GapMapData> map({int? regionId, int? categoryId}) async {
    final res = await _client.get('/places/gap/map', query: {
      'regionId': regionId,
      'categoryId': categoryId,
    });
    return GapMapData.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/{id}/recommendations` — 현재 장소를 제외하고 같은 지역 +
  /// 같은 카테고리 안에서 GAP Score가 비슷한 장소. `<방문 불가>`의
  /// '함께 찾은 관광지' 등에 사용. [limit] 기본 5, 서버 최대 20(스펙 §6.8).
  /// 응답은 `{ basePlace, run, available, items }` — `basePlace`/`run`은 화면에서
  /// 안 써서 버리고 `available`/`items`만 [GapRecommendations]로 반환한다.
  Future<GapRecommendations> recommendations(int placeId, {int limit = 5}) async {
    final res = await _client.get(
      '/places/$placeId/recommendations',
      query: {'limit': limit},
    );
    if (res is List) {
      return GapRecommendations(
        available: true,
        items: res
            .whereType<Map>()
            .map((e) => GapPlace.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
    }
    return GapRecommendations.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /regions/gap-scores` — 각 지역의 최신 GAP Score 평균 + 장소 수.
  /// 지역별 지도/랭킹 화면에서 구 단위 GAP 정도를 보여줄 때 사용. 응답은
  /// 배열 또는 `{ items: [...] }`.
  Future<List<RegionGapScore>> regionGapScores() async {
    final res = await _client.get('/regions/gap-scores');
    final rows = res is List
        ? res
        : (res is Map ? res['items'] as List? ?? res['regions'] as List? : null);
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => RegionGapScore.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

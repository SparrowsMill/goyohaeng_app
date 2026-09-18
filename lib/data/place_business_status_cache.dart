/// 실 장소의 실시간 영업 여부(`Place.isOpenNow`) 앱 전역 캐시 —
/// [[place_verification_cache]]와 같은 구조: placeId별로 한 번 상세 조회된
/// 값을 기억해 둔다.
///
/// 2026-09-15부터 `GET /places/gap/rankings`·`GET /places/gap/map`·
/// `GET /places/{id}/recommendations`(랭킹/지도/추천 목록) 응답에도
/// `isOpenNow`가 직접 내려와([GapPlace.isOpenNow]) [gapPlaceToSpot]이 그
/// 값을 우선 쓴다 — 이 캐시는 그 값이 없을 때(옛 응답 등)만 쓰는 폴백이다.
/// 둘 다 없는 처음 보는 장소는 `null`(영업 여부 알 수 없음)로 남는다.
class PlaceBusinessStatusCache {
  PlaceBusinessStatusCache._();

  static final Map<int, bool> _isOpenNow = {};

  static bool? get(int placeId) => _isOpenNow[placeId];

  static void set(int placeId, bool? isOpenNow) {
    if (isOpenNow != null) _isOpenNow[placeId] = isOpenNow;
  }
}

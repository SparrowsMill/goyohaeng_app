/// 실 장소의 방문 인증 가능 여부(`Place.verification?.enabled`) 앱 전역
/// 캐시 — placeId별로 한 번 조회된 값을 기억해 둔다.
///
/// `GET /places/gap/rankings`·`GET /places/gap/map`(랭킹/지도 목록)은
/// 2026-09-14부터 각 장소에 `verificationAvailable`을 직접 내려주므로
/// ([[GapPlace.verificationAvailable]]) 이 캐시가 더 이상 그 두 목록의
/// 1차 출처는 아니다. 다만 `GET /places/{id}/recommendations`(비슷한 장소
/// 추천)처럼 아직 이 필드가 없는 응답도 있어, 그 장소를 이미 한 번이라도
/// 상세 조회했다면(`GET /places/{id}`) 그 결과를 여기 저장해 두고
/// [gapPlaceToSpot]이 재사용한다 — 새 네트워크 호출 없이 다음에 목록에 뜰
/// 때부터 정확한 값을 보여준다. 그마저도 없는 처음 보는 장소는 `null`(알
/// 수 없음)로 남는다.
class PlaceVerificationCache {
  PlaceVerificationCache._();

  static final Map<int, bool> _enabled = {};

  static bool? get(int placeId) => _enabled[placeId];

  static void set(int placeId, bool? enabled) {
    if (enabled != null) _enabled[placeId] = enabled;
  }
}

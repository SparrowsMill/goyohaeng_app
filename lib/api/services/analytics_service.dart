import '../api_client.dart';

/// `POST /analytics/events` — 사용자 행동 로그 적재(백엔드 2026-09-14 추가).
/// `userId`는 JWT에서 서버가 채우므로 보내지 않는다.
///
/// 반드시 fire-and-forget으로 호출한다 — 화면 최초 진입 시 `initState()`에서
/// 1회만, `await` 하지 않고 실패해도 무시한다. 이 로그 적재가 실패/지연되어도
/// 실제 화면(장소 상세·방문 인증) 표시를 막으면 안 되기 때문이다.
class AnalyticsService {
  AnalyticsService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// [eventType] 예: `PLACE_DETAIL_VIEW`, `VISIT_AUTH_PAGE_ENTER`.
  Future<void> logEvent({required int placeId, required String eventType}) =>
      _client.post('/analytics/events', body: {
        'placeId': placeId,
        'eventType': eventType,
      });
}

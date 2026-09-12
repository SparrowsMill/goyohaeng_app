import '../api_client.dart';
import '../models.dart';

/// `/places*` (frontend-api-spec.md §6). 목록/상세는 인증 불필요,
/// 방문 여부 조회는 JWT 필요.
class PlaceService {
  PlaceService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /places` — 페이지네이션. 목록은 응답의 `items`에서 읽는다(스펙 §6.1).
  Future<PlaceListPage> list({
    int? regionId,
    int? categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get('/places', query: {
      'regionId': regionId,
      'categoryId': categoryId,
      'page': page,
      'limit': limit,
    });
    return PlaceListPage.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/{id}` — 상세(이미지·운영시간·isOpenNow·재료·verification).
  Future<Place> detail(int id) async {
    final res = await _client.get('/places/$id');
    return Place.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/{placeId}/visit-status` — 현재 사용자의 VERIFIED 방문 기록 유무.
  Future<VisitStatus> visitStatus(int placeId) async {
    final res = await _client.get('/places/$placeId/visit-status');
    return VisitStatus.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /places/{id}/trends` — 장소 트렌드 요약 (스펙 §6.4). 데이터 없으면
  /// summaryText/keywords 등이 비어 온다.
  Future<PlaceTrends> trends(int id) async {
    final res = await _client.get('/places/$id/trends');
    return PlaceTrends.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `POST /places/{id}/trends/first-view` — 트렌드 최초 조회 보상 (스펙 §6.5).
  /// 사용자별·장소별 최초 1회만 BASIC 재료 1개 지급.
  Future<TrendFirstViewResult> claimTrendFirstView(int id) async {
    final res = await _client.post('/places/$id/trends/first-view');
    return TrendFirstViewResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `POST /places/{id}/favorite` — 즐겨찾기 추가 (스펙 §6.6).
  Future<FavoriteToggleResult> addFavorite(int id) async {
    final res = await _client.post('/places/$id/favorite');
    return FavoriteToggleResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `DELETE /places/{id}/favorite` — 즐겨찾기 해제 (스펙 §6.7).
  Future<FavoriteToggleResult> removeFavorite(int id) async {
    final res = await _client.delete('/places/$id/favorite');
    return FavoriteToggleResult.fromJson((res as Map).cast<String, dynamic>());
  }
}

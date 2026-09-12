import '../api_client.dart';
import '../models.dart';

/// `/regions*` (frontend-api-spec.md §4). 인증 불필요. PostgreSQL 실데이터.
class RegionService {
  RegionService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<Region>> list() async {
    final res = await _client.get('/regions');
    final rows = res is List ? res : (res is Map ? res['items'] as List? : null);
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => Region.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /regions/{regionId}/spot-counts` — 본인 + 하위 지역 스팟 수.
  Future<RegionSpotCounts> spotCounts(int regionId) async {
    final res = await _client.get('/regions/$regionId/spot-counts');
    return RegionSpotCounts.fromJson((res as Map).cast<String, dynamic>());
  }
}

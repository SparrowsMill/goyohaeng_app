import '../api_client.dart';
import '../models.dart';

/// `/food-histories/{historyId}` (frontend-api-spec.md §11). JWT 인증 필요.
class FoodHistoryService {
  FoodHistoryService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /food-histories/{historyId}` — `historyId`는 `UserFood.id`.
  Future<FoodHistoryDetail> detail(int historyId) async {
    final res = await _client.get('/food-histories/$historyId');
    return FoodHistoryDetail.fromJson(
      (res as Map).cast<String, dynamic>(),
    );
  }
}

import '../api_client.dart';
import '../api_exception.dart';
import '../models.dart';

/// `/foods*` (frontend-api-spec.md §8). 모두 JWT 인증 필요.
/// `canMake` / `ownedQuantity` / `enough`는 로그인 사용자의 현재 보유량 기준.
class FoodService {
  FoodService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /foods` — 음식 목록 + 제작 가능 여부. 응답은 `{ items: [...] }`.
  Future<List<Food>> list() async {
    final res = await _client.get('/foods');
    final rows = res is Map ? res['items'] as List? : (res as List?);
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => Food.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /foods/{id}` — 음식 상세 (기본 정보 + 레시피 + 보유량 + canMake).
  Future<Food> detail(int id) async {
    final res = await _client.get('/foods/$id');
    return Food.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `POST /foods/{id}/make` — 음식 만들기 (재료 차감). 재료 부족 시 400과 함께
  /// `missingIngredients`가 내려오므로 [MakeFoodShortage]로 변환해 던진다.
  Future<MakeFoodResult> make(int id) async {
    try {
      final res = await _client.post('/foods/$id/make');
      return MakeFoodResult.fromJson((res as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      final body = e.body;
      if (body is Map && body['missingIngredients'] is List) {
        throw MakeFoodShortage(
          e.message,
          missing: (body['missingIngredients'] as List)
              .whereType<Map>()
              .map((m) => (
                    ingredientId: (m['ingredientId'] as num?)?.toInt() ?? 0,
                    name: m['name'] as String? ?? '',
                    requiredQuantity:
                        (m['requiredQuantity'] as num?)?.toInt() ?? 0,
                    ownedQuantity: (m['ownedQuantity'] as num?)?.toInt() ?? 0,
                    shortage: (m['shortage'] as num?)?.toInt() ?? 0,
                  ))
              .toList(),
        );
      }
      rethrow;
    }
  }
}

/// `POST /foods/{id}/make` 400 — 보유 재료 부족.
class MakeFoodShortage extends ApiException {
  MakeFoodShortage(super.message, {required this.missing})
      : super(statusCode: 400);

  final List<
      ({
        int ingredientId,
        String name,
        int requiredQuantity,
        int ownedQuantity,
        int shortage,
      })> missing;
}

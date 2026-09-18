import '../api_client.dart';
import '../models.dart';
import '../../data/food_catalog.dart';

/// `/ingredients/{ingredientId}` (frontend-api-spec.md §9). JWT 인증 필요.
class IngredientService {
  IngredientService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /ingredients/{ingredientId}` — 재료 기본 정보 + 보유량 + 사용 음식 +
  /// GAP 기반 획득 방식(`acquisition.dropProbabilities`). 확률은 서버 값을
  /// 그대로 표시하고 프론트에서 계산하지 않는다(스펙 §8.5, §14-14).
  Future<IngredientDetail> detail(int ingredientId) async {
    final res = await _client.get('/ingredients/$ingredientId');
    final json = (res as Map).cast<String, dynamic>();
    return IngredientDetail.fromJson({
      ...json,
      'usedFoods': FoodCatalog.rows(json['usedFoods']),
    });
  }
}

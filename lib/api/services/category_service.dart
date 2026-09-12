import '../api_client.dart';
import '../models.dart';

/// `/categories` (frontend-api-spec.md §5). 인증 불필요.
class CategoryService {
  CategoryService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<Category>> list() async {
    final res = await _client.get('/categories');
    final rows = res is List ? res : (res is Map ? res['items'] as List? : null);
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => Category.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

import '../api_client.dart';
import '../models.dart';

/// `/records*` (frontend-api-spec.md §12) — 발자국 CRUD. 모두 JWT 인증 필요.
class RecordService {
  RecordService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `POST /records` — 발자국 작성. [placeId]/[userFoodId]/[visitVerificationId]는
  /// 모두 선택이며, 서버가 상호 일치 여부를 검증한다(스펙 §12.1).
  /// [date]는 `YYYY-MM-DD`(KST).
  Future<RecordCreateResult> create({
    int? placeId,
    int? userFoodId,
    int? visitVerificationId,
    required String date,
    String? title,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    final res = await _client.post('/records', body: {
      'placeId': ?placeId,
      'userFoodId': ?userFoodId,
      'visitVerificationId': ?visitVerificationId,
      'date': date,
      if (title != null && title.isNotEmpty) 'title': title,
      'body': body,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    });
    return RecordCreateResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /records` — 내 발자국 목록(`PUBLISHED` 상태만, 스펙 §12.2).
  Future<RecordListPage> list({int page = 1, int limit = 20}) async {
    final res = await _client.get('/records', query: {
      'page': page,
      'limit': limit,
    });
    return RecordListPage.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /records/calendar` — 이 달의 기록 있는 날짜/건수(스펙 §12.3).
  Future<RecordCalendar> calendar({required int year, required int month}) async {
    final res = await _client.get('/records/calendar', query: {
      'year': year,
      'month': month,
    });
    return RecordCalendar.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /records/{recordId}` — 발자국 상세.
  Future<RecordDetail> detail(int recordId) async {
    final res = await _client.get('/records/$recordId');
    return RecordDetail.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `PATCH /records/{recordId}` — 발자국 수정. 전달한 필드만 반영된다.
  Future<RecordDetail> update(
    int recordId, {
    String? date,
    String? title,
    String? body,
    List<String>? imageUrls,
  }) async {
    final res = await _client.patch('/records/$recordId', body: {
      'date': ?date,
      'title': ?title,
      'body': ?body,
      'imageUrls': ?imageUrls,
    });
    return RecordDetail.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `DELETE /records/{recordId}` — soft delete(스펙 §12.6).
  Future<void> delete(int recordId) async {
    await _client.delete('/records/$recordId');
  }
}

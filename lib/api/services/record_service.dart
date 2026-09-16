import '../api_client.dart';
import '../models.dart';

/// [RecordService.update]의 `placeId`/`manualPlaceName` 기본값 — "값을 전달하지
/// 않음"(기존 값 유지)을 뜻하는 표시자. 명시적으로 지우려면 `null`을 전달한다
/// (스펙 2026-09-15: PATCH에서 필드 생략 시 유지, 명시적 null이면 해제).
const Object recordFieldUnset = Object();

/// `/records*` (frontend-api-spec.md §12) — 발자국 CRUD. 모두 JWT 인증 필요.
class RecordService {
  RecordService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `POST /records` — 발자국 작성. [placeId]/[manualPlaceName]은 동시에 값을
  /// 가질 수 없다(서버가 검증). [userFoodId]/[visitVerificationId]도 선택이며,
  /// 서버가 상호 일치 여부를 검증한다(스펙 §12.1). [date]는 `YYYY-MM-DD`(KST).
  Future<RecordCreateResult> create({
    int? placeId,
    String? manualPlaceName,
    int? userFoodId,
    int? visitVerificationId,
    required String date,
    String? title,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    final res = await _client.post('/records', body: {
      'placeId': ?placeId,
      'manualPlaceName': ?manualPlaceName,
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
  ///
  /// [placeId]/[manualPlaceName]은 기본값([recordFieldUnset])이면 기존 값을
  /// 유지하고, `null`을 명시적으로 전달하면 해제한다. 둘 중 하나라도 실제
  /// 값으로 전달하면 다른 쪽은 서버에서 함께 해제된다(동시 보유 불가, 스펙
  /// 2026-09-15). 장소가 바뀌거나 해제되면 연결된 방문 인증도 해제되지만
  /// 인증 기록 자체는 유지된다.
  Future<RecordDetail> update(
    int recordId, {
    String? date,
    String? title,
    String? body,
    List<String>? imageUrls,
    Object? placeId = recordFieldUnset,
    Object? manualPlaceName = recordFieldUnset,
  }) async {
    final reqBody = <String, dynamic>{
      'date': ?date,
      'title': ?title,
      'body': ?body,
      'imageUrls': ?imageUrls,
    };
    if (!identical(placeId, recordFieldUnset)) {
      reqBody['placeId'] = placeId as int?;
    }
    if (!identical(manualPlaceName, recordFieldUnset)) {
      reqBody['manualPlaceName'] = manualPlaceName as String?;
    }
    final res = await _client.patch('/records/$recordId', body: reqBody);
    return RecordDetail.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `DELETE /records/{recordId}` — soft delete(스펙 §12.6).
  Future<void> delete(int recordId) async {
    await _client.delete('/records/$recordId');
  }
}

import '../api_client.dart';
import '../models.dart';

/// `/visit-verifications*` (frontend-api-spec.md §7). 모두 JWT 인증 필요.
class VisitVerificationService {
  VisitVerificationService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `POST /visit-verifications` — 세션 생성. 서버가 인증번호/만료시각 발급.
  /// [arrivalOptionMinutes]는 `10` | `30` | `60`.
  Future<VisitVerification> create({
    required int placeId,
    required int arrivalOptionMinutes,
  }) async {
    final res = await _client.post('/visit-verifications', body: {
      'placeId': placeId,
      'arrivalOptionMinutes': arrivalOptionMinutes,
    });
    return VisitVerification.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `GET /visit-verifications/{verificationId}` — 세션 상태 조회.
  /// 만료된 `ISSUED` 세션은 조회 시 `EXPIRED`로 바뀐다.
  ///
  /// > `verificationId`는 placeId가 아니라 생성 응답의 `id`.
  Future<VisitVerification> get(int verificationId) async {
    final res = await _client.get('/visit-verifications/$verificationId');
    return VisitVerification.fromJson((res as Map).cast<String, dynamic>());
  }

  /// `POST /visit-verifications/{verificationId}/verify` — 인증번호 검증 +
  /// (성공 시) `EVERY_VISIT` 재료 지급. 응답은 `VERIFIED` 세션.
  Future<VisitVerification> verify({
    required int verificationId,
    required String verificationCode,
  }) async {
    final res = await _client.post(
      '/visit-verifications/$verificationId/verify',
      body: {'verificationCode': verificationCode},
    );
    return VisitVerification.fromJson((res as Map).cast<String, dynamic>());
  }
}

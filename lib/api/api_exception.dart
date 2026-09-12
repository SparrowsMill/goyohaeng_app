/// API 호출 실패를 나타내는 예외. 화면에서는 [message]를 그대로 사용자에게
/// 보여줄 수 있도록 한국어 메시지로 정규화한다.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});

  /// 사용자에게 보여줄 수 있는 한국어 메시지.
  final String message;

  /// HTTP 상태 코드 (네트워크 오류 등으로 응답이 없으면 `null`).
  final int? statusCode;

  /// 서버가 내려준 원본 응답 본문 (디버깅용).
  final Object? body;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// 얇은 REST 클라이언트 — JSON 직렬화, `Authorization: Bearer` 헤더 부착,
/// 에러를 [ApiException]으로 정규화한다. 화면/서비스는 이 클라이언트를 통해서만
/// 서버와 통신한다 (frontend-api-spec.md §8).
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  http.Client _http = http.Client();

  /// 테스트 전용 — 실제 소켓을 쓰는 기본 [http.Client] 대신 순수 Dart Future만
  /// 쓰는 가짜 클라이언트(예: `MockClient`)로 바꿔치기한다. `flutter_test`의
  /// `HttpOverrides` 기반 자동 스텁은 `testWidgets`의 FakeAsync 존과 타이밍이
  /// 안 맞아 응답이 늦게 도착해 엉뚱한 테스트를 오염시키는 문제가 있었다
  /// (`test/flutter_test_config.dart` 참고).
  @visibleForTesting
  set debugHttpClient(http.Client client) => _http = client;

  /// 로그인 후 발급받은 JWT Access Token. [AuthStore]가 로그인/로그아웃/부팅 시
  /// 갱신한다. `null`이면 인증 헤더 없이 요청한다.
  String? authToken;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final base = Uri.parse('${ApiConfig.baseUrl}/$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        for (final entry in query.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (authToken != null && authToken!.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, {Object? body}) => _send(
        () => _http.post(
          _uri(path),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> patch(String path, {Object? body}) => _send(
        () => _http.patch(
          _uri(path),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> delete(String path, {Object? body}) => _send(
        () => _http.delete(
          _uri(path),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    final http.Response response;
    try {
      response = await run().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw ApiException('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      throw ApiException('네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      _messageFor(response.statusCode, decoded),
      statusCode: response.statusCode,
      body: decoded,
    );
  }

  /// 서버가 내려준 `message`(문자열 또는 문자열 배열)를 우선 사용하고, 없으면
  /// 상태 코드에 맞는 기본 한국어 메시지로 대체한다.
  String _messageFor(int status, dynamic body) {
    if (body is Map && body['message'] != null) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.first.toString();
    }
    return switch (status) {
      400 => '입력값을 다시 확인해 주세요.',
      401 => '로그인이 필요하거나 인증이 만료됐어요.',
      403 => '접근 권한이 없어요.',
      404 => '요청한 정보를 찾을 수 없어요.',
      409 => '이미 사용 중이거나 처리된 요청이에요.',
      >= 500 => '서버에 문제가 발생했어요. 잠시 후 다시 시도해 주세요.',
      _ => '요청을 처리하지 못했어요. (오류 $status)',
    };
  }
}

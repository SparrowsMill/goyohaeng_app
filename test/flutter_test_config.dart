import 'dart:async';

import 'package:goyohaeng_app/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `test/` 전체에 적용되는 전역 훅 (Flutter의 `flutter_test_config.dart`
/// 관례) — 개별 테스트 파일을 하나도 안 건드리고 모든 실제 API 호출을
/// 가짜 HTTP 클라이언트로 돌린다.
///
/// `flutter_test`가 기본 제공하는 `HttpOverrides` 기반 400 스텁은 실제
/// `dart:io` 소켓을 거치는데, 이게 `testWidgets`의 `FakeAsync` 존과 타이밍이
/// 안 맞아서 응답이 원래 요청을 보낸 테스트가 끝난 뒤에 뒤늦게 도착해 다른
/// 테스트를 오염시키거나(비결정적 실패), 결과를 직접 `await`하는 코드에서는
/// 아예 멈춰버리는 문제가 있었다. `MockClient`는 순수 Dart Future만 쓰고
/// 실제 소켓이 없어서 이 문제가 없다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ApiClient.instance.debugHttpClient = MockClient((request) async {
    return http.Response('{"message":"test 환경 — 백엔드 없음"}', 400);
  });
  await testMain();
}

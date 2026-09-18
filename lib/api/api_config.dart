/// 백엔드 REST API 접속 설정 (frontend-api-spec.md §1).
///
/// Base URL은 빌드 시 `--dart-define`으로 주입한다:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000/api/v1
/// ```
///
/// 주입하지 않으면 Railway에 배포된 실제 서버
/// (`https://goyohaengappbackend-production.up.railway.app/api/v1`)를
/// 기본값으로 쓴다. 로컬 서버를 붙일 때는 Android 에뮬레이터에서
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`, iOS
/// 시뮬레이터/웹/데스크톱에서는
/// `--dart-define=API_BASE_URL=http://localhost:3000/api/v1`.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://goyohaengappbackend-production.up.railway.app/api/v1',
  );

  /// 네트워크 요청 타임아웃.
  static const Duration timeout = Duration(seconds: 15);
}

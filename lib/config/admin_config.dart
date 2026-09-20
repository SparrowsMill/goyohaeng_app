/// 관리자 웹(가맹점용 백오피스) 접속 설정.
///
/// 앱은 자체 관리자 화면을 만들지 않고, 이미 배포된 관리자 웹을
/// `AdminWebViewScreen`(웹뷰) 안에서 그대로 띄운다 — 로그인·데이터·API
/// 호출 전부 그 웹사이트가 처리하므로 앱/백엔드 쪽 추가 연동이 없다.
///
/// Base URL은 빌드 시 `--dart-define`으로 주입한다:
///
/// ```sh
/// flutter run --dart-define=ADMIN_WEB_URL=https://your-admin.vercel.app
/// ```
abstract final class AdminConfig {
  static const String baseUrl = String.fromEnvironment(
    'ADMIN_WEB_URL',
    defaultValue: 'https://goyohaeng-admin.vercel.app',
  );

  static const String loginPath = '/login';
}

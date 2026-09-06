/// NAVER Cloud Platform **Mobile Dynamic Map** Client ID (a.k.a. `ncpKeyId`),
/// issued for the Application registered against package / bundle id
/// `com.goyohaeng`.
///
/// This is a client-side key: NCP scopes it by package name, so it is meant to
/// ship inside the app binary. Override per build with
/// `--dart-define=NAVER_MAP_CLIENT_ID=...` (e.g. a separate dev Application).
const String naverMapClientId = String.fromEnvironment(
  'NAVER_MAP_CLIENT_ID',
  defaultValue: 'hpco1eguuv',
);

/// Set to `true` by `main()` once `FlutterNaverMap().init()` has succeeded —
/// only ever happens on Android/iOS. The `<지도>` screen reads this to decide
/// between the real NAVER map and a fallback (desktop/web previews, tests).
bool naverMapInitialized = false;

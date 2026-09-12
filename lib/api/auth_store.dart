import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/favorites.dart';
import 'api_client.dart';
import 'dashboard_store.dart';
import 'models.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';

/// 로그인 세션의 단일 출처. JWT Access Token과 로그인 사용자 정보를
/// `SharedPreferences`에 영속화하고, 변화가 있을 때 리스너에게 알린다.
///
/// 앱 어디서나 `AuthStore.instance`로 접근한다. `ApiClient.instance.authToken`은
/// 이 스토어가 유일하게 관리한다.
class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const _kToken = 'auth.accessToken';
  static const _kUser = 'auth.user';
  static const _kPersist = 'auth.keepSignedIn';

  final AuthService _auth = AuthService();
  final UserService _users = UserService();

  String? _token;
  AuthUser? _user;
  Me? _me;
  bool _keepSignedIn = true;

  String? get token => _token;
  AuthUser? get user => _user;

  /// 마지막으로 조회한 `/users/me` (계정 센터·방앗간에서 재사용).
  Me? get me => _me;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  /// 앱 시작 시 1회 호출. 저장된 토큰이 있으면 복원하고 `/users/me`로 유효성을
  /// 확인한다. 토큰이 만료됐으면 조용히 로그아웃 상태로 둔다.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _keepSignedIn = prefs.getBool(_kPersist) ?? true;
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty || !_keepSignedIn) {
      if (!_keepSignedIn) await _clear(prefs);
      return;
    }

    _token = token;
    ApiClient.instance.authToken = token;
    final rawUser = prefs.getString(_kUser);
    if (rawUser != null) {
      try {
        _user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {
        /* ignore corrupt cache */
      }
    }

    try {
      _me = await _users.getMe();
      _user = AuthUser(
        id: _me!.id,
        username: _me!.username,
        realName: _me!.realName,
      );
      notifyListeners();
      unawaited(Favorites.instance.loadFromServer());
    } catch (_) {
      // 토큰 만료/무효 — 세션 정리.
      await signOut();
    }
  }

  /// `POST /auth/login` 후 세션 저장.
  Future<void> logIn({
    required String username,
    required String password,
    required bool keepSignedIn,
  }) async {
    final result = await _auth.login(username: username, password: password);
    await _apply(result.accessToken, result.user, keepSignedIn: keepSignedIn);
    // 로그인 직후 전체 프로필을 한 번 받아둔다(있으면).
    try {
      _me = await _users.getMe();
    } catch (_) {
      /* 프로필은 계정 센터 진입 시 다시 시도 */
    }
    notifyListeners();
    unawaited(Favorites.instance.loadFromServer());
  }

  Future<void> _apply(
    String token,
    AuthUser user, {
    required bool keepSignedIn,
  }) async {
    _token = token;
    _user = user;
    _keepSignedIn = keepSignedIn;
    ApiClient.instance.authToken = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPersist, keepSignedIn);
    if (keepSignedIn) {
      await prefs.setString(_kToken, token);
      await prefs.setString(_kUser, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_kToken);
      await prefs.remove(_kUser);
    }
  }

  /// 계정 센터에서 `/users/me`를 갱신했을 때 캐시를 최신화.
  void updateMe(Me me) {
    _me = me;
    _user = AuthUser(id: me.id, username: me.username, realName: me.realName);
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _user = null;
    _me = null;
    ApiClient.instance.authToken = null;
    DashboardStore.instance.clear();
    Favorites.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    notifyListeners();
  }

  /// 테스트 전용 — 실제 `POST /auth/login` 없이 즉시 로그인 상태로 만든다
  /// (기기 저장은 건드리지 않음). `ApiClient.instance.debugHttpClient`를
  /// 가짜 클라이언트로 바꿔치기한 테스트에서, 로그인된 화면의 실제 동작을
  /// 검증할 때 쓴다.
  @visibleForTesting
  void debugSignIn({
    int id = 1,
    String username = 'tester',
    String realName = '테스터',
  }) {
    _token = 'debug-token';
    _user = AuthUser(id: id, username: username, realName: realName);
    ApiClient.instance.authToken = _token;
    notifyListeners();
  }

  /// 테스트 전용 — [debugSignIn]으로 만든 상태를 되돌린다.
  @visibleForTesting
  void debugSignOut() {
    _token = null;
    _user = null;
    _me = null;
    ApiClient.instance.authToken = null;
    notifyListeners();
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}

import 'package:flutter/foundation.dart';

import 'api_exception.dart';
import 'models.dart';
import 'services/user_service.dart';

/// `GET /users/me/dashboard` (스펙 §3.6) 캐시. 방앗간 홈 스탯바·방문 TOP·참새
/// 활동 요약이 공유해서 읽는다. 방문 인증/음식 만들기 등 수치가 바뀌는 동작
/// 뒤에 [refresh]를 호출하면 모든 구독 화면이 함께 갱신된다.
class DashboardStore extends ChangeNotifier {
  DashboardStore._();

  static final DashboardStore instance = DashboardStore._();

  final UserService _users = UserService();

  Dashboard? _data;
  bool _loading = false;
  String? _error;

  Dashboard? get data => _data;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _data != null;

  /// 이미 한 번 받아왔으면 재요청하지 않는다(화면 재진입 시 캐시 사용).
  Future<void> ensureLoaded() {
    if (_data != null || _loading) return Future.value();
    return refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _users.getDashboard();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 로그아웃 시 캐시 비우기.
  void clear() {
    _data = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}

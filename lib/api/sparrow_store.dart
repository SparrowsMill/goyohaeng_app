import 'package:flutter/foundation.dart';

import 'api_exception.dart';
import 'models.dart';
import 'services/user_service.dart';

/// `GET /users/me/sparrow` 캐시. 방앗간 홈의 참새 레벨 카드 + 마이 페이지
/// 프로필 카드가 공유해서 읽는다. XP 획득 조건이 아직 확정되지 않아(스펙에
/// 트리거가 명시되지 않음) 화면 재진입 시마다 새로 받기보다 [ensureLoaded]로
/// 캐시해 두고, 필요해지면 다른 스토어처럼 특정 액션 뒤에 [refresh]를 호출하는
/// 식으로 확장한다.
class SparrowStore extends ChangeNotifier {
  SparrowStore._();

  static final SparrowStore instance = SparrowStore._();

  final UserService _users = UserService();

  Sparrow? _data;
  bool _loading = false;
  String? _error;

  Sparrow? get data => _data;
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
      _data = await _users.getSparrow();
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

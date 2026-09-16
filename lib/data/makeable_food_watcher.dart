import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'food_catalog.dart';

/// 재료를 새로 얻을 때마다(방문 인증 보상, 트렌드 요약 최초 확인 보상 등) 호출해
/// 그 결과로 새로 "제작 가능"해진 음식이 있는지 확인한다. 앱 전역 상단 배너
/// (`MakeableFoodBanner`, `lib/widgets/makeable_food_banner.dart`)가 이 상태를
/// 구독해 알려준다.
///
/// 최초 호출(로그인 직후 등)은 기준선만 세우고 배너를 띄우지 않는다 — 이미
/// 예전부터 제작 가능했던 음식까지 "새로 만들 수 있어요"라고 알리면 안 되기
/// 때문이다. 그 이후 호출부터 직전 기준과 비교해 새로 추가된 음식만 알린다.
class MakeableFoodWatcher extends ChangeNotifier {
  MakeableFoodWatcher._();
  static final MakeableFoodWatcher instance = MakeableFoodWatcher._();

  Set<int> _knownMakeableIds = {};
  bool _seeded = false;
  List<Food> _pending = const [];

  List<Food> get pending => _pending;

  /// 배너를 닫거나 "재료 가방 바로가기"로 이동했을 때 호출.
  void dismiss() {
    if (_pending.isEmpty) return;
    _pending = const [];
    notifyListeners();
  }

  /// 로그아웃 시 호출 — 다음 로그인이 이전 계정의 기준선을 이어받지 않게 한다.
  void reset() {
    _seeded = false;
    _knownMakeableIds = {};
    dismiss();
  }

  /// 재료 획득 이벤트 직후 호출. 실패해도(네트워크 오류 등) 조용히 무시한다 —
  /// 배너는 있으면 좋은 부가 안내일 뿐이라 다음 획득 이벤트에서 다시 시도되면
  /// 충분하다.
  Future<void> check() async {
    if (!AuthStore.instance.isSignedIn) return;
    try {
      final foods = await FoodService().list();
      final makeableIds = foods
          .where((f) => f.canMake && FoodCatalog.isOpen(f.name))
          .map((f) => f.id)
          .toSet();

      if (!_seeded) {
        _seeded = true;
        _knownMakeableIds = makeableIds;
        return;
      }

      final newlyIds = makeableIds.difference(_knownMakeableIds);
      _knownMakeableIds = makeableIds;
      if (newlyIds.isEmpty) return;

      _pending = foods.where((f) => newlyIds.contains(f.id)).toList();
      notifyListeners();
    } on ApiException {
      // 다음 재료 획득 이벤트에서 다시 확인하면 된다.
    }
  }
}

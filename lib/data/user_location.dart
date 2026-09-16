import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// 고요행은 위치정보를 수집하지 않는다 — [position]은 항상 `null`로 고정.
/// 지도 위젯들은 원래 GPS 픽스가 늦게 도착하는 동안의 "아직 모름" 상태를
/// 그리도록 만들어져 있어서, 이 상태를 폴백이 아니라 유일한 상태로 그대로
/// 쓴다 (전체 반도 fit / "내 위치" 버튼·점 숨김).
class UserLocation {
  UserLocation._();

  static final ValueNotifier<LatLng?> position = ValueNotifier<LatLng?>(null);

  /// No-op — 위치를 요청하지 않으므로 [position]은 절대 채워지지 않는다.
  /// 호출부를 건드리지 않기 위해 시그니처만 유지.
  static Future<void> ensure() async {}

  @visibleForTesting
  static void resetForTest() {
    position.value = null;
  }
}

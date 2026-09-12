import 'package:flutter/foundation.dart';

// `../api/api.dart` 배럴은 안 쓴다 — `AuthStore`가 로그인/로그아웃 시 이
// 파일을 부르는데, 배럴은 `auth_store.dart`를 다시 export해서 순환 참조가
// 생긴다. 필요한 서비스만 직접 import.
import '../api/api_exception.dart';
import '../api/services/user_service.dart';
import 'mock_region_ranking.dart';

const _seedFavorites = {'담양 죽녹원', '전주 경기전', '보성 녹차밭'};

/// 즐겨찾기 store, keyed by spot name (실 장소도 GAP 스팟 변환 시 이름을
/// 그대로 쓰므로 — `gapPlaceToSpot` — 이름 키 그대로 재사용된다). [_seedFavorites]는
/// 로그인 전/네트워크 실패 시에만 남는 임시값이고, [loadFromServer]가 성공하면
/// `GET /users/me/favorites`의 실제 목록으로 통째로 교체된다(`AuthStore`가
/// 부팅·로그인 시 호출).
///
/// * TODO: 별표 지도 오버레이(`spots`/`locatedSpots`)는 여전히
///   `mockRegionRankings`에서만 이름을 찾아서, 실 GAP 스팟은 즐겨찾기해도
///   지도 위 별 핀으로는 안 뜬다 — 별도 작업 필요.
class Favorites extends ChangeNotifier {
  Favorites._();

  /// The one app-wide store. `ChangeNotifier` so the star buttons, the ranking
  /// list, and both maps refresh together.
  static final Favorites instance = Favorites._();

  // Seeded so the feature has something to show on first run.
  final Set<String> _names = {..._seedFavorites};

  /// Whether the "즐겨찾기" map overlay (star pins) is toggled on. Shared across
  /// the whole 지도 flow so it survives the 도/시/군/구 벡터 지도 ↔ 실제 타일 지도
  /// 전환: turn it on at any stage and it stays on when you drill in or step back.
  final ValueNotifier<bool> mapOverlayActive = ValueNotifier<bool>(false);

  /// Restore the seeded set — for test isolation only.
  @visibleForTesting
  void resetToSeed() {
    _names
      ..clear()
      ..addAll(_seedFavorites);
    mapOverlayActive.value = false;
    notifyListeners();
  }

  /// `GET /users/me/favorites`를 전부 페이지네이션해 받아와 [_names]를 서버
  /// 상태로 통째로 교체한다. `AuthStore`가 부팅(세션 복원) 성공 시와 로그인
  /// 직후에 호출 — 인증 필요 API라 실패(미로그인·네트워크 오류)하면 조용히
  /// 현재 상태(시드 또는 이전 세션 값)를 유지한다.
  Future<void> loadFromServer() async {
    try {
      final names = <String>{};
      var page = 1;
      while (true) {
        final result =
            await UserService().getFavorites(page: page, limit: 100);
        names.addAll(result.items.map((f) => f.name));
        if (!result.hasMore) break;
        page++;
      }
      _names
        ..clear()
        ..addAll(names);
      notifyListeners();
    } on ApiException {
      // 로그인 전이거나 네트워크 오류 — 현재 상태 유지.
    }
  }

  /// 로그아웃 시 — 다음 사용자에게 이전 사용자의 즐겨찾기가 보이지 않도록.
  void clear() {
    _names.clear();
    mapOverlayActive.value = false;
    notifyListeners();
  }

  bool contains(String name) => _names.contains(name);
  int get count => _names.length;
  Set<String> get names => Set.unmodifiable(_names);

  /// Add if absent, remove if present.
  void toggle(String name) {
    if (!_names.remove(name)) _names.add(name);
    notifyListeners();
  }

  /// Every favorited mock spot, with the 행정구역 코드 of the list it lives in.
  List<({String regionCode, MockTouristSpot spot})> spots() => [
        for (final entry in mockRegionRankings.entries)
          for (final spot in entry.value)
            if (_names.contains(spot.name))
              (regionCode: entry.key, spot: spot),
      ];

  /// …only the ones with coordinates (map markers).
  List<({String regionCode, MockTouristSpot spot})> locatedSpots() =>
      [for (final f in spots()) if (f.spot.hasLocation) f];

  /// How many favorites fall under a 행정구역 코드 (2자리 시도 or 5자리 시군구).
  int countForRegion(String regionCode) =>
      spots().where((f) => f.regionCode.startsWith(regionCode)).length;
}

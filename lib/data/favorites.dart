import 'package:flutter/foundation.dart';

import 'mock_region_ranking.dart';

const _seedFavorites = {'담양 죽녹원', '전주 경기전', '보성 녹차밭'};

/// Session-scoped 즐겨찾기 store, keyed by spot name (mock 데이터의 이름은
/// 고유하다). 앱을 다시 켜면 초기화 — 백엔드 연동 전 임시 저장소.
///
/// * TODO(backend): 즐겨찾기 API + 영속화 (기기 저장 / 계정 동기화)
class Favorites extends ChangeNotifier {
  Favorites._();

  /// The one app-wide store. `ChangeNotifier` so the star buttons, the ranking
  /// list, and both maps refresh together.
  static final Favorites instance = Favorites._();

  // Seeded so the feature has something to show on first run.
  final Set<String> _names = {..._seedFavorites};

  /// Restore the seeded set — for test isolation only.
  @visibleForTesting
  void resetToSeed() {
    _names
      ..clear()
      ..addAll(_seedFavorites);
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

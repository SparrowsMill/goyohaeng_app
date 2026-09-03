/// Placeholder "비슷한 분위기의 주변 장소" data for `<방문 불가>` (user_flow §6).
///
/// Since mock spots carry no coordinates, distance labels are assigned by
/// rank here. The pool is the origin spot's own region, filtered to places
/// that can currently be visited, ordered so shared trend keywords come
/// first.
///
/// * TODO(backend): 위치 기반 주변 유사 장소 추천 API 연동
library;

import 'mock_region_ranking.dart';

class NearbySpotSuggestion {
  const NearbySpotSuggestion({required this.spot, required this.distanceLabel});

  final MockTouristSpot spot;
  final String distanceLabel;
}

const _distanceLabels = ['약 1.2km', '약 2.0km', '약 3.4km', '약 5.1km'];

List<NearbySpotSuggestion> nearbySuggestionsForSpot(MockTouristSpot origin) {
  final regionKey = regionKeyForSpot(origin);
  final pool = (regionKey == null ? const <MockTouristSpot>[] : rankingForRegion(regionKey))
      .where((s) =>
          s.name != origin.name &&
          s.visitVerifiable &&
          s.businessStatus != BusinessStatus.holiday)
      .toList();

  int sharedKeywords(MockTouristSpot s) =>
      s.trendKeywords.where(origin.trendKeywords.contains).length;

  pool.sort((a, b) {
    final byShared = sharedKeywords(b).compareTo(sharedKeywords(a));
    if (byShared != 0) return byShared;
    return b.gapIndex.compareTo(a.gapIndex);
  });

  final top = pool.take(_distanceLabels.length).toList();
  return [
    for (var i = 0; i < top.length; i++)
      NearbySpotSuggestion(spot: top[i], distanceLabel: _distanceLabels[i]),
  ];
}

import 'mock_region_ranking.dart';

/// Names of the mock 관광 스팟 the signed-in user has already visited
/// (방문 인증 완료). Placeholder until a real visit history exists.
///
/// * TODO(backend): 방문 기록 API 연동
const _visitedNames = {
  '전주 경기전',
  '담양 죽녹원',
  '순천만 국가정원',
  '여수 해상케이블카',
  '군산 초원사진관',
};

/// The user's already-visited spots (mock), in [mockRegionRankings] order.
List<MockTouristSpot> get mockVisitedSpots => [
      for (final list in mockRegionRankings.values)
        for (final spot in list)
          if (_visitedNames.contains(spot.name)) spot,
    ];

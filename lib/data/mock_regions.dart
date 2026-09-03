/// Korean display name for each region symbol in
/// `assets/illustrations/map/mill_list/`, keyed by the asset's filename stem
/// (the part after `mill_` and before `.png`) — e.g. `seoul` -> `서울`,
/// `gyeongsang_s` -> `경상남도`.
const regionDisplayNames = {
  'seoul': '서울',
  'gyeonggi': '경기도',
  'gangwon': '강원도',
  'chungcheong_n': '충청북도',
  'chungcheong_s': '충청남도',
  'Jeolla_n': '전라북도',
  'Jeolla_s': '전라남도',
  'gyeongsang_n': '경상북도',
  'gyeongsang_s': '경상남도',
  'jeju': '제주도',
};

/// Placeholder per-region mill visit progress until a real backend exists.
class MockRegionProgress {
  const MockRegionProgress({
    required this.regionKey,
    required this.visited,
    required this.total,
  });

  /// Matches a key in [regionDisplayNames] and the `mill_<regionKey>.png`
  /// asset filename.
  final String regionKey;
  final int visited;
  final int total;

  double get ratio => visited / total;
  String get displayName => regionDisplayNames[regionKey] ?? regionKey;
  String get assetPath => 'assets/illustrations/map/mill_list/mill_$regionKey.png';
}

final mockRegionProgress = <MockRegionProgress>[
  const MockRegionProgress(regionKey: 'seoul', visited: 3, total: 5),
  const MockRegionProgress(regionKey: 'gyeonggi', visited: 2, total: 6),
  const MockRegionProgress(regionKey: 'gangwon', visited: 1, total: 5),
  const MockRegionProgress(regionKey: 'chungcheong_n', visited: 1, total: 4),
  const MockRegionProgress(regionKey: 'chungcheong_s', visited: 2, total: 5),
  const MockRegionProgress(regionKey: 'Jeolla_n', visited: 3, total: 8),
  const MockRegionProgress(regionKey: 'Jeolla_s', visited: 1, total: 6),
  const MockRegionProgress(regionKey: 'gyeongsang_n', visited: 1, total: 6),
  const MockRegionProgress(regionKey: 'gyeongsang_s', visited: 4, total: 7),
  const MockRegionProgress(regionKey: 'jeju', visited: 2, total: 3),
];

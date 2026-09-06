/// 이미 방문한 스팟 / 전체 관광스팟, 도(시도) 단위 — placeholder until a real
/// visit history exists.
///
/// * TODO(backend): 방문 기록 API 연동 (지역별 방문/전체 스팟 수)
class RegionVisitStat {
  const RegionVisitStat({
    required this.name,
    required this.visited,
    required this.total,
  });

  final String name;
  final int visited;
  final int total;

  double get ratio => total == 0 ? 0 : visited / total;
}

const _regionVisits = <RegionVisitStat>[
  RegionVisitStat(name: '경상남도', visited: 4, total: 7),
  RegionVisitStat(name: '전라북도', visited: 3, total: 8),
  RegionVisitStat(name: '서울', visited: 3, total: 5),
  RegionVisitStat(name: '경기도', visited: 2, total: 6),
  RegionVisitStat(name: '충청남도', visited: 2, total: 5),
  RegionVisitStat(name: '제주도', visited: 2, total: 3),
  RegionVisitStat(name: '전라남도', visited: 1, total: 6),
  RegionVisitStat(name: '강원도', visited: 1, total: 5),
  RegionVisitStat(name: '충청북도', visited: 1, total: 4),
  RegionVisitStat(name: '경상북도', visited: 1, total: 6),
];

/// The 3 도 with the most visited 관광 스팟, most first.
List<RegionVisitStat> get topVisitedRegions => ([..._regionVisits]
      ..sort((a, b) => b.visited.compareTo(a.visited)))
    .take(3)
    .toList();

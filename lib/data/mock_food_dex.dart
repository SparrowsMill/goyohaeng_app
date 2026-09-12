/// 음식 도감 placeholder 데이터 — user_flow §4. 만든 음식 + 만들 수 있는 음식 +
/// 아직 못 만든 음식을 도감 형태로 보여준다. 실제 도감 백엔드 전까지 쓰는 mock.
///
/// * TODO(backend): 음식 도감 조회 API 연동 — 음식별 상태(제작 완료 / 곧 제작 가능
///   / 미제작)·지역·일러스트. `mock_foods` / `mock_ingredients` 목록과 결국
///   하나의 음식 마스터로 합쳐질 값들 (지금은 화면별로 나뉜 임시 데이터).
/// * TODO(asset): 음식별 일러스트 `assets/illustrations/food/food_{slug}.png`
///   미납품 — 그 전까지 `_DexFoodCard` 가 errorBuilder 로 접시 아이콘 placeholder.
library;

enum DexFoodState {
  /// 이미 만든 음식 — 일러스트 + 이름, 탭 시 `<음식 히스토리>`.
  made,

  /// 곧 만들 수 있는 음식 — 재료가 거의 모였음.
  almost,

  /// 아직 만들지 못한 음식 — 실루엣 + 이름, 탭 시 `<음식 정보>`.
  locked,
}

class DexFood {
  const DexFood({
    required this.name,
    required this.slug,
    required this.region,
    required this.state,
  });

  final String name;
  final String slug;

  /// 음식의 대표 지역(도감 지역별 보기 그룹 키).
  final String region;
  final DexFoodState state;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

/// 지역별 보기 필터 칩에 쓰는 지역 순서.
const mockDexRegions = <String>['전주', '강릉', '경주'];

const mockFoodDex = <DexFood>[
  // 전주
  DexFood(name: '전주비빔밥', slug: 'jeonju_bibimbap', region: '전주', state: DexFoodState.made),
  DexFood(name: '마늘볶음밥', slug: 'maneul_bokkeumbap', region: '전주', state: DexFoodState.almost),
  DexFood(name: '콩나물국밥', slug: 'kongnamul_gukbap', region: '전주', state: DexFoodState.made),
  DexFood(name: '황태해장국', slug: 'hwangtae_haejangguk', region: '전주', state: DexFoodState.locked),
  // 강릉
  DexFood(name: '들깨수제비', slug: 'deulkkae_sujebi', region: '강릉', state: DexFoodState.made),
  DexFood(name: '초당순두부', slug: 'chodang_sundubu', region: '강릉', state: DexFoodState.locked),
  // 경주
  DexFood(name: '감자옹심이', slug: 'gamja_ongsimi', region: '경주', state: DexFoodState.locked),
  DexFood(name: '찰보리빵', slug: 'chalbori_ppang', region: '경주', state: DexFoodState.locked),
];

/// 지역 → 해당 지역 음식 목록 (mockFoodDex 등장 순서 유지).
List<DexFood> dexFoodsByRegion(String region) =>
    mockFoodDex.where((f) => f.region == region).toList();

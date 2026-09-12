/// 재료 가방 placeholder 데이터 — user_flow §5. 실제 재료/인벤토리 백엔드가
/// 생기기 전까지 쓰는 mock. 화면은 여기서 읽어와 값을 하드코딩하지 않는다.
///
/// * TODO(backend): 보유 재료 목록 조회 API 연동 (재료명·보유 개수·기본/지역별 구분).
/// * TODO(backend): 모은 재료 총 개수 조회.
/// * TODO(backend): 보유 재료로 만들 수 있는 음식 추천 API 연동
///   (완성 가능 / 조금 부족 상태 포함).
/// * TODO(backend): 음식별 필요 재료(레시피) 및 재료 전체 도감 목록도 백엔드에서
///   조회 — 여기 하드코딩된 재료/음식 목록은 전부 임시. `MakeStatus` 판정도
///   서버가 내려주거나 (레시피 필요량 vs 보유량)으로 계산.
/// * TODO(backend): 재료 상세(재료 특성·풍미·특산 지역·사용되는 음식·획득 가능
///   장소) 조회 API 연동 — 지금은 `들깨`만 예시로 채워져 있고 나머지는 비어 있음.
/// * TODO(asset): 재료별 일러스트 대부분 미납품 —
///   `assets/illustrations/rewards/ingredient_{slug}.png` (§6 watercolor,
///   §9 네이밍 규칙). 그 전까지 `_IngredientTile` 이 errorBuilder 로 범용
///   재료 아이콘 placeholder 를 그린다.
library;

enum IngredientCategory { basic, regional }

/// 재료를 얻을 수 있는 장소의 종류 — 아이콘 매핑용.
enum IngredientSourceType { market, shop, millReward }

/// 재료 상세의 "사용되는 음식" 항목.
class IngredientFood {
  const IngredientFood({required this.name, required this.slug});

  final String name;
  final String slug;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

/// 재료 상세의 "획득 가능한 장소" 항목.
class IngredientSource {
  const IngredientSource({required this.name, required this.type});

  final String name;
  final IngredientSourceType type;
}

class MockIngredient {
  const MockIngredient({
    required this.name,
    required this.slug,
    required this.count,
    required this.category,
    this.flavor,
    this.specialtyRegion,
    this.usedInFoods = const [],
    this.sources = const [],
  });

  final String name;
  final String slug;
  final int count;
  final IngredientCategory category;

  /// 재료 특성 한 줄(예: "고소한 풍미"). 없으면 특성 카드에서 생략.
  final String? flavor;

  /// 지역 특산 재료의 산지(예: "제주"). null 이면 특산 재료 아님.
  final String? specialtyRegion;

  final List<IngredientFood> usedInFoods;
  final List<IngredientSource> sources;

  bool get owned => count > 0;
  bool get isRegionalSpecialty => specialtyRegion != null;

  String get illustrationPath =>
      'assets/illustrations/rewards/ingredient_$slug.png';
}

/// 모은 재료 총 개수 — 목록 합계와 별개(도감 진행도처럼 별도 집계).
const mockCollectedIngredientCount = 27;

const mockIngredients = <MockIngredient>[
  // 기본 재료
  MockIngredient(name: '쌀', slug: 'rice', count: 3, category: IngredientCategory.basic, flavor: '든든한 곡물의 단맛'),
  MockIngredient(
    name: '들깨',
    slug: 'perilla',
    count: 2,
    category: IngredientCategory.basic,
    flavor: '고소한 풍미',
    usedInFoods: [
      IngredientFood(name: '들깨수제비', slug: 'deulkkae_sujebi'),
      IngredientFood(name: '들깨칼국수', slug: 'deulkkae_kalguksu'),
      IngredientFood(name: '들깨죽', slug: 'deulkkae_juk'),
      IngredientFood(name: '들깨미역국', slug: 'deulkkae_miyeokguk'),
    ],
    sources: [
      IngredientSource(name: '전주 남부시장', type: IngredientSourceType.market),
      IngredientSource(name: '전통 식재료 상점', type: IngredientSourceType.shop),
      IngredientSource(name: '방앗간 보상', type: IngredientSourceType.millReward),
    ],
  ),
  MockIngredient(name: '고추장', slug: 'gochujang', count: 1, category: IngredientCategory.basic, flavor: '칼칼하고 감칠맛 나는 장'),
  MockIngredient(name: '참기름', slug: 'sesame_oil', count: 1, category: IngredientCategory.basic, flavor: '진한 고소함'),
  MockIngredient(name: '콩나물', slug: 'beansprout', count: 4, category: IngredientCategory.basic, flavor: '아삭한 식감'),
  MockIngredient(name: '마늘', slug: 'garlic', count: 5, category: IngredientCategory.basic, flavor: '알싸한 향'),
  MockIngredient(name: '고춧가루', slug: 'chili_powder', count: 1, category: IngredientCategory.basic, flavor: '매콤한 감칠맛'),
  MockIngredient(name: '간장', slug: 'soy_sauce', count: 1, category: IngredientCategory.basic, flavor: '짭조름한 감칠맛'),
  MockIngredient(name: '두부', slug: 'tofu', count: 0, category: IngredientCategory.basic, flavor: '부드럽고 담백함'),
  MockIngredient(name: '애호박', slug: 'zucchini', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '버섯', slug: 'mushroom', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '당근', slug: 'carrot', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '달걀', slug: 'egg', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '파', slug: 'green_onion', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '양파', slug: 'onion', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '멸치', slug: 'anchovy', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '소금', slug: 'salt', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '감자', slug: 'potato', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '깨소금', slug: 'sesame_salt', count: 0, category: IngredientCategory.basic),
  MockIngredient(name: '무', slug: 'radish', count: 0, category: IngredientCategory.basic),
  // 지역별 재료
  MockIngredient(
    name: '녹차잎',
    slug: 'greentea',
    count: 2,
    category: IngredientCategory.regional,
    flavor: '은은한 쓴맛과 향',
    specialtyRegion: '보성',
  ),
  MockIngredient(
    name: '대나무잎',
    slug: 'bamboo',
    count: 1,
    category: IngredientCategory.regional,
    flavor: '맑고 청량한 향',
    specialtyRegion: '담양',
  ),
  MockIngredient(name: '한라봉', slug: 'hallabong', count: 0, category: IngredientCategory.regional, flavor: '새콤달콤한 과즙', specialtyRegion: '제주'),
  MockIngredient(name: '흑돼지', slug: 'black_pork', count: 0, category: IngredientCategory.regional, flavor: '쫄깃하고 고소한 육향', specialtyRegion: '제주'),
];

List<MockIngredient> ingredientsByCategory(IngredientCategory category) =>
    mockIngredients.where((i) => i.category == category).toList();

/// 보유 재료로 만들 수 있는 음식의 완성 가능도.
enum MakeStatus {
  /// 보유 재료만으로 바로 만들 수 있음.
  ready,

  /// 재료가 조금 부족 — 보충하면 만들 수 있음.
  almost,
}

class MockMakeableFood {
  const MockMakeableFood({
    required this.name,
    required this.slug,
    required this.status,
  });

  final String name;
  final String slug;
  final MakeStatus status;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

const mockMakeableFoods = <MockMakeableFood>[
  MockMakeableFood(name: '들깨수제비', slug: 'deulkkae_sujebi', status: MakeStatus.ready),
  MockMakeableFood(name: '전주비빔밥', slug: 'jeonju_bibimbap', status: MakeStatus.ready),
  MockMakeableFood(name: '콩나물무침', slug: 'kongnamul_muchim', status: MakeStatus.ready),
  MockMakeableFood(name: '마늘볶음밥', slug: 'maneul_bokkeumbap', status: MakeStatus.almost),
];

/// 요약 카드의 "추천: OO" — 바로 만들 수 있는 음식 중 첫 번째.
MockMakeableFood? get recommendedMakeableFood {
  for (final food in mockMakeableFoods) {
    if (food.status == MakeStatus.ready) return food;
  }
  return null;
}

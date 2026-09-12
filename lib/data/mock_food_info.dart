/// 음식 정보 placeholder 데이터 — user_flow §4. 아직 만들지 못한 음식을 눌렀을
/// 때 보여주는 필요 재료(보유/필요 수량) + 부족한 재료 획득 장소.
///
/// * TODO(backend): 음식 레시피 조회 API 연동 — 필요 재료별 필요 수량, 사용자
///   보유 수량, 부족한 재료의 획득 가능 장소. 보유 수량은 `mock_ingredients` 와
///   결국 같은 인벤토리에서 와야 함 (지금은 값이 대략만 맞음).
/// * TODO: "만들기" → `<셰프의 주방>` (제작 애니메이션 + 완성 일러스트) 미구현.
/// * TODO(asset): 재료 일러스트 `assets/illustrations/rewards/ingredient_{slug}.png`,
///   장소 썸네일 `assets/illustrations/map/map_{slug}.png` 미납품 — placeholder 아이콘.
library;

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.slug,
    required this.owned,
    required this.required,
  });

  final String name;
  final String slug;
  final int owned;
  final int required;

  bool get satisfied => owned >= required;

  String get illustrationPath =>
      'assets/illustrations/rewards/ingredient_$slug.png';
}

/// 부족한 재료를 얻을 수 있는 장소 추천.
class IngredientPlace {
  const IngredientPlace({
    required this.ingredientName,
    required this.ingredientSlug,
    required this.placeName,
    required this.description,
    required this.slug,
  });

  final String ingredientName;
  final String ingredientSlug;
  final String placeName;
  final String description;

  /// 썸네일 / 재료 미니 아이콘 경로 키.
  final String slug;

  String get thumbnailPath => 'assets/illustrations/map/map_$slug.png';
  String get ingredientIconPath =>
      'assets/illustrations/rewards/ingredient_$ingredientSlug.png';
}

/// 셰프의 주방 완성 화면의 "특별 재료" 항목 — 재료 또는 "OO 로컬 재료" 같은
/// 카테고리 한 줄 소개.
class SpecialNote {
  const SpecialNote({required this.name, required this.slug, required this.note});

  final String name;

  /// `ingredient_{slug}.png` 아이콘 키. 카테고리성 항목이면 대표 재료 slug.
  final String slug;
  final String note;

  String get illustrationPath =>
      'assets/illustrations/rewards/ingredient_$slug.png';
}

class FoodInfo {
  const FoodInfo({
    required this.slug,
    required this.name,
    required this.description,
    required this.ingredients,
    this.places = const [],
    this.completedDescription,
    this.specialNotes = const [],
  });

  final String slug;
  final String name;
  final String description;
  final List<RecipeIngredient> ingredients;
  final List<IngredientPlace> places;

  /// 완성 화면용 문구. 없으면 [description] 을 그대로 쓴다.
  final String? completedDescription;

  /// 완성 화면의 "특별 재료" 카드들.
  final List<SpecialNote> specialNotes;

  int get ownedCount => ingredients.where((i) => i.satisfied).length;
  int get totalCount => ingredients.length;
  int get missingCount => totalCount - ownedCount;
  bool get canMake => missingCount == 0;

  String get completedText => completedDescription ?? description;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

const _infos = <FoodInfo>[
  FoodInfo(
    slug: 'deulkkae_sujebi',
    name: '들깨수제비',
    description: '고소한 들깨 국물에 쫀득한 수제비가 어우러진 따뜻한 한 그릇 요리예요.',
    completedDescription: '고소한 들깨 향이 가득한 따뜻한 한 그릇이 완성되었어요.',
    specialNotes: [
      SpecialNote(
        name: '들깨',
        slug: 'perilla',
        note: '고소함을 더해주는 국내산 들깨',
      ),
      SpecialNote(
        name: '전주 로컬 재료',
        slug: 'potato',
        note: '전주의 신선한 제철 로컬 농산물',
      ),
    ],
    ingredients: [
      RecipeIngredient(name: '들깨', slug: 'perilla', owned: 2, required: 2),
      RecipeIngredient(name: '감자', slug: 'potato', owned: 0, required: 2),
      RecipeIngredient(name: '애호박', slug: 'zucchini', owned: 0, required: 1),
      RecipeIngredient(name: '마늘', slug: 'garlic', owned: 1, required: 1),
      RecipeIngredient(name: '양파', slug: 'onion', owned: 1, required: 1),
      RecipeIngredient(name: '소금', slug: 'salt', owned: 1, required: 1),
    ],
    places: [
      IngredientPlace(
        ingredientName: '감자',
        ingredientSlug: 'potato',
        placeName: '전주 남부시장',
        description: '싱싱한 감자를 만날 수 있는 전통시장이에요.',
        slug: 'nambu_market',
      ),
      IngredientPlace(
        ingredientName: '애호박',
        ingredientSlug: 'zucchini',
        placeName: '완주 로컬푸드 직매장',
        description: '지역 농가의 신선함을 바로 구매할 수 있어요.',
        slug: 'wanju_localfood',
      ),
    ],
  ),
  FoodInfo(
    slug: 'hwangtae_haejangguk',
    name: '황태해장국',
    description: '푹 우려낸 황태 국물이 속을 시원하게 풀어 주는 해장 음식이에요.',
    ingredients: [
      RecipeIngredient(name: '콩나물', slug: 'beansprout', owned: 4, required: 2),
      RecipeIngredient(name: '황태', slug: 'pollack', owned: 0, required: 1),
      RecipeIngredient(name: '무', slug: 'radish', owned: 0, required: 1),
      RecipeIngredient(name: '계란', slug: 'egg', owned: 0, required: 2),
      RecipeIngredient(name: '파', slug: 'green_onion', owned: 0, required: 1),
    ],
    places: [
      IngredientPlace(
        ingredientName: '황태',
        ingredientSlug: 'pollack',
        placeName: '대관령 황태덕장',
        description: '겨우내 얼고 마르기를 반복한 황태를 구할 수 있어요.',
        slug: 'daegwallyeong_hwangtae',
      ),
      IngredientPlace(
        ingredientName: '무',
        ingredientSlug: 'radish',
        placeName: '전주 남부시장',
        description: '단단하고 물오른 무를 고를 수 있어요.',
        slug: 'nambu_market',
      ),
    ],
  ),
  FoodInfo(
    slug: 'chodang_sundubu',
    name: '초당순두부',
    description: '바닷물로 간을 맞춰 부드럽게 엉긴 강릉 초당동의 순두부예요.',
    ingredients: [
      RecipeIngredient(name: '콩', slug: 'soybean', owned: 0, required: 2),
      RecipeIngredient(name: '간수', slug: 'brine', owned: 0, required: 1),
      RecipeIngredient(name: '소금', slug: 'salt', owned: 1, required: 1),
    ],
    places: [
      IngredientPlace(
        ingredientName: '콩',
        ingredientSlug: 'soybean',
        placeName: '강릉 초당마을',
        description: '순두부 마을에서 좋은 콩을 구할 수 있어요.',
        slug: 'chodang_village',
      ),
      IngredientPlace(
        ingredientName: '간수',
        ingredientSlug: 'brine',
        placeName: '주문진 바닷가',
        description: '깨끗한 바닷물로 만든 간수를 얻을 수 있어요.',
        slug: 'jumunjin_beach',
      ),
    ],
  ),
  FoodInfo(
    slug: 'gamja_ongsimi',
    name: '감자옹심이',
    description: '으깬 감자를 동글게 빚어 넣은 쫄깃하고 담백한 강원도 음식이에요.',
    ingredients: [
      RecipeIngredient(name: '감자', slug: 'potato', owned: 0, required: 3),
      RecipeIngredient(name: '애호박', slug: 'zucchini', owned: 0, required: 1),
      RecipeIngredient(name: '파', slug: 'green_onion', owned: 0, required: 1),
      RecipeIngredient(name: '소금', slug: 'salt', owned: 1, required: 1),
    ],
    places: [
      IngredientPlace(
        ingredientName: '감자',
        ingredientSlug: 'potato',
        placeName: '평창 감자밭',
        description: '고랭지에서 자란 단단한 감자를 캘 수 있어요.',
        slug: 'pyeongchang_potato',
      ),
    ],
  ),
  FoodInfo(
    slug: 'chalbori_ppang',
    name: '찰보리빵',
    description: '찰보리 반죽에 팥소를 넣어 구운 쫀득한 경주의 간식이에요.',
    ingredients: [
      RecipeIngredient(name: '보리', slug: 'barley', owned: 0, required: 2),
      RecipeIngredient(name: '팥', slug: 'red_bean', owned: 0, required: 2),
      RecipeIngredient(name: '밀가루', slug: 'flour', owned: 0, required: 1),
      RecipeIngredient(name: '소금', slug: 'salt', owned: 1, required: 1),
    ],
    places: [
      IngredientPlace(
        ingredientName: '보리',
        ingredientSlug: 'barley',
        placeName: '경주 성동시장',
        description: '경주 찰보리빵의 재료가 모이는 시장이에요.',
        slug: 'gyeongju_seongdong',
      ),
      IngredientPlace(
        ingredientName: '팥',
        ingredientSlug: 'red_bean',
        placeName: '경주 성동시장',
        description: '잘 삶아 쓰기 좋은 국산 팥을 살 수 있어요.',
        slug: 'gyeongju_seongdong',
      ),
    ],
  ),
  // 모든 재료가 준비된 예시 — "만들기" 활성화 → 셰프의 주방 진입 플로우 확인용.
  FoodInfo(
    slug: 'maneul_bokkeumbap',
    name: '마늘볶음밥',
    description: '알싸한 마늘 향을 입힌 고소한 볶음밥이에요.',
    completedDescription: '알싸한 마늘 향이 입맛을 돋우는 볶음밥이 완성되었어요.',
    specialNotes: [
      SpecialNote(
        name: '마늘',
        slug: 'garlic',
        note: '알싸한 향을 내는 국산 통마늘',
      ),
      SpecialNote(
        name: '참기름',
        slug: 'sesame_oil',
        note: '고소한 풍미를 더하는 참기름',
      ),
    ],
    ingredients: [
      RecipeIngredient(name: '쌀', slug: 'rice', owned: 3, required: 1),
      RecipeIngredient(name: '마늘', slug: 'garlic', owned: 5, required: 2),
      RecipeIngredient(name: '간장', slug: 'soy_sauce', owned: 1, required: 1),
      RecipeIngredient(name: '참기름', slug: 'sesame_oil', owned: 1, required: 1),
      RecipeIngredient(name: '계란', slug: 'egg', owned: 1, required: 1),
    ],
  ),
];

FoodInfo? foodInfoFor(String slug) {
  for (final info in _infos) {
    if (info.slug == slug) return info;
  }
  return null;
}

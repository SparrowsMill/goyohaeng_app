/// 음식 히스토리 placeholder 데이터 — user_flow §4. 이미 만든 음식을 눌렀을 때
/// 보여주는 만든 날짜 · 사용된 재료 · 특별 재료를 얻은 관광 스팟 정보.
///
/// * TODO(backend): 음식 히스토리 조회 API 연동 — 제작 일시, 사용된 재료 목록
///   (특별/일반 구분), 특별 재료를 획득한 관광 스팟, 음식 설명/특징. 지금은
///   `made` 상태 음식 일부만 예시로 채워져 있음.
/// * TODO(asset): 관광 스팟 썸네일 — 정해진 에셋 카테고리 없음. 임시로
///   `assets/illustrations/map/map_{slug}.png` 경로를 참조하고 없으면 아이콘 placeholder.
library;

class HistoryIngredient {
  const HistoryIngredient({required this.name, required this.slug});

  final String name;
  final String slug;

  String get illustrationPath =>
      'assets/illustrations/rewards/ingredient_$slug.png';
}

class HistorySpot {
  const HistorySpot({
    required this.name,
    required this.description,
    required this.slug,
  });

  final String name;
  final String description;
  final String slug;

  String get thumbnailPath => 'assets/illustrations/map/map_$slug.png';
}

class FoodHistory {
  const FoodHistory({
    required this.slug,
    required this.name,
    required this.region,
    required this.description,
    required this.madeDate,
    required this.characteristic,
    this.specialIngredients = const [],
    this.normalIngredients = const [],
    this.sourceSpots = const [],
  });

  final String slug;
  final String name;
  final String region;

  /// 히어로 카드 설명(2~3줄).
  final String description;
  final DateTime madeDate;

  /// "음식의 특징" 문단.
  final String characteristic;

  final List<HistoryIngredient> specialIngredients;
  final List<HistoryIngredient> normalIngredients;
  final List<HistorySpot> sourceSpots;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

final _histories = <FoodHistory>[
  FoodHistory(
    slug: 'jeonju_bibimbap',
    name: '전주비빔밥',
    region: '전주',
    description: '다양한 나물과 고추장, 참기름이 어우러진 전주의 대표 음식. '
        '색과 맛의 조화가 아름다워요.',
    madeDate: DateTime(2026, 8, 15),
    characteristic: '여러 가지 나물의 식감과 고소한 참기름, 매콤한 고추장이 조화를 '
        '이루어 풍부한 맛을 냅니다. 전주의 정성과 전통이 담긴 지역 대표 음식입니다.',
    specialIngredients: [
      HistoryIngredient(name: '참기름', slug: 'sesame_oil'),
      HistoryIngredient(name: '고추장', slug: 'gochujang'),
      HistoryIngredient(name: '들깨', slug: 'perilla'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '쌀', slug: 'rice'),
      HistoryIngredient(name: '콩나물', slug: 'beansprout'),
      HistoryIngredient(name: '시금치', slug: 'spinach'),
      HistoryIngredient(name: '당근', slug: 'carrot'),
      HistoryIngredient(name: '버섯', slug: 'mushroom'),
      HistoryIngredient(name: '계란', slug: 'egg'),
      HistoryIngredient(name: '소금', slug: 'salt'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '전주 한옥마을',
        description: '전통의 멋과 맛이 깃든 전주의 대표 관광지',
        slug: 'jeonju_hanok',
      ),
      HistorySpot(
        name: '경기전',
        description: '조선 태조의 영정을 모신 역사 깊은 문화 공간',
        slug: 'gyeonggijeon',
      ),
    ],
  ),
  FoodHistory(
    slug: 'kongnamul_gukbap',
    name: '콩나물국밥',
    region: '전주',
    description: '뜨끈한 국물에 콩나물과 밥을 말아낸 전주의 해장 음식. '
        '맑고 시원한 맛이 일품이에요.',
    madeDate: DateTime(2026, 8, 22),
    characteristic: '아삭한 콩나물과 개운한 국물이 속을 편안하게 달래 줍니다. '
        '전주 사람들이 아침으로 즐겨 찾는 음식입니다.',
    specialIngredients: [
      HistoryIngredient(name: '고춧가루', slug: 'chili_powder'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '쌀', slug: 'rice'),
      HistoryIngredient(name: '콩나물', slug: 'beansprout'),
      HistoryIngredient(name: '파', slug: 'green_onion'),
      HistoryIngredient(name: '계란', slug: 'egg'),
      HistoryIngredient(name: '멸치', slug: 'anchovy'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '전주 남부시장',
        description: '전주의 오랜 재래시장, 콩나물국밥 골목이 유명',
        slug: 'nambu_market',
      ),
    ],
  ),
  FoodHistory(
    slug: 'deulkkae_sujebi',
    name: '들깨수제비',
    region: '강릉',
    description: '손으로 뜯어낸 반죽에 고소한 들깨 국물을 더한 강릉의 향토 음식.',
    madeDate: DateTime(2026, 9, 3),
    characteristic: '들깨의 진한 고소함과 쫄깃한 수제비가 어우러져 든든한 한 그릇이 '
        '됩니다. 강릉의 소박한 밥상을 닮은 음식입니다.',
    specialIngredients: [
      HistoryIngredient(name: '들깨', slug: 'perilla'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '밀가루', slug: 'flour'),
      HistoryIngredient(name: '애호박', slug: 'zucchini'),
      HistoryIngredient(name: '감자', slug: 'potato'),
      HistoryIngredient(name: '파', slug: 'green_onion'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '강릉 중앙시장',
        description: '강원도 식재료가 모이는 강릉의 중심 시장',
        slug: 'gangneung_market',
      ),
    ],
  ),
  FoodHistory(
    slug: 'yakgwa',
    name: '약과',
    region: '경주',
    description: '밀가루 반죽을 꿀과 기름에 지져낸 달콤하고 쫀득한 전통 한과.',
    madeDate: DateTime(2026, 7, 28),
    characteristic: '꿀의 은은한 단맛과 참기름의 고소함이 배어 쫀득하게 씹힙니다. '
        '잔칫상과 제사상에 오르던 귀한 과자입니다.',
    specialIngredients: [
      HistoryIngredient(name: '참기름', slug: 'sesame_oil'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '밀가루', slug: 'flour'),
      HistoryIngredient(name: '꿀', slug: 'honey'),
      HistoryIngredient(name: '생강', slug: 'ginger'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '경주 황리단길',
        description: '한옥 사이로 전통 먹거리가 늘어선 경주의 골목',
        slug: 'gyeongju_hwangnidan',
      ),
    ],
  ),
  FoodHistory(
    slug: 'tea',
    name: '전통차',
    region: '보성',
    description: '정성껏 우려낸 따뜻한 차 한 잔의 여유.',
    madeDate: DateTime(2026, 8, 5),
    characteristic: '맑고 은은한 향이 마음을 차분하게 가라앉힙니다. 느리게 흐르는 '
        '시간을 닮은 음료입니다.',
    specialIngredients: [
      HistoryIngredient(name: '녹차잎', slug: 'greentea'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '꿀', slug: 'honey'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '보성 녹차밭',
        description: '층층이 이어진 초록빛 차밭 풍경으로 유명한 곳',
        slug: 'boseong_green_tea',
      ),
    ],
  ),
  FoodHistory(
    slug: 'samsaek_songpyeon',
    name: '삼색송편',
    region: '서울',
    description: '흰색·쑥색·분홍색 고운 빛깔로 빚어낸 명절 떡.',
    madeDate: DateTime(2026, 9, 1),
    characteristic: '쫄깃한 떡 안에 고소한 소가 들어 있고, 솔잎 향이 은은하게 '
        '뱁니다. 온 가족이 둘러앉아 빚던 한가위 음식입니다.',
    specialIngredients: [
      HistoryIngredient(name: '들깨', slug: 'perilla'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '쌀', slug: 'rice'),
      HistoryIngredient(name: '쑥', slug: 'mugwort'),
      HistoryIngredient(name: '꿀', slug: 'honey'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '남대문시장',
        description: '온갖 식재료가 모이는 서울의 대표 재래시장',
        slug: 'namdaemun_market',
      ),
    ],
  ),
  FoodHistory(
    slug: 'janchi_guksu',
    name: '잔치국수',
    region: '안동',
    description: '멸치 육수에 소면을 말아낸 담백하고 깔끔한 국수 한 그릇.',
    madeDate: DateTime(2026, 8, 30),
    characteristic: '시원한 멸치 육수와 부드러운 소면, 알록달록한 고명이 어우러집니다. '
        '잔칫날 손님상에 내던 정겨운 음식입니다.',
    specialIngredients: [
      HistoryIngredient(name: '간장', slug: 'soy_sauce'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '소면', slug: 'somyeon'),
      HistoryIngredient(name: '멸치', slug: 'anchovy'),
      HistoryIngredient(name: '애호박', slug: 'zucchini'),
      HistoryIngredient(name: '계란', slug: 'egg'),
      HistoryIngredient(name: '파', slug: 'green_onion'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '안동 구시장',
        description: '안동국시와 건진국수로 이름난 오래된 시장',
        slug: 'andong_market',
      ),
    ],
  ),
  FoodHistory(
    slug: 'maneul_bokkeumbap',
    name: '마늘볶음밥',
    region: '전주',
    description: '알싸한 마늘 향을 입힌 고소한 볶음밥이에요.',
    madeDate: DateTime(2026, 9, 9),
    characteristic: '노릇하게 볶은 마늘의 단맛과 고소한 참기름이 밥알에 배어 '
        '입맛을 돋웁니다. 간단하지만 자꾸 손이 가는 한 그릇이에요.',
    specialIngredients: [
      HistoryIngredient(name: '마늘', slug: 'garlic'),
      HistoryIngredient(name: '참기름', slug: 'sesame_oil'),
    ],
    normalIngredients: [
      HistoryIngredient(name: '쌀', slug: 'rice'),
      HistoryIngredient(name: '간장', slug: 'soy_sauce'),
      HistoryIngredient(name: '계란', slug: 'egg'),
    ],
    sourceSpots: [
      HistorySpot(
        name: '전주 남부시장',
        description: '갓 들어온 신선한 재료가 모이는 전통시장',
        slug: 'nambu_market',
      ),
    ],
  ),
];

FoodHistory? foodHistoryFor(String slug) {
  for (final h in _histories) {
    if (h.slug == slug) return h;
  }
  return null;
}

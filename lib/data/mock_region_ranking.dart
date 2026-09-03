/// Placeholder tourist-spot ranking data for `<지역별 랭킹 페이지>`
/// (user_flow §6). Everything here — the spots, their 갭지수, whether a visit
/// can be verified, the obtainable ingredient, and the open/closed state —
/// is backend data; this file just stands in until the API exists.
///
/// The same records back `<장소 정보 페이지>` (user_flow §6): the extra fields
/// (주소, 운영시간, 주인의 소개, 트렌드 키워드, 문의처 …) are consumed there.
///
/// * TODO(backend): 지역별 관광스팟 랭킹 API 연동 (카테고리/정렬 파라미터 포함)
/// * TODO(backend): 장소 상세 정보 API 연동 (주소·운영시간·트렌드 키워드 등)
library;

enum SpotCategory {
  restaurant('식당'),
  cafe('카페'),
  activity('액티비티');

  const SpotCategory(this.label);
  final String label;
}

enum BusinessStatus {
  open('영업 중'),
  closed('영업 종료'),
  holiday('휴무');

  const BusinessStatus(this.label);
  final String label;
}

/// Whether the current user has completed 방문 인증 for this spot — drives the
/// "미방문 / 방문 인증 완료" pill on `<장소 정보 페이지>`.
enum VisitState {
  notVisited('미방문'),
  verified('방문 인증 완료');

  const VisitState(this.label);
  final String label;
}

class MockTouristSpot {
  const MockTouristSpot({
    required this.name,
    required this.category,
    required this.gapIndex,
    required this.visitVerifiable,
    required this.ingredient,
    required this.businessStatus,
    this.spotType = '관광명소',
    this.address = '주소 정보를 준비하고 있어요',
    this.hours = const ['운영시간 정보를 준비하고 있어요'],
    this.ownerIntro = '이곳만의 이야기를 곧 들려드릴게요.',
    this.trendKeywords = const ['숨은명소', '조용한여행', '힐링'],
    this.phone,
    this.homepage,
    this.visitState = VisitState.notVisited,
    this.storeBenefit,
    this.ingredientCount = 1,
  });

  final String name;
  final SpotCategory category;
  final int gapIndex;

  /// 방문 인증 가능 여부 (admin 토글에 의존 — user_flow §6).
  final bool visitVerifiable;

  /// 획득 가능한 재료 이름. `null`이면 "획득 재료 없음".
  final String? ingredient;

  /// 방문 인증 1회로 지급되는 재료 개수.
  final int ingredientCount;

  final BusinessStatus businessStatus;

  /// 넓은 분류 라벨 (예: 자연관광). `<장소 정보 페이지>`의 카테고리 줄에서
  /// "$spotType · ${category.label}" 형태로 함께 노출된다.
  final String spotType;

  final String address;

  /// 운영시간 — 줄 단위. (예: 성수기/비수기 구분, 입장 마감 안내)
  final List<String> hours;

  /// 주인의 소개 (user_flow §6 "주인 소개").
  final String ownerIntro;

  /// 트렌드 요약의 근거가 된 최다 언급 키워드 3-5개 (user_flow §6).
  final List<String> trendKeywords;

  /// 문의 전화번호 (옵션 — user_flow §6).
  final String? phone;

  /// 공식 홈페이지 URL (옵션 — user_flow §6).
  final String? homepage;

  final VisitState visitState;

  /// 매장 자체 방문 혜택. `null`이면 "제공 혜택 없음".
  final String? storeBenefit;

  /// 갭지수 구간에 따른 한 줄 설명 (user_flow §6 예: "온라인 관심에 비해
  /// 실제 방문이 적은 편이에요").
  String get gapDescription {
    if (gapIndex >= 75) {
      return '온라인 관심에 비해 실제 방문이 적은 편이에요.\n'
          '잘 알려져 있지만 비교적 여유롭게 둘러볼 수 있는 장소예요.';
    }
    if (gapIndex >= 50) {
      return '검색되는 만큼 실제 방문도 꾸준히 이어지는 편이에요.\n'
          '적당한 관심과 발길이 함께 닿는 장소예요.';
    }
    return '관심에 비해 이미 발길이 많이 닿은 장소예요.\n'
        '붐비는 시간대는 살짝 피해 찾는 걸 추천해요.';
  }
}

/// Keyed by [MockMapRegion.key]. Regions without a bespoke list fall back to
/// [_fallbackSpots] so no region opens empty.
const mockRegionRankings = <String, List<MockTouristSpot>>{
  'jeolla': [
    MockTouristSpot(
      name: '담양 죽녹원',
      category: SpotCategory.activity,
      gapIndex: 89,
      visitVerifiable: true,
      ingredient: '대나무잎',
      businessStatus: BusinessStatus.open,
      spotType: '자연관광',
      address: '전라남도 담양군 담양읍 죽녹원로 119',
      hours: [
        '3월-10월  09:00-19:00',
        '11월-2월  09:00-18:00',
        '입장 마감은 종료 30-60분 전',
      ],
      ownerIntro: '대나무숲의 고요한 길을 따라 천천히\n산책하며 쉬어갈 수 있는 공간이에요.',
      trendKeywords: ['대나무숲', '산책', '사진명소', '고요한분위기', '힐링'],
      phone: '061-380-2680',
      homepage: 'https://juknokwon.go.kr',
      storeBenefit: '입장권 10% 할인',
    ),
    MockTouristSpot(
      name: '담양 소쇄원',
      category: SpotCategory.activity,
      gapIndex: 84,
      visitVerifiable: false,
      ingredient: null,
      businessStatus: BusinessStatus.holiday,
      spotType: '역사문화',
      address: '전라남도 담양군 가사문학면 소쇄원길 17',
      hours: [
        '3월-10월  09:00-18:00',
        '11월-2월  09:00-17:00',
        '매주 화요일 정기 휴무',
      ],
      ownerIntro: '자연을 거스르지 않고 지은 옛 정원에서\n느린 걸음으로 계절을 느껴보세요.',
      trendKeywords: ['정원', '고요한분위기', '전통풍경', '사진명소'],
      phone: '061-381-0115',
    ),
    MockTouristSpot(
      name: '담양 메타세쿼이아길',
      category: SpotCategory.activity,
      gapIndex: 71,
      visitVerifiable: true,
      ingredient: '단풍잎',
      businessStatus: BusinessStatus.open,
      spotType: '자연관광',
      address: '전라남도 담양군 담양읍 학동리 578-4',
      hours: [
        '3월-10월  09:00-19:00',
        '11월-2월  09:00-18:00',
      ],
      ownerIntro: '높게 뻗은 나무들이 이룬 초록 터널을\n천천히 걸으며 사진에 담아보세요.',
      trendKeywords: ['사진명소', '고요한분위기', '산책', '드라이브'],
      phone: '061-380-3149',
    ),
    MockTouristSpot(
      name: '담양 관방제림',
      category: SpotCategory.activity,
      gapIndex: 66,
      visitVerifiable: true,
      ingredient: '느티나무잎',
      businessStatus: BusinessStatus.open,
      spotType: '자연관광',
      address: '전라남도 담양군 담양읍 객사리 관방제림길',
      hours: ['상시 개방 (제방 산책로)'],
      ownerIntro: '오래된 나무가 늘어선 냇가 둑길을\n따라 여유롭게 산책할 수 있어요.',
      trendKeywords: ['힐링산책', '전통풍경', '산책', '노거수'],
      phone: '061-380-3752',
    ),
    MockTouristSpot(
      name: '순천만 국가정원',
      category: SpotCategory.activity,
      gapIndex: 82,
      visitVerifiable: true,
      ingredient: '갈대',
      businessStatus: BusinessStatus.open,
      spotType: '자연관광',
      address: '전라남도 순천시 국가정원1호길 47',
      hours: [
        '3월-10월  09:00-19:00',
        '11월-2월  09:00-18:00',
        '입장 마감은 종료 1시간 전',
      ],
      ownerIntro: '드넓은 정원과 갈대밭을 걸으며\n계절의 색을 천천히 느껴보세요.',
      trendKeywords: ['갈대밭', '정원산책', '노을', '가족나들이'],
      phone: '1577-2013',
      homepage: 'https://scbay.suncheon.go.kr',
    ),
    MockTouristSpot(
      name: '보성 녹차밭',
      category: SpotCategory.cafe,
      gapIndex: 76,
      visitVerifiable: true,
      ingredient: '녹차잎',
      businessStatus: BusinessStatus.closed,
      spotType: '자연관광',
      address: '전라남도 보성군 보성읍 녹차로 763-67',
      hours: [
        '3월-10월  09:00-18:00',
        '11월-2월  09:00-17:00',
        '입장 마감은 종료 30분 전',
      ],
      ownerIntro: '층층이 이어진 초록빛 다원을 오르며\n맑은 공기를 마셔보세요.',
      trendKeywords: ['녹차밭', '초록물결', '사진명소', '드라이브'],
      phone: '061-852-4540',
    ),
    MockTouristSpot(
      name: '여수 해상케이블카',
      category: SpotCategory.activity,
      gapIndex: 68,
      visitVerifiable: false,
      ingredient: null,
      businessStatus: BusinessStatus.open,
      spotType: '액티비티',
      address: '전라남도 여수시 오동도로 3',
      hours: [
        '평일  09:00-21:30',
        '주말·공휴일  09:00-22:00',
        '탑승 마감은 운행 종료 30분 전',
      ],
      ownerIntro: '바다 위를 가로지르며 여수 밤바다와\n돌산의 풍경을 한눈에 담아보세요.',
      trendKeywords: ['여수밤바다', '케이블카', '야경', '커플여행'],
      phone: '061-664-7301',
      homepage: 'https://www.yeosucablecar.com',
    ),
    MockTouristSpot(
      name: '전주 한옥마을',
      category: SpotCategory.restaurant,
      gapIndex: 61,
      visitVerifiable: true,
      ingredient: '콩나물',
      businessStatus: BusinessStatus.holiday,
      spotType: '역사문화',
      address: '전라북도 전주시 완산구 기린대로 99',
      hours: [
        '상시 개방 (거리)',
        '개별 상점·전시관은 매장별 운영시간 상이',
      ],
      ownerIntro: '기와지붕이 이어지는 골목을 걸으며\n전주만의 맛과 멋을 느껴보세요.',
      trendKeywords: ['한복나들이', '전주비빔밥', '골목산책', '전통찻집'],
      phone: '063-282-1330',
      homepage: 'https://hanok.jeonju.go.kr',
    ),
    MockTouristSpot(
      name: '군산 초원사진관',
      category: SpotCategory.activity,
      gapIndex: 54,
      visitVerifiable: true,
      ingredient: null,
      businessStatus: BusinessStatus.open,
      spotType: '역사문화',
      address: '전라북도 군산시 구영2길 12-1',
      hours: [
        '매일  09:00-18:00',
        '매주 월요일 휴무',
      ],
      ownerIntro: '영화 속 한 장면 같은 작은 사진관에서\n느린 오후를 기록해보세요.',
      trendKeywords: ['영화촬영지', '레트로', '흑백사진', '군산여행'],
      phone: '063-445-6879',
    ),
    MockTouristSpot(
      name: '목포 근대역사관',
      category: SpotCategory.cafe,
      gapIndex: 47,
      visitVerifiable: false,
      ingredient: '홍어',
      businessStatus: BusinessStatus.open,
      spotType: '역사문화',
      address: '전라남도 목포시 영산로 29번길 6',
      hours: [
        '매일  09:00-18:00',
        '매주 월요일 휴관',
        '입장 마감은 관람 종료 30분 전',
      ],
      ownerIntro: '오래된 건물에 남은 시간의 결을\n천천히 따라가며 살펴보세요.',
      trendKeywords: ['근대건축', '목포투어', '역사기행', '사진명소'],
      phone: '061-242-0340',
    ),
  ],
};

const _fallbackSpots = <MockTouristSpot>[
  MockTouristSpot(
    name: '숨은 명소 준비 중',
    category: SpotCategory.activity,
    gapIndex: 70,
    visitVerifiable: true,
    ingredient: null,
    businessStatus: BusinessStatus.open,
    spotType: '자연관광',
    address: '주소 정보를 준비하고 있어요',
    hours: ['운영시간 정보를 준비하고 있어요'],
    ownerIntro: '이 지역의 숨은 명소를 곧 소개해 드릴게요.',
    trendKeywords: ['숨은명소', '조용한여행', '힐링'],
  ),
];

List<MockTouristSpot> rankingForRegion(String regionKey) =>
    mockRegionRankings[regionKey] ?? _fallbackSpots;

/// The region key whose ranking list contains [spot] (matched by name), or
/// `null` if it only came from [_fallbackSpots]. Used by `<방문 불가>` to pull
/// nearby recommendations from the same region.
String? regionKeyForSpot(MockTouristSpot spot) {
  for (final entry in mockRegionRankings.entries) {
    if (entry.value.any((s) => s.name == spot.name)) return entry.key;
  }
  return null;
}

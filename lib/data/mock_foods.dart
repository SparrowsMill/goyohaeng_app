/// 내가 만든(완성한) 음식 목록 + 전체 완성 개수 — 실제 음식/도감 백엔드가
/// 생기기 전까지 쓰는 placeholder. 화면은 `MyFoodsStore.instance` 를 통해 읽는다.
///
/// * TODO(backend): 완성한 음식 목록 조회 + 제작 시 서버 반영 API 연동
///   (이름·한 줄 설명·완성일·획득 일러스트 — user_flow §4). 지금은 셰프의 주방에서
///   만든 음식을 `MyFoodsStore` 로컬 상태에만 앞쪽에 추가한다(앱 재시작 시 초기화).
/// * TODO(backend): 완성한 음식 총 개수(도감 진행도) 조회.
/// * TODO(backend): 음식별 필요 재료(레시피) 조회 — `<음식 정보>`(§4)에서
///   보유/필요 수량 표기에 사용. 여기 목록엔 아직 재료 정보 없음.
/// * TODO(asset): 음식별 일러스트 미납품 —
///   `assets/illustrations/food/food_{slug}.png` (투명 배경 PNG, §9 네이밍 규칙).
///   납품 시 `pubspec.yaml` 의 `flutter > assets` 에
///   `- assets/illustrations/food/` 한 줄 추가 필요. 그 전까지 `_FoodCard` 가
///   errorBuilder 로 범용 접시 아이콘 placeholder 를 그린다.
library;

import 'package:flutter/foundation.dart';

class MockFood {
  const MockFood({
    required this.name,
    required this.slug,
    required this.description,
  });

  final String name;
  final String slug;

  /// 카드에 들어가는 짧은 설명(한 줄, 최대 2줄로 줄바꿈됨).
  final String description;

  String get illustrationPath => 'assets/illustrations/food/food_$slug.png';
}

/// 도감 진행도 — "완성한 음식 N개". 목록보다 큰 값일 수 있어 별도로 둔다.
const mockCompletedFoodCount = 18;

const mockMyFoods = <MockFood>[
  MockFood(
    name: '전주비빔밥',
    slug: 'jeonju_bibimbap',
    description: '알록달록 재료가 어우러진 맛',
  ),
  MockFood(
    name: '들깨수제비',
    slug: 'deulkkae_sujebi',
    description: '고소한 들깨 향이 가득',
  ),
  MockFood(
    name: '약과',
    slug: 'yakgwa',
    description: '달콤하고 쫀득한 전통 한과',
  ),
  MockFood(
    name: '전통차',
    slug: 'tea',
    description: '따뜻한 차 한 잔의 여유',
  ),
  MockFood(
    name: '삼색송편',
    slug: 'samsaek_songpyeon',
    description: '고운 빛깔의 명절 떡',
  ),
  MockFood(
    name: '잔치국수',
    slug: 'janchi_guksu',
    description: '담백하고 깔끔한 국수 한 그릇',
  ),
];

/// "내가 만든 음식" 목록의 로컬 상태. 셰프의 주방에서 요리를 완성하면
/// [markMade] 로 해당 음식을 목록 맨 앞에 추가/이동한다. 백엔드 연동 전까지의
/// 임시 저장소 — 앱을 재시작하면 [mockMyFoods] 초기 상태로 돌아간다.
class MyFoodsStore extends ChangeNotifier {
  MyFoodsStore._();

  static final instance = MyFoodsStore._();

  final List<MockFood> _foods = [...mockMyFoods];

  List<MockFood> get foods => List.unmodifiable(_foods);

  /// 방금 만든 음식을 목록 맨 앞으로. 이미 있으면 이동, 없으면 새로 추가.
  void markMade({
    required String slug,
    required String name,
    required String description,
  }) {
    _foods.removeWhere((f) => f.slug == slug);
    _foods.insert(0, MockFood(name: name, slug: slug, description: description));
    notifyListeners();
  }
}

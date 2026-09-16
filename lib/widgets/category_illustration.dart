import 'package:flutter/material.dart';

import '../data/mock_region_ranking.dart';

/// 카테고리별 워터컬러 일러스트 (`assets/illustrations/categories/`).
/// [PlaceInfoScreen]의 타이틀 옆 아이콘과 `<방문 인증 페이지>` 헤더가 동일한
/// 매핑을 공유한다 — 카테고리 추가 시 이 파일 한 곳만 수정하면 된다.
class CategoryIllustration extends StatelessWidget {
  const CategoryIllustration({super.key, required this.spot, required this.size});

  final MockTouristSpot spot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/illustrations/categories/${switch (spot.categoryName ?? spot.category.label) {
        '관광' || '관광지' => 'attraction',
        '문화' => 'culture',
        '축제' || '축제·행사' => 'festival',
        '음식' || '식당' || '카페' => 'food',
        '쇼핑' => 'shopping',
        '숙박' => 'stay',
        '레저' || '레저·오락' || '액티비티' => 'leisure',
        _ => 'all',
      }}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}

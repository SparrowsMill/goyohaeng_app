/// Bundled dish asset mapping. Foods without a local asset remain visible and
/// fall back to their server image or the generic dish icon.
///
/// 콘텐츠 마스터(D01~D39) 39종 모두 `assets/illustrations/rewards/dish/`에
/// 그림은 이미 있지만, 이 맵에는 의도적으로 다르게 반영한다:
///
/// * COMMON / UNCOMMON / RARE(D01~D33, 33종)는 지역과 무관하게 전부 매핑한다
///   — 재료 자체는 지역을 타도(BASIC 외 RARE급 재료도 지역 한정 없이 얻을 수
///   있음), 음식 그림은 어느 지역 사용자든 다 보이게 푼다.
/// * LEGENDARY(D34~D39, 지역당 1종)는 수도권 것(강화 순무밥상)만 매핑하고
///   나머지 5개(강원/충청/경상/전라/제주)는 의도적으로 비워둔다 — 전설급
///   재료가 들어가는 음식은 수도권으로 제한한다는 결정. 나중에 다른 지역
///   전설 음식도 풀기로 하면 그때 이 5개(D35~D39)를 추가하면 된다.
abstract final class FoodCatalog {
  static const assets = <String, String>{
    // COMMON (D01~D10)
    '계란볶음밥': 'dish_egg_fried_rice',
    '감자채볶음': 'dish_stir_fried_potato',
    '김치볶음밥': 'dish_kimchi_fried_rice',
    '계란말이': 'dish_rolled_omelette',
    '감자조림': 'dish_braised_potato',
    '감자양파국': 'dish_potato_onion_soup',
    '김치전': 'dish_kimchi_pancake',
    '양파계란볶음': 'dish_onion_stir_fried_egg',
    '마늘계란볶음': 'dish_garlic_stir_fried_egg',
    '계란찜': 'dish_steamed_egg',
    // UNCOMMON (D11~D15)
    '돼지고기김치찌개': 'dish_pork_kimchi_stew',
    '두부채소국': 'dish_tofu_vegetable_soup',
    '표고버섯볶음': 'dish_stir_fried_shiitake',
    '새우볶음밥': 'dish_shrimp_fried_rice',
    '오징어볶음': 'dish_stir_fried_squid',
    // RARE — 수도권 (D16~D18)
    '수도권 한우장국밥': 'dish_metro_beef_gukbap',
    '한강 장어구이': 'dish_hangang_grilled_eel',
    '더덕고추장구이': 'dish_grilled_deodeok_gochujang',
    // RARE — 강원 (D19~D21)
    '횡성식 한우국밥': 'dish_hoengseong_beef_gukbap',
    '정선 더덕구이': 'dish_jeongseon_grilled_deodeok',
    '양양 능이버섯찌개': 'dish_yangyang_neungi_mushroom_stew',
    // RARE — 충청 (D22~D24)
    '금강 민물장어구이': 'dish_geumgang_grilled_eel',
    '충청 한우불고기': 'dish_chungcheong_beef_bulgogi',
    '보령 전복죽': 'dish_boryeong_abalone_porridge',
    // RARE — 경상 (D25~D27)
    '안동 능이백숙': 'dish_andong_neungi_mushroom_baeksuk',
    '거제 전복돌솥밥': 'dish_geoje_abalone_hotpot_rice',
    '산청 더덕한우비빔밥': 'dish_sancheong_deodeok_beef_bibimbap',
    // RARE — 전라 (D28~D30)
    '나주 장어구이': 'dish_naju_grilled_eel',
    '담양 한우떡갈비': 'dish_damyang_beef_tteokgalbi',
    '완도 전복장어탕': 'dish_wando_abalone_eel_soup',
    // RARE — 제주 (D31~D33)
    '제주 전복뚝배기': 'dish_jeju_abalone_hotpot',
    '제주 한우구이': 'dish_jeju_grilled_beef',
    '제주 더덕비빔밥': 'dish_jeju_deodeok_bibimbap',
    // LEGENDARY — 수도권만 (D34). D35~D39(강원/충청/경상/전라/제주)는
    // 의도적으로 미포함.
    '강화 순무밥상': 'dish_ganghwa_turnip_rice_set',
  };

  static String? assetPath(String name) {
    final asset = assets[name];
    return asset == null
        ? null
        : 'assets/illustrations/rewards/dish/$asset.png';
  }

  /// [assets]에 없는 음식(비수도권 전설 음식)은 아직 안 연 콘텐츠다 — 음식
  /// 도감/재료 가방의 "만들 수 있어요" 목록 등에서 이 이름으로 걸러 숨긴다.
  static bool isOpen(String name) => assets.containsKey(name);

  static List<Map<String, dynamic>> rows(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
}

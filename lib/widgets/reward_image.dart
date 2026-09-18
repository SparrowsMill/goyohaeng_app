import 'package:flutter/material.dart';

import '../data/food_catalog.dart';

/// 요리(dish) / 재료(ingredient) 이미지 — 이름이 정확히 일치하는 로컬 에셋
/// (`assets/illustrations/rewards/{dish|ingredient}/{name}.png`)이 있으면
/// 서버 `imageUrl`을 기다리지 않고 그것부터 쓴다. 일치하는 로컬 에셋이 없으면
/// 서버 URL로, 그마저 없거나 로드 실패하면 아이콘으로 폴백한다
/// (§6 — placeholder 대신 기존 errorBuilder 패턴 유지).
enum RewardAssetFolder { dish, ingredient }

/// 지역 특산 재료 파일명을 전부 영문으로 통일하면서(S3/CDN 업로드 시 한글·공백
/// 파일명을 피하기 위해) 서버가 내려주는 한글 재료명과 파일명이 더 이상 같지
/// 않게 된 항목들의 매핑. 이 목록에 없는 이름은 그대로 파일명으로 시도한다.
const Map<String, String> _ingredientAssetOverrides = {
  // BASIC (재료 마스터 I01~I18).
  '쌀': 'ingredient_rice',
  '계란': 'ingredient_egg',
  '대파': 'ingredient_green_onion',
  '마늘': 'ingredient_garlic',
  '양파': 'ingredient_onion',
  '감자': 'ingredient_potato',
  '김치': 'ingredient_kimchi',
  '간장': 'ingredient_soy_sauce',
  '밀가루': 'ingredient_flour',
  '돼지고기': 'ingredient_pork',
  '두부': 'ingredient_tofu',
  '표고버섯': 'ingredient_pyogo_mushroom',
  '새우': 'ingredient_shrimp',
  '오징어': 'ingredient_squid',
  '닭고기': 'ingredient_chicken',
  '고추장': 'ingredient_gochujang',
  '한우': 'ingredient_beef',
  '전복': 'ingredient_jeonbok',
  '능이버섯': 'ingredient_neungi_mushroom',
  // BASIC 중 파일명이 한글 표기 그대로였던 것들 (I20, I21).
  '산더덕': 'ingredient_wild_deodeok',
  '민물장어': 'ingredient_freshwater_eel',
  // REGIONAL + LEGENDARY (I22~I27) — 전설급 재료는 수도권 것(강화 순무)만
  // 연다. 나머지 5개(평창 자연산 송이버섯/금산 인삼/영덕 대게/순창 명인
  // 고추장/제주 옥돔)는 [FoodCatalog.assets]의 전설 음식(D35~D39) 제한과
  // 짝을 맞춰 의도적으로 미포함 — 파일은 이미 있지만 지금은 안 풀어서 서버
  // URL/아이콘으로 폴백한다.
  '강화 순무': 'ingredient_ganghwa_turnip',
};

/// [name]이 아직 안 연 콘텐츠(비수도권 전설 재료)인지 — BASIC/REGIONAL
/// 재료는 파일명이 한글 원본과 달라 예외 없이 위 오버라이드가 있으므로,
/// 오버라이드가 없다는 것 자체가 "닫힌 콘텐츠"라는 뜻이다. 재료 가방 등
/// 목록 화면에서 이 이름으로 걸러 숨긴다.
bool isIngredientOpen(String name) => _ingredientAssetOverrides.containsKey(name);

class RewardImage extends StatelessWidget {
  const RewardImage({
    super.key,
    required this.name,
    required this.folder,
    this.networkUrl,
    required this.icon,
    required this.color,
    this.fit = BoxFit.contain,
    this.iconSize,
  });

  final String name;
  final RewardAssetFolder folder;
  final String? networkUrl;
  final IconData icon;
  final Color color;
  final BoxFit fit;
  final double? iconSize;

  Widget _netOrIcon() {
    final u = networkUrl;
    if (u == null || u.isEmpty) {
      return Center(
        child: Icon(icon, size: iconSize, color: color),
      );
    }
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (folder == RewardAssetFolder.dish) {
      final path = FoodCatalog.assetPath(name);
      if (path == null) {
        return _netOrIcon();
      }
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _netOrIcon(),
      );
    }
    if (name.isEmpty) return _netOrIcon();
    const folderName = 'ingredient';
    final assetName = _ingredientAssetOverrides[name] ?? name;
    return Image.asset(
      'assets/illustrations/rewards/$folderName/$assetName.png',
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _netOrIcon(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_food_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';
import 'chef_kitchen_screen.dart';

/// `<음식 정보>` (user_flow §4) — 음식 도감에서 아직 만들지 못한 음식을 눌렀을 때.
/// 필요 재료(보유/필요 수량), 부족한 재료를 얻을 수 있는 장소, "만들기" 버튼
/// (모든 재료 구비 시 활성화)을 보여준다.
///
/// 뼈대만 구현 — 데이터는 `mock_food_info` placeholder. "만들기"(모든 재료 구비
/// 시) → `<셰프의 주방>` 연결됨. 장소 "자세히 보기" → `<장소 정보 페이지>` 는
/// 미구현이라 스낵바 안내.
///
/// * TODO: "자세히 보기" → `<장소 정보 페이지>` (§6).
/// * TODO(asset): 이 화면 배경 scene — 음식 도감과 같은 펼친 책 밴드
///   (`assets/illustrations/scenes/food_dex_bg.png`) 재사용.
class FoodInfoScreen extends StatelessWidget {
  const FoodInfoScreen({super.key, required this.info});

  final FoodInfo info;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBar(onBack: () => Navigator.of(context).maybePop()),
              // 상단 헤더 밴드 scene. 납품 전까지 errorBuilder 로 아무것도
              // 그리지 않고 #FAE7C0 base 가 그대로 보이게 둔다.
              Image.asset(
                'assets/illustrations/scenes/food_dex_bg.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCard(info: info),
                    const SizedBox(height: AppSpacing.xxl),
                    _RequiredHeader(
                      owned: info.ownedCount,
                      total: info.totalCount,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _IngredientGrid(ingredients: info.ingredients),
                    if (info.places.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel(
                        '부족한 재료를 얻을 수 있는 장소',
                        icon: Symbols.location_on_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final place in info.places) ...[
                        _PlaceCard(
                          place: place,
                          onTap: () => _todo(
                            context,
                            '${place.placeName} 정보는 준비 중이에요.',
                          ),
                        ),
                        if (place != info.places.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    _MakeSection(
                      info: info,
                      onMake: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChefKitchenScreen(info: info),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
          // * TODO: 랭킹 탭 — 해당 화면 구현 후 연결.
        },
      ),
    );
  }
}

/// 뒤로가기 + 가운데 정렬 제목.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('음식 정보', style: AppTextStyles.h2),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Symbols.arrow_back_rounded),
                color: AppColors.iconPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 잠긴 음식 일러스트(실루엣 + 자물쇠) + 이름 + 설명 + "아직 만들지 못했어요" 칩.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.info});

  final FoodInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              width: 120,
              height: 120,
              color: AppColors.surfaceSelected,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      info.illustrationPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Symbols.dinner_dining_rounded,
                          size: 40,
                          color: AppColors.iconInactive,
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Symbols.lock_rounded,
                    size: 28,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name, style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  info.description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.hourglass_empty_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '아직 만들지 못했어요',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "🌿 필요한 재료" + 우측 "현재 N / M 재료 보유" 뱃지.
class _RequiredHeader extends StatelessWidget {
  const _RequiredHeader({required this.owned, required this.total});

  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SectionLabel('필요한 재료'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              children: [
                const TextSpan(text: '현재 '),
                TextSpan(
                  text: '$owned / $total',
                  style: TextStyle(
                    color: owned == total
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' 재료 보유'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientGrid extends StatelessWidget {
  const _IngredientGrid({required this.ingredients});

  final List<RecipeIngredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: ingredients.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 152,
      ),
      itemBuilder: (context, index) =>
          _IngredientCard(ingredient: ingredients[index]),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.ingredient});

  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final ok = ingredient.satisfied;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Image.asset(
              ingredient.illustrationPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Symbols.grocery_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ingredient.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${ingredient.owned} / ${ingredient.required}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: ok ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatusChip(ok: ok),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBackground : AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ok) ...[
            const Icon(
              Symbols.check_rounded,
              size: 12,
              color: AppColors.success,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            ok ? '보유완료' : '부족',
            style: AppTextStyles.caption.copyWith(
              color: ok ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 부족한 재료 획득 장소 카드 — 썸네일 + 재료 아이콘 + 이름/장소/설명 + 자세히 보기.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});

  final IngredientPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.smallButton),
                child: Container(
                  width: 60,
                  height: 60,
                  color: AppColors.surfaceSelected,
                  child: Image.asset(
                    place.thumbnailPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.storefront_rounded,
                      size: 22,
                      color: AppColors.iconInactive,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            place.ingredientIconPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Symbols.grocery_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          place.ingredientName,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.placeName,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      place.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '자세히',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryPressed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Symbols.chevron_right_rounded,
                    size: 16,
                    color: AppColors.primaryPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "재료 N개 더 필요" 안내 + "만들기" 버튼(모든 재료 구비 시 활성화).
class _MakeSection extends StatelessWidget {
  const _MakeSection({required this.info, required this.onMake});

  final FoodInfo info;
  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) {
    final canMake = info.canMake;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              children: canMake
                  ? const [TextSpan(text: '필요한 재료를 모두 모았어요!')]
                  : [
                      const TextSpan(text: '재료 '),
                      TextSpan(
                        text: '${info.missingCount}개',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const TextSpan(text: '가 더 필요해요.'),
                    ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canMake ? onMake : null,
              icon: const Icon(Symbols.soup_kitchen_rounded, size: 20),
              label: const Text('만들기'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canMake
                ? '지금 바로 만들 수 있어요.'
                : '모든 재료를 모으면 만들기 버튼이 활성화돼요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// 왼쪽 정렬 섹션 제목 — 앞에 작은 잎 또는 지정 아이콘.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 20, color: AppColors.primary)
        else
          _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.h3),
      ],
    );
  }
}

/// 브랜드 잎 장식(작게). 아직 파일이 없을 때를 대비해 errorBuilder 로 대체.
class _Leaf extends StatelessWidget {
  const _Leaf({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/branding/leaf_ornament.png',
      width: 18,
      height: 18,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 18),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}

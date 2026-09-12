import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_ingredients.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';
import 'ingredient_detail_sheet.dart';

/// `<재료 가방>` (user_flow §5) — 모은 재료를 확인하는 페이지. 기본 재료 /
/// 지역별 재료 탭으로 구분하고, 미획득 재료는 실루엣 + 이름, 획득 재료는 보유
/// 개수를 표시한다. 하단에 보유 재료로 만들 수 있는 음식 추천 코너.
///
/// 현재는 뼈대만 구현 — 데이터는 `mock_ingredients` placeholder. 재료 탭 시
/// `<재료 상세 페이지>` 모달(`ingredient_detail_sheet.dart`)을 띄운다.
///
/// * TODO: 추천 음식 탭 → `<음식 정보>` (§4).
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/ingredient_bag_bg.png` (§9, 불투명 헤더 밴드
///   PNG). 그 전까지 평면 #FAE7C0 위에 콘텐츠만 표시.
class IngredientBagScreen extends StatefulWidget {
  const IngredientBagScreen({super.key});

  @override
  State<IngredientBagScreen> createState() => _IngredientBagScreenState();
}

class _IngredientBagScreenState extends State<IngredientBagScreen> {
  IngredientCategory _category = IngredientCategory.basic;

  void _todo(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ingredientsByCategory(_category);

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
                'assets/illustrations/scenes/ingredient_bag_bg.png',
                height: 200,
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
                    _CollectedSummaryCard(
                      onTapRecommendation: () =>
                          _todo('추천 음식 정보는 준비 중이에요.'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CategoryTabs(
                      selected: _category,
                      onChanged: (c) => setState(() => _category = c),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _IngredientGrid(
                      ingredients: ingredients,
                      onTapIngredient: (ing) =>
                          showIngredientDetail(context, ing),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    const _SectionLabel('이 재료로 만들 수 있어요'),
                    const SizedBox(height: AppSpacing.md),
                    _MakeableFoodRow(
                      foods: mockMakeableFoods,
                      onTapFood: (food) =>
                          _todo('${food.name} 정보는 준비 중이에요.'),
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

/// 뒤로가기 + 가운데 정렬 제목 + 잎 장식.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('재료 가방', style: AppTextStyles.h2),
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Leaf(flip: true),
              const SizedBox(width: AppSpacing.xs),
              _Leaf(flip: false),
            ],
          ),
        ],
      ),
    );
  }
}

/// "모은 재료 N개" 요약 카드 — 왼쪽 큰 숫자, 오른쪽 추천 음식 pill + 참새.
class _CollectedSummaryCard extends StatelessWidget {
  const _CollectedSummaryCard({required this.onTapRecommendation});

  final VoidCallback onTapRecommendation;

  @override
  Widget build(BuildContext context) {
    final recommended = recommendedMakeableFood;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Leaf(flip: true),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '모은 재료',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.h1.copyWith(color: AppColors.success),
                    children: [
                      TextSpan(text: '$mockCollectedIngredientCount'),
                      TextSpan(
                        text: '개',
                        style: AppTextStyles.title
                            .copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Container(width: 1, color: AppColors.divider),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommended == null
                        ? '재료를 더 모아볼까요?'
                        : '지금 가진 재료로\n만들 수 있는 음식이 있어요',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (recommended != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _RecommendationPill(
                      label: '추천: ${recommended.name}',
                      onTap: onTapRecommendation,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationPill extends StatelessWidget {
  const _RecommendationPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSelected,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.restaurant_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPressed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 16,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기본 재료 / 지역별 재료 세그먼트 토글.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onChanged});

  final IngredientCategory selected;
  final ValueChanged<IngredientCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final c in IngredientCategory.values)
            Expanded(
              child: _TabButton(
                label: c == IngredientCategory.basic ? '기본 재료' : '지역별 재료',
                selected: c == selected,
                onTap: () => onChanged(c),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.buttonMedium.copyWith(
              color: selected
                  ? AppColors.textOnPrimaryButton
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 재료 4열 그리드.
class _IngredientGrid extends StatelessWidget {
  const _IngredientGrid({
    required this.ingredients,
    required this.onTapIngredient,
  });

  final List<MockIngredient> ingredients;
  final ValueChanged<MockIngredient> onTapIngredient;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: ingredients.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 118,
      ),
      itemBuilder: (context, index) {
        final ing = ingredients[index];
        return _IngredientTile(
          ingredient: ing,
          onTap: () => onTapIngredient(ing),
        );
      },
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.ingredient, required this.onTap});

  final MockIngredient ingredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owned = ingredient.owned;
    return Material(
      color: owned ? AppColors.surface : AppColors.surfaceDisabled,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 미획득 재료는 실루엣처럼 흐리게 (user_flow §5).
              Opacity(
                opacity: owned ? 1 : 0.35,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    ingredient.illustrationPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Symbols.grocery_rounded,
                      size: 28,
                      color: owned
                          ? AppColors.primary
                          : AppColors.iconDisabled,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: owned
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _CountChip(count: ingredient.count),
            ],
          ),
        ),
      ),
    );
  }
}

/// "N개" 개수 칩 — 보유 시 올리브 아웃라인, 미보유 시 흐리게.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final owned = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: owned ? AppColors.surface : Colors.transparent,
        border: Border.all(
          color: owned ? AppColors.primary : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count개',
        style: AppTextStyles.caption.copyWith(
          color: owned ? AppColors.primaryPressed : AppColors.textDisabled,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 왼쪽 정렬 섹션 제목 — 앞에 작은 잎 장식.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.h3),
      ],
    );
  }
}

/// 보유 재료로 만들 수 있는 음식 — 가로 스크롤 카드 리스트.
class _MakeableFoodRow extends StatelessWidget {
  const _MakeableFoodRow({required this.foods, required this.onTapFood});

  final List<MockMakeableFood> foods;
  final ValueChanged<MockMakeableFood> onTapFood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: foods.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final food = foods[index];
          return _MakeableFoodCard(food: food, onTap: () => onTapFood(food));
        },
      ),
    );
  }
}

class _MakeableFoodCard extends StatelessWidget {
  const _MakeableFoodCard({required this.food, required this.onTap});

  final MockMakeableFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final almost = food.status == MakeStatus.almost;
    return SizedBox(
      width: 132,
      child: Material(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.smallButton),
                    child: Container(
                      color: AppColors.surfaceSelected,
                      child: Image.asset(
                        food.illustrationPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(
                            Symbols.dinner_dining_rounded,
                            size: 28,
                            color: AppColors.iconInactive,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      almost ? Symbols.star_rounded : Symbols.check_circle_rounded,
                      size: 16,
                      color: almost
                          ? AppColors.secondaryAccent
                          : AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  almost
                      ? '조금만 보충하면\n만들 수 있어요'
                      : '보유 재료로\n충분히 만들 수 있어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
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
      width: 16,
      height: 16,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 16),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}

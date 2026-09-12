import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_ingredients.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// `<재료 상세 페이지>` (user_flow §5) — 재료 가방에서 재료 하나를 눌렀을 때 뜨는
/// 모달. 재료 이름·보유 개수·재료 특성·사용되는 음식·획득 가능한 장소를 보여준다.
///
/// 뼈대만 구현 — 데이터는 `mock_ingredients` placeholder. "사용되는 음식" /
/// "획득 가능한 장소" 항목 탭 시 스낵바로 안내한다.
///
/// * TODO: 사용되는 음식 탭 → `<음식 정보>` (§4).
/// * TODO: 획득 가능한 장소 탭 → `<장소 정보 페이지>` (§6) / `<방앗간>` 등.
/// * TODO(backend): 재료 상세 조회 API 연동 (mock_ingredients TODO 참고).
Future<void> showIngredientDetail(
  BuildContext context,
  MockIngredient ingredient,
) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x8C1E160E),
    builder: (_) => _IngredientDetailDialog(ingredient: ingredient),
  );
}

class _IngredientDetailDialog extends StatelessWidget {
  const _IngredientDetailDialog({required this.ingredient});

  final MockIngredient ingredient;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.huge,
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: ingredient.name,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CharacteristicsSection(ingredient: ingredient),
                    if (ingredient.usedInFoods.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel('사용되는 음식'),
                      const SizedBox(height: AppSpacing.md),
                      _UsedInFoodsGrid(
                        foods: ingredient.usedInFoods,
                        onTapFood: (food) =>
                            _todo(context, '${food.name} 정보는 준비 중이에요.'),
                      ),
                    ],
                    if (ingredient.sources.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel('획득 가능한 장소'),
                      const SizedBox(height: AppSpacing.md),
                      for (final source in ingredient.sources) ...[
                        _SourceRow(
                          source: source,
                          onTap: () =>
                              _todo(context, '${source.name} 정보는 준비 중이에요.'),
                        ),
                        if (source != ingredient.sources.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                    if (ingredient.usedInFoods.isEmpty &&
                        ingredient.sources.isEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '사용되는 음식 · 획득 장소 정보는 준비 중이에요.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 정렬 제목 + 닫기(X) + 잎 장식.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title, style: AppTextStyles.h2),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Symbols.close_rounded),
                    color: AppColors.iconInactive,
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

/// 재료 일러스트 + "재료 특성" 카드.
class _CharacteristicsSection extends StatelessWidget {
  const _CharacteristicsSection({required this.ingredient});

  final MockIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: ingredient.owned ? 1 : 0.4,
          child: SizedBox(
            width: 108,
            height: 108,
            child: Image.asset(
              ingredient.illustrationPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Symbols.grocery_rounded,
                size: 56,
                color: ingredient.owned
                    ? AppColors.primary
                    : AppColors.iconDisabled,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '재료 특성',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.md),
                _CharRow(
                  icon: Symbols.inventory_2_rounded,
                  label: '보유 수량',
                  trailing: '${ingredient.count}개',
                  trailingColor: ingredient.owned
                      ? AppColors.success
                      : AppColors.textDisabled,
                ),
                const SizedBox(height: AppSpacing.sm),
                _CharRow(
                  icon: Symbols.eco_rounded,
                  label: ingredient.category == IngredientCategory.basic
                      ? '기본 재료'
                      : '지역별 재료',
                ),
                if (ingredient.flavor != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CharRow(
                    icon: Symbols.nutrition_rounded,
                    label: ingredient.flavor!,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _CharRow(
                  icon: Symbols.location_on_rounded,
                  label: ingredient.isRegionalSpecialty
                      ? '${ingredient.specialtyRegion} 특산 재료'
                      : '지역 특산 재료 아님',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CharRow extends StatelessWidget {
  const _CharRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: trailingColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// 왼쪽 정렬 섹션 제목 — 양옆에 작은 잎 장식.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.title),
        const SizedBox(width: AppSpacing.xs),
        _Leaf(flip: true),
      ],
    );
  }
}

class _UsedInFoodsGrid extends StatelessWidget {
  const _UsedInFoodsGrid({required this.foods, required this.onTapFood});

  final List<IngredientFood> foods;
  final ValueChanged<IngredientFood> onTapFood;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: foods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 96,
      ),
      itemBuilder: (context, index) {
        final food = foods[index];
        return _UsedFoodTile(food: food, onTap: () => onTapFood(food));
      },
    );
  }
}

class _UsedFoodTile extends StatelessWidget {
  const _UsedFoodTile({required this.food, required this.onTap});

  final IngredientFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.surfaceSelected,
                    child: Image.asset(
                      food.illustrationPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Symbols.dinner_dining_rounded,
                          size: 22,
                          color: AppColors.iconInactive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onTap});

  final IngredientSource source;
  final VoidCallback onTap;

  IconData get _icon => switch (source.type) {
        IngredientSourceType.market => Symbols.storefront_rounded,
        IngredientSourceType.shop => Symbols.cottage_rounded,
        IngredientSourceType.millReward => Symbols.grain_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSelected,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  source.name,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: AppColors.iconInactive,
              ),
            ],
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

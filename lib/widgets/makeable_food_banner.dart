import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../api/api.dart';
import '../data/makeable_food_watcher.dart';
import '../navigation/root_navigator.dart';
import '../screens/food/ingredient_bag_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// 재료 획득으로 새로 "제작 가능"해진 음식이 생기면 앱 전역 상단에 배너를
/// 띄운다. `main.dart`에서 `MaterialApp.builder`로 한 번만 wiring — 어느
/// 화면에 있든(탭 전환 포함) 항상 최상단에 그려진다.
class MakeableFoodBanner extends StatelessWidget {
  const MakeableFoodBanner({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ?child,
        AnimatedBuilder(
          animation: MakeableFoodWatcher.instance,
          builder: (context, _) {
            final pending = MakeableFoodWatcher.instance.pending;
            if (pending.isEmpty) return const SizedBox.shrink();
            return _Banner(foods: pending);
          },
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.foods});

  final List<Food> foods;

  String get _title {
    final first = foods.first.name;
    return foods.length == 1
        ? '$first, 지금 만들 수 있어요!'
        : '$first 등 ${foods.length}가지 음식을 만들 수 있어요!';
  }

  void _open(BuildContext context) {
    final targetIngredient = foods.first.ingredients.isEmpty
        ? null
        : foods.first.ingredients.first.name;
    MakeableFoodWatcher.instance.dismiss();
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) =>
            IngredientBagScreen(initialIngredientName: targetIngredient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.elevatedCard,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Symbols.celebration_rounded,
                    size: 24,
                    color: AppColors.secondaryAccent,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _GoToBagButton(onTap: () => _open(context)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: MakeableFoodWatcher.instance.dismiss,
                    icon: const Icon(
                      Symbols.close_rounded,
                      size: 18,
                      color: AppColors.iconInactive,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "재료 가방 바로가기" pill 버튼.
class _GoToBagButton extends StatelessWidget {
  const _GoToBagButton({required this.onTap});

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
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Image.asset(
                  'assets/illustrations/icon/ingredient_2.png',
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Symbols.shopping_bag_rounded,
                    size: 16,
                    color: AppColors.primaryPressed,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '재료 가방 바로가기',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryPressed,
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

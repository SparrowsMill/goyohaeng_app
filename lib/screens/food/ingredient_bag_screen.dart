import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/food_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/reward_image.dart';
import 'food_info_screen.dart';
import 'ingredient_detail_sheet.dart';

/// `<재료 가방>` (user_flow §5) — 모은 재료를 확인하는 페이지. 일반 / 고급 /
/// 희귀 / 전설 탭으로 구분하고, 미획득 재료는 실루엣 + 이름, 획득 재료는 보유
/// 개수를 표시한다. 하단에 보유 재료로 만들 수 있는 음식 추천 코너.
///
/// `GET /users/me/ingredients` (스펙 §3.8) + `GET /foods` (스펙 §10.1) 로 실 데이터를
/// 읽는다. 재료 탭 시 실제 `ingredientId` 로 `<재료 상세 페이지>`
/// (`ingredient_detail_sheet.dart`) 모달을 띄운다.
class IngredientBagScreen extends StatefulWidget {
  const IngredientBagScreen({super.key, this.initialIngredientName});

  /// 방문 인증 보상 화면 등에서 특정 재료를 확인하러 넘어올 때, 그 재료가
  /// 속한 등급 탭을 미리 선택해둔다. 목록에서 이름이 일치하는 재료를 찾지
  /// 못하면(실 방문 세션처럼 지급된 재료명을 아직 모르는 경우 등) 기본 탭
  /// (일반)을 그대로 유지한다.
  final String? initialIngredientName;

  @override
  State<IngredientBagScreen> createState() => _IngredientBagScreenState();
}

enum _Category {
  common('COMMON', '일반'),
  uncommon('UNCOMMON', '고급'),
  rare('RARE', '희귀'),
  legendary('LEGENDARY', '전설');

  const _Category(this.rarity, this.label);

  final String rarity;
  final String label;
}

/// 재료 가방 화면의 전체 재료 + 도감과 동일한 음식 목록
/// (하단 "이 재료로 만들 수 있어요" 추천용).
typedef _BagData = ({UserIngredients ingredients, List<Food> foods});

class _IngredientBagScreenState extends State<IngredientBagScreen> {
  /// `ingredient_bg.png`'s native aspect ratio (1588×990) — used to size the
  /// fixed header scene at its full, uncropped height for any screen width,
  /// and to clear that much space before the scrollable content starts.
  static const _kBgAspectRatio = 1588 / 990;

  _Category _category = _Category.common;
  late Future<_BagData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    final targetName = widget.initialIngredientName;
    if (targetName != null) {
      _future.then((data) {
        if (!mounted) return;
        final match = _findByName(data.ingredients.items, targetName);
        final category = _categoryForRarity(match?.rarity);
        if (category != null) setState(() => _category = category);
      }).catchError((_) {});
    }
  }

  static UserIngredient? _findByName(List<UserIngredient> items, String name) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }

  static _Category? _categoryForRarity(String? rarity) {
    if (rarity == null) return null;
    for (final c in _Category.values) {
      if (c.rarity == rarity) return c;
    }
    return null;
  }

  Future<_BagData> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    final results = await Future.wait([
      UserService().getIngredients(),
      FoodService().list(),
    ]);
    return (
      ingredients: results[0] as UserIngredients,
      foods: results[1] as List<Food>,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final bgHeight = MediaQuery.sizeOf(context).width / _kBgAspectRatio;
    final fadeHeight = bgHeight * 0.3;
    // Pull the content block up slightly into the fade zone (not the crisp
    // illustration above it) so it sits a bit closer to the scene without
    // covering more of it.
    final contentClearance = bgHeight - fadeHeight * 0.6;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('재료가방'),
      ),
      // `SizedBox.expand` guarantees the Stack itself fills the screen via a
      // tight constraint from *outside* it, regardless of `fit` or how many
      // children are `Positioned` — needed because every child below is
      // `Positioned` (including the header, so its `SizedBox(height: 44)`
      // isn't force-stretched); with zero non-positioned children, a bare
      // `Stack` with no outer sizing would otherwise collapse to 0×0.
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Fixed background scene, shown in full (not cropped) — stays put
            // while the content below scrolls over it, like the account-center
            // screen's `setting_bg`.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/illustrations/scenes/ingredient_bg.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
            // Soft fade at the scene's bottom edge into the flat app
            // background, so it doesn't cut off abruptly.
            Positioned(
              top: bgHeight - fadeHeight,
              left: 0,
              right: 0,
              height: fadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.appBackground.withValues(alpha: 0),
                        AppColors.appBackground,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: FutureBuilder<_BagData>(
                  future: _future,
                  builder: (context, snapshot) {
                    return LoadingOverlay(
                      loading: snapshot.connectionState != ConnectionState.done,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: contentClearance),
                            Padding(
                              padding: AppBottomNavBar.scrollPadding(
                                context,
                                const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.lg,
                                  AppSpacing.xl,
                                  AppSpacing.xxl,
                                ),
                              ),
                              child: _buildBody(context, snapshot),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<_BagData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      // The LoadingOverlay above already shows the loading pill.
      return const SizedBox(height: AppSpacing.huge);
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '재료 정보를 불러오지 못했어요.';
      return _ErrorState(message: message, onRetry: _reload);
    }

    final data = snapshot.data!;
    final ingredients = data.ingredients.items
        .where((i) => i.rarity == _category.rarity)
        .where((i) => isIngredientOpen(i.name))
        .toList();
    final makeable = data.foods
        .where((food) => food.canMake && FoodCatalog.isOpen(food.name))
        .toList();
    final recommended = makeable.isEmpty ? null : makeable.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CollectedSummaryCard(
          totalQuantity: data.ingredients.totalQuantity,
          totalTypes: data.ingredients.totalTypes,
          recommended: recommended,
          onTapRecommendation: recommended == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FoodInfoScreen(foodId: recommended.id),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CategoryTabs(
          selected: _category,
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: AppSpacing.lg),
        _IngredientGrid(
          ingredients: ingredients,
          onTapIngredient: (ing) => showIngredientDetail(
            context,
            ingredientId: ing.id,
            initialName: ing.name,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        const _SectionLabel('이 재료로 만들 수 있어요'),
        const SizedBox(height: AppSpacing.md),
        _MakeableFoodRow(
          foods: makeable,
          onTapFood: (food) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FoodInfoScreen(foodId: food.id)),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const Icon(
            Symbols.error_outline_rounded,
            size: 32,
            color: AppColors.iconInactive,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

/// "모은 재료 N개" 요약 카드 — 왼쪽 큰 숫자, 오른쪽 추천 음식 pill + 참새.
class _CollectedSummaryCard extends StatelessWidget {
  const _CollectedSummaryCard({
    required this.totalQuantity,
    required this.totalTypes,
    required this.recommended,
    required this.onTapRecommendation,
  });

  final int totalQuantity;
  final int totalTypes;
  final Food? recommended;
  final VoidCallback? onTapRecommendation;

  @override
  Widget build(BuildContext context) {
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
                      TextSpan(text: '$totalQuantity'),
                      TextSpan(
                        text: '개',
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$totalTypes종 보유',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (recommended != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _RecommendationPill(
                      label: '추천: ${recommended!.name}',
                      onTap: onTapRecommendation!,
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

/// 일반 / 고급 / 희귀 / 전설 등급 선택.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onChanged});

  final _Category selected;
  final ValueChanged<_Category> onChanged;

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
          for (final c in _Category.values)
            Expanded(
              child: _TabButton(
                label: c.label,
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

  final List<UserIngredient> ingredients;
  final ValueChanged<UserIngredient> onTapIngredient;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          '이 등급에 등록된 재료가 없어요.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
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

  final UserIngredient ingredient;
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
                  child: RewardImage(
                    name: ingredient.name,
                    folder: RewardAssetFolder.ingredient,
                    networkUrl:
                        ingredient.imageUrl ?? ingredient.illustrationUrl,
                    icon: Symbols.grocery_rounded,
                    color: owned ? AppColors.primary : AppColors.iconDisabled,
                    iconSize: 28,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: owned ? AppColors.textPrimary : AppColors.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _CountChip(count: ingredient.quantity),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: owned ? AppColors.surface : Colors.transparent,
        border: Border.all(color: owned ? AppColors.primary : AppColors.border),
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
  const _MakeableFoodRow({
    required this.foods,
    required this.onTapFood,
  });

  final List<Food> foods;
  final ValueChanged<Food> onTapFood;

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return Text(
        '아직 만들 수 있는 음식이 없어요.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: foods.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final food = foods[index];
          return _MakeableFoodCard(
            food: food,
            onTap: () => onTapFood(food),
          );
        },
      ),
    );
  }
}

class _MakeableFoodCard extends StatelessWidget {
  const _MakeableFoodCard({
    required this.food,
    required this.onTap,
  });

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      child: RewardImage(
                        name: food.name,
                        folder: RewardAssetFolder.dish,
                        networkUrl: food.imageUrl ?? food.illustrationUrl,
                        icon: Symbols.dinner_dining_rounded,
                        color: AppColors.iconInactive,
                        fit: BoxFit.cover,
                        iconSize: 28,
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Symbols.check_circle_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '보유 재료로\n충분히 만들 수 있어요',
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

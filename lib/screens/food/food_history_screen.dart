import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_food_history.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';

/// `<음식 히스토리>` (user_flow §4) — 음식 도감에서 이미 만든 음식을 눌렀을 때.
/// 만든 날짜, 사용된 재료(특별/일반), 특별 재료를 얻은 관광 스팟, 음식의 특징을
/// 보여준다.
///
/// 뼈대만 구현 — 데이터는 `mock_food_history` placeholder. 관광 스팟 탭 →
/// `<장소 정보 페이지>` 는 미구현이라 스낵바로 안내한다.
///
/// * TODO: 관광 스팟 탭 → `<장소 정보 페이지>` (§6).
/// * TODO(asset): 이 화면 배경 scene — 음식 도감과 같은 펼친 책 밴드
///   (`assets/illustrations/scenes/food_dex_bg.png`) 재사용. 별도 파일이 필요하면
///   `food_history_bg.png` 로 교체.
class FoodHistoryScreen extends StatelessWidget {
  const FoodHistoryScreen({super.key, required this.history});

  final FoodHistory history;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _dateText {
    final d = history.madeDate;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}.$m.$day';
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
                    _HeroCard(history: history),
                    const SizedBox(height: AppSpacing.lg),
                    _MadeDateCard(dateText: _dateText),
                    if (history.specialIngredients.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel('사용된 특별 재료'),
                      const SizedBox(height: AppSpacing.md),
                      _WideIngredientRow(items: history.specialIngredients),
                    ],
                    if (history.normalIngredients.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel('일반 재료'),
                      const SizedBox(height: AppSpacing.md),
                      _IngredientGrid(items: history.normalIngredients),
                    ],
                    if (history.sourceSpots.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionLabel('특별 재료를 얻은 관광 스팟'),
                      const SizedBox(height: AppSpacing.md),
                      for (final spot in history.sourceSpots) ...[
                        _SpotCard(
                          spot: spot,
                          onTap: () =>
                              _todo(context, '${spot.name} 정보는 준비 중이에요.'),
                        ),
                        if (spot != history.sourceSpots.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    const _SectionLabel('음식의 특징'),
                    const SizedBox(height: AppSpacing.md),
                    _CharacteristicCard(text: history.characteristic),
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
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Leaf(flip: true),
                const SizedBox(width: AppSpacing.sm),
                Text('음식 히스토리', style: AppTextStyles.h2),
                const SizedBox(width: AppSpacing.sm),
                _Leaf(flip: false),
              ],
            ),
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

/// 음식 일러스트 + 이름 + 설명.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.history});

  final FoodHistory history;

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
              width: 116,
              height: 116,
              color: AppColors.surfaceSelected,
              child: Image.asset(
                history.illustrationPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Symbols.dinner_dining_rounded,
                    size: 40,
                    color: AppColors.iconInactive,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(history.name, style: AppTextStyles.h2),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Leaf(flip: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  history.description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "만든 날짜 ......... 2026.08.15" 카드.
class _MadeDateCard extends StatelessWidget {
  const _MadeDateCard({required this.dateText});

  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              'assets/illustrations/icon/main_calendar_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.calendar_month_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '만든 날짜',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            dateText,
            style: AppTextStyles.numericScore.copyWith(
              fontSize: 18,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// 특별 재료 — 아이콘 + 이름을 가로로 나열한 넓은 카드 3개.
class _WideIngredientRow extends StatelessWidget {
  const _WideIngredientRow({required this.items});

  final List<HistoryIngredient> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _WideIngredientCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _WideIngredientCard extends StatelessWidget {
  const _WideIngredientCard({required this.item});

  final HistoryIngredient item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IngredientImage(item: item, size: 36),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 일반 재료 — 4열 그리드(아이콘 + 이름).
class _IngredientGrid extends StatelessWidget {
  const _IngredientGrid({required this.items});

  final List<HistoryIngredient> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IngredientImage(item: item, size: 32),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 재료 일러스트 — 없으면 범용 아이콘 placeholder.
class _IngredientImage extends StatelessWidget {
  const _IngredientImage({required this.item, required this.size});

  final HistoryIngredient item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        item.illustrationPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Symbols.grocery_rounded,
          size: size * 0.8,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 특별 재료를 얻은 관광 스팟 카드 — 이름 + 설명 + 썸네일.
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, required this.onTap});

  final HistorySpot spot;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.location_on_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      spot.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.smallButton),
                child: Container(
                  width: 72,
                  height: 56,
                  color: AppColors.surfaceSelected,
                  child: Image.asset(
                    spot.thumbnailPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.image_rounded,
                      size: 24,
                      color: AppColors.iconInactive,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "음식의 특징" 문단 카드.
class _CharacteristicCard extends StatelessWidget {
  const _CharacteristicCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(height: 1.7),
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

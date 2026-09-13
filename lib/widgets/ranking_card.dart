import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../api/api.dart' show Category;
import '../data/mock_map_regions.dart' show gapIndexAccent;
import '../data/mock_region_ranking.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'favorite_star_button.dart';
import 'gap_index_info_dialog.dart';

/// Category + sort dropdowns (side by side) + hint line, pinned above a
/// scrolling GAP 랭킹 list. Shared by `<지역별 랭킹>`(`RegionRankingScreen`)
/// and `<전체 랭킹>`(`RankingScreen`) so both look identical.
class RankingFilterBar extends StatelessWidget {
  const RankingFilterBar({
    super.key,
    required this.category,
    required this.categories,
    required this.onCategory,
    required this.descending,
    required this.onSort,
    required this.hint,
  });

  /// 선택된 카테고리 id, `null` == 전체.
  final int? category;

  /// `GET /categories` level 1.
  final List<Category> categories;
  final ValueChanged<int?> onCategory;
  final bool descending;
  final ValueChanged<bool> onSort;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PillDropdown<int?>(
                  value: category,
                  onChanged: onCategory,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PillDropdown<bool>(
                  value: descending,
                  onChanged: (v) => onSort(v ?? true),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('갭지수 높은순')),
                    DropdownMenuItem(value: false, child: Text('갭지수 낮은순')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const GapIndexInfoButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// A compact pill-styled dropdown used by [RankingFilterBar] and any other
/// region/카테고리 picker that wants the same look.
class PillDropdown<T> extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;

  /// `null` disables the dropdown (e.g. 시군구 before a 시도 is picked).
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          icon: const Icon(Symbols.keyboard_arrow_down_rounded, size: 18),
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          dropdownColor: AppColors.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// One ranked GAP 스팟 row — rank badge, name, 즐겨찾기 별, 갭지수, category/
/// ingredient/방문·영업 tags, and (when [selected]) a "자세히 보기" button.
/// Shared by `<지역별 랭킹>` and `<전체 랭킹>`.
class RankingCard extends StatelessWidget {
  const RankingCard({
    super.key,
    required this.rank,
    required this.spot,
    required this.onTap,
    required this.onDetail,
    this.selected = false,
  });

  final int rank;
  final MockTouristSpot spot;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // The spot's map-pin colour (갭지수 scale) — used for the row's pin, the
    // emphasised 갭지수 text, and (when selected) the border / 자세히 보기 button.
    final accent = gapIndexAccent(spot.gapIndex);
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? AppColors.textOnPrimaryButton
            : AppColors.textPrimary;

    return Material(
      color: selected
          ? Color.alphaBlend(accent.withValues(alpha: 0.09), AppColors.surface)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RankBadge(rank: rank),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        spot.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: FavoriteStarButton(spotName: spot.name, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _GapValue(gapIndex: spot.gapIndex, accent: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Category · ingredient · visit-verify · business status, all
              // on one line; scrolls sideways rather than wrapping.
              Padding(
                padding: const EdgeInsets.only(left: 26 + AppSpacing.sm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      _Tag(label: spot.categoryName ?? spot.category.label),
                      const SizedBox(width: AppSpacing.xs),
                      _IngredientTag(ingredient: spot.ingredient),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusChip(
                        label: spot.visitVerifiable ? '방문 인증 가능' : '방문 인증 불가',
                        tone: spot.visitVerifiable
                            ? _ChipTone.positive
                            : _ChipTone.muted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusChip(
                        label: spot.businessStatus.label,
                        tone: switch (spot.businessStatus) {
                          BusinessStatus.open => _ChipTone.positive,
                          BusinessStatus.closed => _ChipTone.muted,
                          BusinessStatus.holiday => _ChipTone.negative,
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.xs),
                _DetailButton(
                  onTap: onDetail,
                  color: accent,
                  foreground: onAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "자세히 보기" — appears on the selected ranking card, opens `<장소 정보>`.
/// Filled with the spot's map-pin colour so the card reads as "this pin".
class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.onTap,
    required this.color,
    required this.foreground,
  });

  final VoidCallback onTap;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Symbols.arrow_forward_rounded, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  // Medal colors are inherently gold/silver/bronze — not design tokens.
  // Used only as the fallback if the medal art fails to load.
  static const _medalColors = {
    1: Color(0xFFC9A34E),
    2: Color(0xFFACACAC),
    3: Color(0xFFB58150),
  };

  static const _medalAsset = {
    1: 'assets/illustrations/ranking/first.png',
    2: 'assets/illustrations/ranking/second.png',
    3: 'assets/illustrations/ranking/third.png',
  };

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return SizedBox(
        width: 26,
        child: Center(
          child: Text(
            '$rank',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final color = _medalColors[rank]!;
    return Image.asset(
      _medalAsset[rank]!,
      width: 26,
      height: 26,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textOnPrimaryButton,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The 갭지수, emphasised with the scale colour: a filled pin + a bold coloured
/// number, shown at the card's top-right.
class _GapValue extends StatelessWidget {
  const _GapValue({required this.gapIndex, required this.accent});

  final int gapIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.location_on_rounded, size: 18, fill: 1, color: accent),
        const SizedBox(width: 2),
        Text(
          '갭지수 $gapIndex',
          style: AppTextStyles.bodyMedium.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.iconAsset});

  final String label;
  final IconData? icon;

  /// Illustration asset shown instead of [icon] (takes precedence).
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            Image.asset(
              iconAsset!,
              width: 15,
              height: 15,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.eco_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 3),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IngredientTag extends StatelessWidget {
  const _IngredientTag({required this.ingredient});

  final String? ingredient;

  @override
  Widget build(BuildContext context) {
    if (ingredient == null) {
      return const _Tag(label: '획득 재료 없음', icon: Symbols.do_not_disturb_on_rounded);
    }
    return _Tag(
      label: '$ingredient 획득 가능',
      iconAsset: 'assets/illustrations/icon/ingredient_4.png',
    );
  }
}

enum _ChipTone { positive, muted, negative }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _ChipTone.positive => (AppColors.successBackground, AppColors.success),
      _ChipTone.muted => (AppColors.surfaceDisabled, AppColors.textSecondary),
      _ChipTone.negative => (AppColors.errorBackground, AppColors.error),
    };
    return Container(
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

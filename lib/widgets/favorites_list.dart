import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/favorites.dart';
import '../data/mock_map_regions.dart' show gapIndexAccent;
import '../data/mock_region_ranking.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'favorite_star_button.dart';

/// The favorites list body — a "즐겨찾기 N곳" header, a 시/군/구 filter, then a
/// row per favorited place (each keeps its star for in-place removal). Sized by
/// its parent; used as the slide-up panel over the `<지도>` vector map.
///
/// Tapping a row **selects** it — the parent pans/zooms the map behind the panel
/// to that spot at the current drill stage (no navigation). The selected row
/// grows a "자세히 보기" button that opens `<장소 정보>`.
class FavoritesList extends StatefulWidget {
  const FavoritesList({
    super.key,
    required this.onFocusSpot,
    required this.onOpenDetail,
  });

  /// A row was tapped (freshly selected) — move the map to this spot. The parent
  /// ignores spots with no coordinates.
  final ValueChanged<MockTouristSpot> onFocusSpot;

  /// "자세히 보기" on the selected row — open `<장소 정보>`.
  final ValueChanged<MockTouristSpot> onOpenDetail;

  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

/// 시/군/구 name a spot belongs to — the 2nd address token ("담양군",
/// "전주시"), used both as the filter chip label and its key.
String _sigunguOf(MockTouristSpot spot) {
  final parts = spot.address.split(' ');
  return parts.length > 1 ? parts[1] : parts.first;
}

class _FavoritesListState extends State<FavoritesList> {
  /// `null` == 전체.
  String? _sigungu;

  /// Name of the selected row, or `null`. Re-tapping it deselects.
  String? _selectedName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Favorites.instance,
      builder: (context, _) {
          final all = [for (final f in Favorites.instance.spots()) f.spot];
          final regions = <String>{for (final s in all) _sigunguOf(s)}.toList()
            ..sort();
          // A removal may have emptied the chosen region — fall back to 전체.
          final active =
              _sigungu != null && regions.contains(_sigungu) ? _sigungu : null;
          final spots = active == null
              ? all
              : [for (final s in all) if (_sigunguOf(s) == active) s];
          // Selection may have been un-favorited or filtered out.
          final selectedName =
              spots.any((s) => s.name == _selectedName) ? _selectedName : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.star_rounded,
                      size: 20,
                      fill: 1,
                      color: AppColors.secondaryAccent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('즐겨찾기 ${all.length}곳', style: AppTextStyles.title),
                  ],
                ),
              ),
              if (regions.length > 1)
                _SigunguFilter(
                  regions: regions,
                  selected: active,
                  onChanged: (value) => setState(() => _sigungu = value),
                ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: spots.isEmpty
                    ? Center(
                        child: Text(
                          '아직 즐겨찾기한 장소가 없어요.',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        itemCount: spots.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: AppSpacing.xl,
                          endIndent: AppSpacing.xl,
                          color: AppColors.divider,
                        ),
                        itemBuilder: (_, i) {
                          final spot = spots[i];
                          return _FavoriteRow(
                            spot: spot,
                            selected: spot.name == selectedName,
                            onTap: () {
                              final select = _selectedName != spot.name;
                              setState(() =>
                                  _selectedName = select ? spot.name : null);
                              if (select) widget.onFocusSpot(spot);
                            },
                            onDetail: () => widget.onOpenDetail(spot),
                          );
                        },
                      ),
              ),
            ],
          );
      },
    );
  }
}

/// Horizontally scrolling "전체 · 담양군 · 전주시 …" filter chips.
class _SigunguFilter extends StatelessWidget {
  const _SigunguFilter({
    required this.regions,
    required this.selected,
    required this.onChanged,
  });

  final List<String> regions;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String? value})>[
      (label: '전체', value: null),
      for (final r in regions) (label: r, value: r),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.md,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final on = selected == items[i].value;
          return Material(
            color: on ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => onChanged(items[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  items[i].label,
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: on
                        ? AppColors.textOnPrimaryButton
                        : AppColors.primaryPressed,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.spot,
    required this.selected,
    required this.onTap,
    required this.onDetail,
  });

  final MockTouristSpot spot;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    // "전라남도 담양군" — first two address tokens are the 시도 + 시군구.
    final region = spot.address.split(' ').take(2).join(' ');
    final accent = gapIndexAccent(spot.gapIndex);
    return Material(
      color: selected ? AppColors.surfaceSelected : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.location_on_rounded,
                      size: 22, fill: 1, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$region · ${spot.category.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '갭지수 ${spot.gapIndex}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FavoriteStarButton(spotName: spot.name, size: 22),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.md),
                _DetailButton(onTap: onDetail),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "자세히 보기" — shown on the selected favorite row, opens `<장소 정보>`.
class _DetailButton extends StatelessWidget {
  const _DetailButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: AppColors.textOnPrimaryButton,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Symbols.arrow_forward_rounded,
                    size: 18, color: AppColors.textOnPrimaryButton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

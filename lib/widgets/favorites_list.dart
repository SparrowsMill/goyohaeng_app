import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/favorites.dart';
import '../data/mock_map_regions.dart' show gapIndexColor;
import '../data/mock_region_ranking.dart';
import '../screens/place/place_info_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'favorite_star_button.dart';

/// The favorites list body — a "즐겨찾기 N곳" header, a 시/군/구 filter, then a
/// row per favorited place (each keeps its star for in-place removal; tapping a
/// row opens `<장소 정보>`). Sized by its parent; used as the bottom half of the
/// split `<지도>` view.
class FavoritesList extends StatefulWidget {
  const FavoritesList({super.key});

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
                        itemBuilder: (_, i) => _FavoriteRow(
                          spot: spots[i],
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaceInfoScreen(spot: spots[i]),
                            ),
                          ),
                        ),
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
  const _FavoriteRow({required this.spot, required this.onOpen});

  final MockTouristSpot spot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // "전라남도 담양군" — first two address tokens are the 시도 + 시군구.
    final region = spot.address.split(' ').take(2).join(' ');
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: gapIndexColor(spot.gapIndex),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                      '$region · ${spot.category.label} · 갭지수 ${spot.gapIndex}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FavoriteStarButton(spotName: spot.name, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

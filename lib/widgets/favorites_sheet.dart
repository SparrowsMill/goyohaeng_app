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

/// Slides up a half-screen list of every favorited place. Each row keeps its
/// star so it can be removed in place; tapping a row opens `<장소 정보>`.
Future<void> showFavoritesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.15),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (_) => const _FavoritesSheet(),
  );
}

class _FavoritesSheet extends StatelessWidget {
  const _FavoritesSheet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: AnimatedBuilder(
        animation: Favorites.instance,
        builder: (context, _) {
          final spots = [for (final f in Favorites.instance.spots()) f.spot];
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
                    Text('즐겨찾기 ${spots.length}곳', style: AppTextStyles.title),
                  ],
                ),
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
                          onOpen: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            nav.push(
                              MaterialPageRoute(
                                builder: (_) => PlaceInfoScreen(spot: spots[i]),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
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

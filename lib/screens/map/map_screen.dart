import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_map_regions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../ranking/region_ranking_screen.dart';

/// `<지도>` (user_flow §6) — the country split into six broad regions, each
/// shaded by its average 갭지수. Reached two ways: the "지도 열기" button under
/// the mill-home TOP 3 list, and the 지도 bottom-nav tab. Tapping a region
/// opens its `<지역별 랭킹 페이지>`; the "갭지수란?" button opens the explainer.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _openRegion(BuildContext context, MockMapRegion region) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegionRankingScreen(
          regionKey: region.key,
          regionName: region.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('지도'),
        actions: const [_NotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('어디로 떠나볼까요?', style: AppTextStyles.h2),
                const SizedBox(width: AppSpacing.xs),
                Image.asset(
                  'assets/illustrations/sparrow/sparrow_default.png',
                  width: 30,
                  height: 30,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(width: 30),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '지역별 갭지수와 숨은 관광 스팟을 둘러보세요',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Align(
              alignment: Alignment.centerRight,
              child: _GapLegend(),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Align(
              alignment: Alignment.centerRight,
              child: GapIndexInfoButton(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _RegionMap(onRegionTap: (region) => _openRegion(context, region)),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).maybePop();
          }
          // * TODO: 랭킹/기록 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }
}

/// Notification bell with the unread dot, mirroring the mill-home top bar.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        // * TODO(backend): 알림 목록 화면 연동 필요
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Symbols.notifications_rounded),
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      color: AppColors.textPrimary,
    );
  }
}

/// Compact "낮음 —— 높음" scale shown above the map.
class _GapLegend extends StatelessWidget {
  const _GapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('낮음', style: AppTextStyles.caption),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 96,
          height: 10,
          decoration: BoxDecoration(
            gradient: gapIndexGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('높음', style: AppTextStyles.caption),
      ],
    );
  }
}

/// The watercolor map, assembled from the six `full_map/<key>_map.png`
/// cutouts. Each cutout is neutral (light warm grey) and gets tinted at
/// runtime by its 갭지수 via [gapIndexColor] + [BlendMode.modulate], so the
/// map's colors always track the legend and survive a theme change.
///
/// Layout comes entirely from the art: each region is placed by its
/// [MockMapRegion.artRect] within [mapCompositionRect], which also sets the
/// overall aspect ratio. Only the six `artTopLeft` offsets are hand-tuned.
///
/// Tap targets are each region's (rectangular) bounding box — good enough
/// for six chunky regions; where two boxes overlap, the one painted later
/// (further down [mockMapRegions]) wins.
class _RegionMap extends StatelessWidget {
  const _RegionMap({required this.onRegionTap});

  final ValueChanged<MockMapRegion> onRegionTap;

  @override
  Widget build(BuildContext context) {
    final bounds = mapCompositionRect();

    return AspectRatio(
      aspectRatio: bounds.width / bounds.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / bounds.width;
          Rect place(Rect artRect) => Rect.fromLTWH(
                (artRect.left - bounds.left) * scale,
                (artRect.top - bounds.top) * scale,
                artRect.width * scale,
                artRect.height * scale,
              );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final region in mockMapRegions)
                Positioned.fromRect(
                  rect: place(region.artRect),
                  child: Semantics(
                    button: true,
                    label: '${region.displayName} 지역, 평균 갭지수 '
                        '${region.avgGapIndex}, 관광 스팟 ${region.spotCount}곳',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onRegionTap(region),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          gapIndexColor(region.avgGapIndex),
                          BlendMode.modulate,
                        ),
                        child: Image.asset(
                          region.asset,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final region in mockMapRegions)
                Positioned.fromRect(
                  rect: place(region.artRect),
                  child: IgnorePointer(
                    // OverflowBox both positions the label (its `alignment`
                    // IS `labelAlignment`) and lets it spill past a small
                    // region's box without tripping layout asserts. The
                    // parent Stack is Clip.none so the spill still paints.
                    child: OverflowBox(
                      alignment: region.labelAlignment,
                      minWidth: 0,
                      maxWidth: double.infinity,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: _RegionLabel(region: region),
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

/// The region name + 평균 갭지수 / 관광 스팟 lines drawn over each blob (the
/// art carries no baked text). Text color flips to light on the darker
/// (higher-갭지수) regions; a soft counter-colored shadow keeps it legible.
class _RegionLabel extends StatelessWidget {
  const _RegionLabel({required this.region});

  final MockMapRegion region;

  @override
  Widget build(BuildContext context) {
    final onDark = ThemeData.estimateBrightnessForColor(
          gapIndexColor(region.avgGapIndex),
        ) ==
        Brightness.dark;
    final color = onDark ? AppColors.surface : AppColors.textPrimary;
    final shadows = [
      Shadow(
        color: (onDark ? Colors.black : AppColors.surface).withValues(alpha: 0.5),
        blurRadius: 3,
      ),
    ];
    final s = region.labelScale;
    final nameStyle = AppTextStyles.h3.copyWith(
      color: color,
      shadows: shadows,
      fontSize: (AppTextStyles.h3.fontSize ?? 20) * s,
    );
    final statStyle = AppTextStyles.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
      shadows: shadows,
      fontSize: (AppTextStyles.caption.fontSize ?? 12) * s,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(region.displayName, style: nameStyle),
        const SizedBox(height: 2),
        Text('평균 갭지수 ${region.avgGapIndex}', style: statStyle),
        Text('관광 스팟 ${region.spotCount}곳', style: statStyle),
      ],
    );
  }
}

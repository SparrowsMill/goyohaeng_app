import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_regions.dart';
import '../../data/mock_user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../account/account_center_screen.dart';
import '../map/map_screen.dart';

/// Mill home ("방앗간") screen — the app's main landing tab. `_TopBar` (logo +
/// notifications) is persistent, like the bottom nav. `_MillHeader` below it
/// (background scene + greeting + sparrow + speech bubble) scrolls away with
/// the rest of the content like any other section.
class MillHomeScreen extends StatelessWidget {
  const MillHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _MillHeader(),
                      // Overlaps up into the header banner instead of
                      // sitting flush below it.
                      const Positioned(
                        left: AppSpacing.xl,
                        right: AppSpacing.xl,
                        bottom: -40,
                        child: _StatBar(),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      100,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('어디로 떠나볼까요?', style: AppTextStyles.h2),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '지역별 방앗간과 숨은 장소를 둘러보세요',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Shifts the whole left column (list + button)
                                  // down relative to the map. To move only the
                                  // text inside the frame, use
                                  // `_MillRegionList._contentTopInset` instead.
                                  SizedBox(height: 0),
                                  _MillRegionList(),
                                  SizedBox(height: AppSpacing.sm),
                                  _OpenMapButton(),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const Expanded(
                              flex: 6,
                              child: _MillMap(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Material(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.primaryButton),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.primaryButton),
                              onTap: () {
                                // * TODO(backend): 내 음식 목록 화면 연동 필요
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/illustrations/icon/main_meal_icon.png',
                                    width: 50,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    '내 음식 보기',
                                    style: AppTextStyles.buttonLarge.copyWith(
                                      color: AppColors.textOnPrimaryButton,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          }
          // * TODO: 랭킹/기록 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }
}

/// Persistent top bar (logo + notification bell) — stays on screen at all
/// times, like the bottom navigation, unlike `_MillHeader` below it which
/// scrolls away with the page.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text('고요행', style: AppTextStyles.h3),
            const SizedBox(width: 4),
            Transform.rotate(
              angle: 0.3,
              child: Image.asset(
                'assets/branding/leaf_ornament.png',
                width: 16,
                height: 16,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                // * TODO(backend): 알림 목록 화면 연동 필요
              },
              icon: const Icon(Symbols.notifications_rounded),
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed-size banner (not full-bleed background, not a sticky header — it
/// scrolls away with the page): `mill_bg.png` behind the greeting, with the
/// sparrow + its speech bubble grouped together on top of it.
class _MillHeader extends StatelessWidget {
  const _MillHeader();

  static const _height = 340.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.largeCard),
        bottomRight: Radius.circular(AppRadius.largeCard),
      ),
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/illustrations/scenes/mill_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '좋은 오후예요, ',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '${mockUserProfile.name}!',
                      style: AppTextStyles.h1,
                    ),
                  ],
                ),
              ),
            ),
            // Sparrow + speech bubble as one attached group. Tapping the
            // sparrow opens the account center ("마이페이지") — the bubble
            // doubles as the tap hint for that.
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Align(
                // x: -1 = left edge, 0 = centered, 1 = right edge.
                alignment: const Alignment(-0.3, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SpeechBubble(text: '참새를 눌러\n마이페이지로\n이동해요'),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountCenterScreen(),
                        ),
                      ),
                      child: const Image(
                        image: AssetImage(
                          'assets/illustrations/sparrow/sparrow_default.png',
                        ),
                        width: 140,
                      ),
                    ),
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

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  // Adjust this to change how see-through the bubble (and its tail, below,
  // which reads the same constant) are.
  static const _opacity = 0.6;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: _opacity),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: _BubbleTailPainter(opacity: _opacity),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surface.withValues(alpha: opacity);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatBar extends StatelessWidget {
  const _StatBar();

  static const _opacity = 0.85;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        // Between appBackground (warm cream) and surface (near-white) —
        // brighter than the page background instead of blending flush into
        // it, but without going back to a stark white card.
        color: Color.lerp(AppColors.appBackground, AppColors.surface, 1.0)!
            .withValues(alpha: _opacity),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              iconAsset: 'assets/illustrations/icon/main_calendar_icon.png',
              label: '이번 달 방문',
              value: '${mockUserProfile.monthlyVisitCount}곳',
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(
              iconAsset: 'assets/illustrations/icon/main_collected_icon.png',
              label: '모은 재료',
              value: '${mockUserProfile.collectedIngredientCount}개',
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(
              iconAsset: 'assets/illustrations/icon/main_verified_icon.png',
              label: '인증 완료',
              value: '${mockUserProfile.verifiedStampCount}회',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(iconAsset, width: 50, height: 50),
        const SizedBox(width: AppSpacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Top 3 regions by visit ratio (visited/total), each with its
/// `mill_list/mill_<regionKey>.png` symbol and Korean display name.
class _MillRegionList extends StatelessWidget {
  const _MillRegionList();

  /// Native pixel ratio of `main_mill_list.png` (858 × 1177). The card box is
  /// locked to this so the baked frame renders undistorted with `BoxFit.fill`
  /// — keep it in sync whenever the art is re-exported at a new size.
  static const _frameAspectRatio = 858 / 1177;

  /// Headroom above the text, as a fraction of the frame height, to clear the
  /// "방앗간 수" banner baked into the top of `main_mill_list.png`. Fraction
  /// (not px) so it holds when the card is resized. Bump it to drop the text
  /// lower inside the frame.
  static const _contentTopFraction = 0.16;

  /// Left / right / bottom inset from the image edge to the content.
  static const _sideInset = AppSpacing.lg;
  static const _bottomInset = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final topThree = [...mockRegionProgress]
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    return AspectRatio(
      aspectRatio: _frameAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The card frame is the baked `main_mill_list.png` image — it
          // replaces the drawn border/fill/shadow. The dynamic TOP 3 rows
          // are composited on top in code.
          Image.asset(
            'assets/illustrations/map/main_mill_list.png',
            fit: BoxFit.fill,
          ),
          LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.fromLTRB(
                _sideInset,
                constraints.maxHeight * _contentTopFraction,
                _sideInset,
                _bottomInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최다 방문 지역 TOP 3',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < 3 && i < topThree.length; i++) ...[
                    if (i != 0) const SizedBox(height: AppSpacing.sm),
                    _MillRegionRow(rank: i + 1, region: topThree[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MillRegionRow extends StatelessWidget {
  const _MillRegionRow({required this.rank, required this.region});

  final int rank;
  final MockRegionProgress region;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textOnPrimaryButton,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Image.asset(
          region.assetPath,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(width: 32, height: 32),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Fixed-width name slot so the fraction always sits at the
                  // same x regardless of name length (2~4 Korean chars).
                  SizedBox(
                    width: 60,
                    child: Text(
                      region.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs), // name ↔ fraction gap
                  Text(
                    '${region.visited}/${region.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Visualizes the visited/total ratio the fraction above states.
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6, // bar length (0~1 of the row width)
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: region.ratio,
                    minHeight: 2, // bar thickness
                    backgroundColor: AppColors.surfaceSelected,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill button beneath the region list, filling the space left over now
/// that the list is no longer stretched to match the map's height.
class _OpenMapButton extends StatelessWidget {
  const _OpenMapButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        ),
        child: Ink(
          decoration: const BoxDecoration(
            // Same gradient as the "내 음식 보기" CTA, so the two share a
            // color identity.
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondaryAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '지도 열기',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.textOnPrimaryButton),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Symbols.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textOnPrimaryButton,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Korea watercolor map with its static badge pins baked in
/// (`main_map.png`), plus the current/selected-location marker
/// (`cur_position_icon.png`) composited on top since its position varies.
class _MillMap extends StatelessWidget {
  const _MillMap();

  /// Native pixel ratio of `main_map.png` (1073 × 1466) — the box matches it
  /// so `BoxFit.cover` fills without cropping. Keep in sync on re-export.
  static const _mapAspectRatio = 1073 / 1466;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mapAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/illustrations/map/main_map.png',
              fit: BoxFit.cover,
            ),
            Align(
              alignment: const Alignment(-0.1, 0.15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/illustrations/map/cur_position_icon.png',
                    width: 40,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppShadows.card,
                    ),
                    child: Text(
                      '현재 위치',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

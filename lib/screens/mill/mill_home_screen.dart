import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../data/mock_user.dart';
import '../../data/mock_visits.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/mini_korea_map.dart';
import '../account/account_center_screen.dart';
import '../map/map_screen.dart';
import '../place/place_info_screen.dart';

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
                          '내 위치 주변의 갭지수와 다녀온 곳을 한눈에',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _HomeMapCard(),
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
        Image.asset(iconAsset, width: 44, height: 44),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The home mini-map card — a 시도-level slice of the vector map cropped to the
/// user's location (갭지수 colours + "you are here" dot), an "지도 열기" hint,
/// and a short list of already-visited spots. The whole map area opens `<지도>`.
class _HomeMapCard extends StatelessWidget {
  const _HomeMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 172,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const MiniKoreaMap(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    ),
                  ),
                ),
                const Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: _OpenMapPill(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: _VisitedList(),
          ),
        ],
      ),
    );
  }
}

/// "지도 열기 ›" affordance pinned to the mini-map corner (not itself a button —
/// the whole map area is tappable).
class _OpenMapPill extends StatelessWidget {
  const _OpenMapPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondaryAccent],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '지도 열기',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnPrimaryButton,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(
            Symbols.chevron_right_rounded,
            size: 14,
            color: AppColors.textOnPrimaryButton,
          ),
        ],
      ),
    );
  }
}

/// The "다녀온 곳" mini-list inside the home map card.
class _VisitedList extends StatelessWidget {
  const _VisitedList();

  @override
  Widget build(BuildContext context) {
    final spots = mockVisitedSpots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.where_to_vote_rounded,
              size: 16,
              color: AppColors.success,
              fill: 1,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '다녀온 관광 스팟 ${spots.length}곳',
              style:
                  AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (spots.isEmpty)
          Text(
            '아직 다녀온 곳이 없어요.',
            style: AppTextStyles.caption,
          )
        else
          for (final spot in spots.take(4)) ...[
            _VisitedRow(spot: spot),
            if (spot != spots.take(4).last)
              const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _VisitedRow extends StatelessWidget {
  const _VisitedRow({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final region = spot.address.split(' ').take(2).join(' ');
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.smallButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: gapIndexColor(spot.gapIndex),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  spot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                region,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

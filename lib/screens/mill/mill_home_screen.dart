import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_sparrow.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/mini_korea_map.dart';
import '../food/my_food_screen.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';
import '../sparrow/sparrow_screen.dart';

/// Mill home ("방앗간") screen — the app's main landing tab. `_TopBar` (logo +
/// notifications) is persistent, like the bottom nav. `_MillHeader` below it
/// (background scene + greeting + sparrow + speech bubble) scrolls away with
/// the rest of the content like any other section.
class MillHomeScreen extends StatefulWidget {
  const MillHomeScreen({super.key});

  @override
  State<MillHomeScreen> createState() => _MillHomeScreenState();
}

class _MillHomeScreenState extends State<MillHomeScreen> {
  @override
  void initState() {
    super.initState();
    // 방앗간에 들어올 때마다 스탯을 최신화 (방문 인증·음식 만들기 후 반영).
    DashboardStore.instance.refresh();
  }

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
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: MyFoodScreen.routeName,
                                  ),
                                  builder: (_) => const MyFoodScreen(),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/illustrations/icon/dish.png',
                                    width: 40,
                                    height: 40,
                                    errorBuilder:
                                        (context, error, stackTrace) => const Icon(
                                      Symbols.soup_kitchen_rounded,
                                      size: 24,
                                      color: AppColors.textOnPrimaryButton,
                                    ),
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
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
          // * TODO: 랭킹 탭 — 해당 화면 구현 후 연결
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
        padding: const EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xs,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/branding/app_logo.png',
              height: 50,
              errorBuilder: (context, error, stackTrace) =>
                  Text('고요행', style: AppTextStyles.h3),
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

  static const _height = 372.0;

  /// 로그인 사용자 이름 + "님". 프로필을 아직 못 받았으면 중립 호칭.
  String _greetingName() {
    final name = AuthStore.instance.me?.realName;
    return (name == null || name.isEmpty) ? '여행자님' : '$name님';
  }

  void _openSparrow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SparrowScreen()),
    );
  }

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
              'assets/illustrations/scenes/main_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
                      text: '${_greetingName()}!',
                      style: AppTextStyles.h1,
                    ),
                  ],
                ),
              ),
            ),
            // Sparrow + speech bubble as one attached group — decorative only.
            // Navigation to the sparrow profile is via the button below.
            Positioned(
              top: 114,
              left: 0,
              right: 0,
              child: Align(
                // x: -1 = left edge, 0 = centered, 1 = right edge.
                alignment: const Alignment(-0.6, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(-30, 0),
                      child: const _SpeechBubble(
                        text: '오늘도\n좋은 재료를 찾아\n떠나볼까요?',
                      ),
                    ),
                    Image.asset(
                      'assets/illustrations/sparrow/sparrow_default.png',
                      width: 132,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Symbols.flutter_dash_rounded,
                        size: 88,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Sparrow level card — overlaps the scene on the left, below the
            // greeting.
            const Positioned(
              left: 184,
              top: 184,
              child: _SparrowLevelCard(),
            ),
            // "마이페이지로 이동" button. Kept clear of the `_StatBar` that
            // overlaps up into the banner bottom.
            Positioned(
              right: AppSpacing.md,
              bottom: 34,
              child: Material(
                color: AppColors.textPrimary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => _openSparrow(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '마이페이지로 이동',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textOnPrimaryButton,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Symbols.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textOnPrimaryButton,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sparrow level indicator on the mill-home header — no card frame, just the
/// profile avatar + "참새 Lv.N" name, with the XP bar directly below.
class _SparrowLevelCard extends StatelessWidget {
  const _SparrowLevelCard();

  @override
  Widget build(BuildContext context) {
    final p = mockSparrowProfile;
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceSelected,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/illustrations/sparrow/sparrow_profile.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.flutter_dash_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _OutlinedText('참새 Lv.${p.level}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 116,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.textPrimary, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: p.xpProgress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceSelected,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.secondaryAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White text with a black outline — for labels sitting directly on the scene
/// image where a plain fill wouldn't stay readable.
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700);
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = AppColors.textPrimary,
          ),
        ),
        Text(
          text,
          style: base.copyWith(color: AppColors.textOnPrimaryButton),
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  // Adjust this to change how see-through the bubble (and its tail, below,
  // which reads the same constant) are.
  static const _opacity = 1.0;

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
      child: ListenableBuilder(
        listenable: DashboardStore.instance,
        builder: (context, _) {
          final d = DashboardStore.instance.data;
          String v(int? n) => n == null ? '–' : '$n';
          return Row(
            children: [
              Expanded(
                child: _StatItem(
                  iconAsset: 'assets/illustrations/icon/calendar.png',
                  fallbackIcon: Symbols.calendar_month_rounded,
                  label: '이번 달 방문',
                  value: '${v(d?.monthlyVisitCount)}곳',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  iconAsset: 'assets/illustrations/icon/ingredient.png',
                  fallbackIcon: Symbols.shopping_bag_rounded,
                  label: '모은 재료',
                  value: '${v(d?.ingredientCount)}개',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatItem(
                  iconAsset: 'assets/illustrations/icon/verified.png',
                  fallbackIcon: Symbols.verified_rounded,
                  label: '인증 완료',
                  value: '${v(d?.verifiedVisitCount)}회',
                ),
              ),
            ],
          );
        },
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
    required this.fallbackIcon,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final IconData fallbackIcon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          iconAsset,
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, size: 24, color: AppColors.primary),
        ),
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

/// The home mini-map card — the live `<지도>` vector map cropped to the user's
/// location (갭지수 colours + 지역 이름 + "you are here" dot). A compact "방문
/// TOP 3" panel sits in the top-left corner; the "지도 열기" button in the
/// bottom-right.
class _HomeMapCard extends StatelessWidget {
  const _HomeMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const MiniKoreaMap(),
          const Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _TopVisitedPanel(),
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _OpenMapButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "방문 TOP 3" card — `/users/me/dashboard`의 `topRegions` (방문 인증
/// 횟수 상위 지역), tucked into the top-left corner of the mini-map frame.
class _TopVisitedPanel extends StatelessWidget {
  const _TopVisitedPanel();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DashboardStore.instance,
      builder: (context, _) {
        final top =
            (DashboardStore.instance.data?.topRegions ?? const <DashboardRegion>[])
                .take(3)
                .toList();
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '방문 TOP 3',
                style:
                    AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (top.isEmpty)
                Text(
                  '아직 방문 인증이 없어요',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                )
              else
                for (var i = 0; i < top.length; i++) ...[
                  if (i != 0) const SizedBox(height: 3),
                  _TopVisitedRow(rank: i + 1, region: top[i]),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _TopVisitedRow extends StatelessWidget {
  const _TopVisitedRow({required this.rank, required this.region});

  final int rank;
  final DashboardRegion region;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
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
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          region.regionName,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${region.visitCount}회',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// "지도 열기 ›" — solid primary pill in the mini-map's bottom-right corner.
class _OpenMapButton extends StatelessWidget {
  const _OpenMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: 3,
      shadowColor: const Color(0x33626730),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '지도 열기',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.textOnPrimaryButton),
              ),
              const SizedBox(width: 2),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 20,
                color: AppColors.textOnPrimaryButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

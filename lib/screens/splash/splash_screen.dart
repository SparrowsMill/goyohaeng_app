import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// 앱 로딩 화면 (user_flow §1 "Start") — `AuthStore.bootstrap()` 이 저장된
/// 세션을 복원하는 동안 표시된다.
///
/// 모션은 CLAUDE.md §8 — 잔잔하게만:
///  * 진입: 로고가 페이드인하며 살짝 확대(0.94→1.0)해 자리를 잡는다. 1회.
///  * 대기: 로고가 아주 느리게 "숨쉬고"(1.0↔1.03) 점 3개가 순차 페이드한다. 무한.
/// 통통 튀는 커브·빠른 아크는 쓰지 않는다.
///
/// * TODO(asset): 전용 스플래시 아트 `assets/branding/splash.png` 미납품 —
///   그 전까지 `app_logo.png` 로고 락업으로 대체(errorBuilder).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 진입 — 페이드인 + 살짝 확대. 1회 재생.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  // 대기 — 숨쉬기 + 점 페이드. 무한 반복(0→1 위상).
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _enter, curve: AppMotion.curve);
  late final Animation<double> _scaleIn =
      Tween<double>(begin: 0.94, end: 1.0).animate(_fadeIn);

  @override
  void dispose() {
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// 0→1 로 도는 위상을 0→1→0 삼각파로 바꿔 easeInOut 을 먹인다.
  double _breathe(double phase) =>
      Curves.easeInOut.transform(1 - (phase * 2 - 1).abs());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scaleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _idle,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + 0.03 * _breathe(_idle.value),
                    child: child,
                  ),
                  child: const _SplashLogo(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) => _LoadingDots(phase: _idle.value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로고 락업. 파일이 아직 없으면 단계적으로 대체한다:
/// `splash.png` → `app_logo.png` → 아이콘 + 워드마크.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  static const _width = 240.0;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/splash.png',
      width: _width,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/branding/app_logo.png',
        width: _width,
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.filter_vintage_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('고요행', style: AppTextStyles.display),
          ],
        ),
      ),
    );
  }
}

/// 점 3개 — [phase](0~1, 무한 루프)에 위상차를 줘 왼쪽부터 잔잔히 밝아졌다 어두워진다.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.phase});

  final double phase;

  static const _count = 3;
  static const _stagger = 0.16;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _count; i++) ...[
          if (i != 0) const SizedBox(width: AppSpacing.sm),
          Opacity(
            opacity: 0.3 + 0.7 * _wave((phase - i * _stagger) % 1.0),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _wave(double t) => Curves.easeInOut.transform(1 - (t * 2 - 1).abs());
}

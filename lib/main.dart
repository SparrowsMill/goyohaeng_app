import 'package:flutter/material.dart';

import 'api/auth_store.dart';
import 'data/mock_map_regions.dart' show loadRealRegionStats;
import 'screens/auth/login_screen.dart';
import 'screens/mill/mill_home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';
import 'widgets/paper_texture_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoyohaengApp());
}

class GoyohaengApp extends StatelessWidget {
  const GoyohaengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '고요행',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _Bootstrap(),
      builder: (context, child) => PaperTextureOverlay(child: child),
    );
  }
}

/// 저장된 세션을 복원한다(user_flow §1). 토큰이 유효하면 바로 `<본인 방앗간>`으로,
/// 아니면 로그인 화면으로 보낸다.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  /// 세션 복원과 최소 표시 시간(스플래시가 깜빡이지 않게)을 함께 기다린다.
  late final Future<void> _ready = Future.wait([
    AuthStore.instance.bootstrap(),
    Future<void>.delayed(const Duration(milliseconds: 1500)),
  ]);

  @override
  void initState() {
    super.initState();
    // 인증 불필요 API라 스플래시를 막지 않고 백그라운드로 미리 받아둔다
    // (<지도>/방앗간 미니맵이 열릴 때쯤엔 대부분 이미 도착해 있다).
    loadRealRegionStats();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        final Widget screen;
        if (snapshot.connectionState != ConnectionState.done) {
          screen = const SplashScreen();
        } else {
          screen = AuthStore.instance.isSignedIn
              ? const MillHomeScreen()
              : const LoginScreen();
        }
        // 스플래시 → 다음 화면 크로스페이드 (CLAUDE.md §8, 소프트 페이드).
        return AnimatedSwitcher(
          duration: AppMotion.modalTransition,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          child: KeyedSubtree(
            key: ValueKey(screen.runtimeType),
            child: screen,
          ),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'config/map_config.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/paper_texture_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNaverMap();
  runApp(const GoyohaengApp());
}

/// The NAVER Map SDK ships Android/iOS implementations only. Desktop/web are
/// used for quick previews, so skip init there — the `<지도>` screen already
/// falls back to the GeoJSON vector map when the real map is unavailable.
Future<void> _initNaverMap() async {
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!isMobile) return;

  try {
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (ex) =>
          debugPrint('NaverMap auth failed (${ex.runtimeType}): $ex'),
    );
    naverMapInitialized = true;
  } catch (e, s) {
    debugPrint('NaverMap init skipped after error: $e\n$s');
  }
}

class GoyohaengApp extends StatelessWidget {
  const GoyohaengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '고요행',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
      builder: (context, child) => PaperTextureOverlay(child: child),
    );
  }
}

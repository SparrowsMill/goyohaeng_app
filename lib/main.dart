import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/paper_texture_overlay.dart';

void main() {
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
      // * TODO(backend): 자동 로그인 분기 필요 (user_flow §1) — 저장된 세션/토큰이
      //   유효하면 LoginScreen 대신 바로 MillHomeScreen 으로 진입.
      home: const LoginScreen(),
      builder: (context, child) => PaperTextureOverlay(child: child),
    );
  }
}

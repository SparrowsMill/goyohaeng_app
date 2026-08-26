import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';

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
      home: const LoginScreen(),
    );
  }
}

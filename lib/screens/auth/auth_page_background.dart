import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared chrome for the auth flow (login/signup): full-bleed watercolor
/// background, an optional back button, and the app logo lockup, with
/// [child] filling the remaining space.
class AuthPageBackground extends StatelessWidget {
  const AuthPageBackground({
    super.key,
    required this.child,
    this.showBackButton = true,
  });

  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/illustrations/scenes/auth_bg.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Padding(
                  padding: EdgeInsets.only(bottom: 96.0),
                  child: Image(
                    image: AssetImage('assets/branding/app_logo.png'),
                    width: 160,
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
          if (showBackButton)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  0,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Symbols.arrow_back_rounded),
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

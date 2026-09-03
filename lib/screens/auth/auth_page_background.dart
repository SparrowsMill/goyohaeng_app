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
    this.showSceneImage = true,
    this.showLogo = true,
    this.logoWidth = 160,
  });

  final Widget child;
  final bool showBackButton;

  /// Whether to paint the `auth_bg.png` watercolor scene behind the content.
  /// When false, the flat `AppColors.appBackground` fill is used instead.
  final bool showSceneImage;

  /// Whether to show the app logo lockup above [child].
  final bool showLogo;

  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Header-style band, not a full-bleed fill: the asset spans the
          // full screen width pinned to the top, and its own aspect ratio
          // sets the height. Everything below it shows the Scaffold's
          // `AppColors.appBackground` fill — so a shorter header-sized asset
          // drops in without any code change here.
          if (showSceneImage)
            Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                'assets/illustrations/scenes/auth_bg.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                // Without the logo, the content would otherwise start right
                // under the back button; add clearance so they don't crowd.
                SizedBox(
                  height: showLogo || !showBackButton
                      ? AppSpacing.lg
                      : AppSpacing.massive + 80,
                ),
                if (showLogo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Image(
                      image: const AssetImage('assets/branding/app_logo.png'),
                      width: logoWidth,
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

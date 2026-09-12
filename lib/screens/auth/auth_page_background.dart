import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared chrome for the auth flow (login/signup): a top-anchored watercolor
/// scene band, an optional back button, and an optional app logo lockup, with
/// [child] filling the rest.
class AuthPageBackground extends StatelessWidget {
  const AuthPageBackground({
    super.key,
    required this.child,
    this.showBackButton = true,
    this.showSceneImage = true,
    this.showLogo = true,
    this.logoWidth = 250,
  });

  final Widget child;
  final bool showBackButton;

  /// Whether to paint the `start_bg.png` watercolor scene behind the content.
  /// When false, the flat `AppColors.appBackground` fill is used instead.
  final bool showSceneImage;

  /// Whether to show the small `app_logo.png` lockup centered just below the
  /// scene band.
  final bool showLogo;

  /// On-screen width of the centered logo.
  final double logoWidth;

  /// Gap between the scene band and the content below it.
  static const _contentGap = 24.0;

  /// Gap between the bottom of the scene band and the logo below it.
  static const _logoTopGap = 16.0;

  Widget _logo() => Image.asset(
        'assets/branding/app_logo.png',
        width: logoWidth,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final hasBand = showSceneImage || showLogo;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            // The scene runs full-bleed to the very top (behind the status
            // bar); only pad the top when there's no scene to fill it.
            top: !showSceneImage,
            child: Column(
              children: [
                // Header-style band (scene) then the logo below it — normal
                // column children, so the content flows underneath. The scene
                // asset's own aspect ratio sets the band height.
                if (showSceneImage)
                  Image.asset(
                    'assets/illustrations/scenes/start_bg.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                if (showLogo) ...[
                  const SizedBox(height: _logoTopGap),
                  _logo(),
                ],
                if (hasBand)
                  const SizedBox(height: _contentGap)
                else
                  SizedBox(
                    height: showBackButton
                        ? AppSpacing.massive + 80
                        : AppSpacing.lg,
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
                  // Circular chip so the icon stays legible over the scene art.
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Symbols.arrow_back_rounded,
                          size: 24,
                          color: AppColors.iconPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

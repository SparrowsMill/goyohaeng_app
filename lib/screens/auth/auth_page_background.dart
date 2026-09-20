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
    this.logoWidth = 140,
    this.title,
  });

  final Widget child;
  final bool showBackButton;

  /// When set, the back button (if any) sits in a flat `AppBar` bar above the
  /// scene — matching `<관리자 모드>`(웹뷰) — instead of the default floating
  /// circular chip over the scene art.
  final String? title;

  /// Whether to paint the `start_bg.png` watercolor scene behind the content.
  /// When false, the flat `AppColors.appBackground` fill is used instead.
  final bool showSceneImage;

  /// Whether to show the small `app_logo_2.png` lockup centered just below the
  /// scene band.
  final bool showLogo;

  /// On-screen width of the centered logo.
  final double logoWidth;

  /// Gap between the scene band and the content below it.
  static const _contentGap = 24.0;

  /// Gap between the bottom of the scene band and the logo below it.
  static const _logoTopGap = 16.0;

  Widget _logo() => Image.asset(
        'assets/branding/app_logo_2.png',
        width: logoWidth,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );

  /// The `start_bg.png` watercolor scene, sized by its own aspect ratio at
  /// full screen width. When [visible] is false it still occupies the same
  /// layout space but paints nothing — used as a spacer inside the
  /// scrollable content column so that column lines up with the real scene
  /// (painted once, separately, as a fixed background layer below it) while
  /// still being free to scroll up over it.
  Widget _scene({bool visible = true}) {
    final image = Image.asset(
      'assets/illustrations/scenes/start_bg.png',
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) => const SizedBox(),
    );
    return visible ? image : Opacity(opacity: 0, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final hasBand = showSceneImage || showLogo;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: title == null
          ? null
          : AppBar(
              leading: showBackButton
                  ? IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Symbols.arrow_back_rounded),
                    )
                  : null,
              title: Text(title!),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fixed background layer — painted once here, outside the
          // scrollable content below, so it stays put on screen instead of
          // scrolling away with the logo/form (that's why the content column
          // below reserves matching space with an invisible `_scene(visible:
          // false)` spacer rather than including this same image inline).
          if (showSceneImage)
            Positioned(top: 0, left: 0, right: 0, child: _scene()),
          SafeArea(
            // The scene runs full-bleed to the very top (behind the status
            // bar); only pad the top when there's no scene to fill it. With
            // an `appBar` set, the Scaffold body is already below it, so the
            // top inset is never needed either way.
            top: title == null && !showSceneImage,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Reserves the same height as the fixed scene band above
                  // so content starts just below it, but scrolls freely
                  // (including up over the fixed scene) once the logo/form
                  // below don't fit the screen — e.g. with the keyboard open.
                  if (showSceneImage) _scene(visible: false),
                  if (showLogo) ...[
                    const SizedBox(height: _logoTopGap),
                    // `Center` opts back out of the Column's `stretch`
                    // (needed below so `child` fills the full width) so the
                    // logo keeps its own fixed [logoWidth] instead of being
                    // stretched to the screen width.
                    Center(child: _logo()),
                  ],
                  if (hasBand)
                    const SizedBox(height: _contentGap)
                  else
                    SizedBox(
                      height: showBackButton
                          ? AppSpacing.massive + 80
                          : AppSpacing.lg,
                    ),
                  child,
                ],
              ),
            ),
          ),
          if (showBackButton && title == null)
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

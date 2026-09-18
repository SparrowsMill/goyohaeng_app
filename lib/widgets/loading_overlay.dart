import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shared "still loading" treatment for any screen with a slow fetch or
/// render (map boundaries/tiles, list fetches, etc.): a small pill pinned
/// near the top (Naver Map-style), with the rest of [child] blurred behind
/// it while [loading] is true — instead of swapping the whole screen for a
/// centered spinner.
///
/// Wrap a screen's body content (not the whole [Scaffold]) so the app bar
/// and bottom nav stay interactive. The blur scrim blocks touches to the
/// stale content underneath while [loading] is true and stops blocking the
/// instant it turns false, even while the fade-out is still animating.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.label = '불러오는 중...',
  });

  final bool loading;
  final Widget child;

  /// Text shown next to the spinner in the pill. Pass null for icon-only.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !loading,
            child: AnimatedOpacity(
              opacity: loading ? 1 : 0,
              duration: AppMotion.standard,
              curve: AppMotion.curve,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          color: const Color.fromRGBO(76, 57, 39, 0.10),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Center(child: _LoadingPill(label: label)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.elevatedCard,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              label!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Tappable "input" that opens `<지도>` search (지역명·장소명 → `<지역별 랭킹>`).
/// Shared by `<지도>` (translucent, laid over the map tiles) and `<전체 랭킹>`
/// (opaque, sitting on the flat `#FAE7C0` background).
class PlaceSearchBar extends StatelessWidget {
  const PlaceSearchBar({super.key, required this.onTap, this.translucent = false});

  final VoidCallback onTap;

  /// `<지도>` needs the sea/land behind it to read through; `<전체 랭킹>` sits on
  /// a flat background so a plain opaque surface reads better there.
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final bar = Material(
      color: translucent
          ? AppColors.surface.withValues(alpha: 0.74)
          : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: translucent
                  ? AppColors.border.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppRadius.inputField),
          ),
          child: Row(
            children: [
              const Icon(Symbols.search_rounded,
                  size: 20, color: AppColors.iconInactive),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '지역명 · 장소명 검색',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );

    if (!translucent) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.inputField),
        child: bar,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.inputField),
      child: BackdropFilter(
        // Slight frost so the sea/land behind reads through the bar without
        // muddying the placeholder text.
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: bar,
      ),
    );
  }
}

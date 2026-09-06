import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A tourist-spot map marker: a teardrop pin tinted by [color] (its 갭지수
/// colour), or — when [favorite] — an amber star. Grows and shows its [label]
/// on a chip when [selected]. White-edged for contrast on light tiles.
class SpotPin extends StatelessWidget {
  const SpotPin({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.favorite,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pinColor = favorite ? AppColors.secondaryAccent : color;
    final onColor =
        ThemeData.estimateBrightnessForColor(pinColor) == Brightness.dark
            ? AppColors.surface
            : AppColors.textPrimary;
    final size = selected ? 36.0 : 26.0;
    final glyph =
        favorite ? Symbols.star_rounded : Symbols.location_on_rounded;
    final pin = Stack(
      alignment: Alignment.center,
      children: [
        Icon(glyph, size: size + 4, color: AppColors.surface, fill: 1),
        Icon(glyph, size: size, color: pinColor, fill: 1),
      ],
    );

    return GestureDetector(
      // deferToChild (default): only the chip/icon absorb taps so the map still
      // gets pan/zoom gestures that start near a pin.
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pinColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: pinColor),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(color: onColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 1),
          ],
          pin,
        ],
      ),
    );
  }
}

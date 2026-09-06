import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Map overlay button — a crosshair icon over the label "내 위치". Tapping it
/// asks the host map to locate the user and recentre on them. Shared by the
/// `<지도>` vector map and the real tile map (`RegionSpotMap`).
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({
    super.key,
    required this.onTap,
    this.busy = false,
  });

  final VoidCallback onTap;

  /// While a location fix is in flight — swaps the icon for a spinner.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.iconContainer),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.iconContainer),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Symbols.my_location_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                '내 위치',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "you are here" marker — an [AppColors.info] dot with a white ring and a
/// soft halo. Sized to sit inside a 28x28 box (vector map draws its own on the
/// canvas; this is the `flutter_map` marker child).
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.info,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withValues(alpha: 0.25),
              blurRadius: 6,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

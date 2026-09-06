import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// A deliberately vivid blue for the "you are here" marker — off the warm
/// storybook palette on purpose so it never reads as a spot pin.
const myLocationColor = Color(0xFF2E6BFF);

/// A map-overlay toggle — an icon over a label. [active] fills the icon and
/// switches to the amber accent + a selected surface, so it reads as "on".
class MapToggleButton extends StatelessWidget {
  const MapToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.secondaryAccent : AppColors.primary;
    return Material(
      color: active ? AppColors.surfaceSelected : AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.iconContainer),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.iconContainer),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, fill: active ? 1 : 0, color: tint),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption
                    .copyWith(color: tint, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "you are here" marker — a vivid blue dot with a white ring and a soft
/// halo. Sized to sit inside a 32x32 box (the vector map draws its own on the
/// canvas; this is the `flutter_map` marker child).
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: myLocationColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: myLocationColor.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

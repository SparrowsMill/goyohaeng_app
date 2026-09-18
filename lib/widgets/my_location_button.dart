import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Accent tint for "current location"-themed spots (e.g. the 장소 정보 페이지
/// 방문 CTA icon, the 길찾기 button) — off the warm storybook palette so it
/// never reads as a spot pin.
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

/// Reusable "current location"-themed pin icon (e.g. the 장소 정보 페이지
/// 방문 CTA heading).
const myLocationAsset = 'assets/illustrations/icon/current_location.png';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Fallback tint for the "you are here" marker when [myLocationAsset] can't be
/// drawn — off the warm storybook palette so it never reads as a spot pin.
const myLocationColor = Color(0xFF2E6BFF);

/// Lazily-decoded [myLocationAsset] for the canvas maps (vector `<지도>` and
/// the mill-home mini map). Null until [ensureMyLocationImage] finishes.
final ValueNotifier<ui.Image?> myLocationImage = ValueNotifier<ui.Image?>(null);
Future<void>? _myLocationImageLoad;

/// Kicks off decoding [myLocationAsset] once; safe to call repeatedly.
void ensureMyLocationImage() {
  _myLocationImageLoad ??= rootBundle.load(myLocationAsset).then((data) async {
    final codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    myLocationImage.value = (await codec.getNextFrame()).image;
  }).catchError((_) {});
}

/// A map-overlay button that recentres the camera on the device location.
/// The blue "you are here" dot appears on its own when the screen opens; this
/// button is for getting *back* to it after panning/zooming somewhere else.
/// Shown only once a location is known.
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
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
              const Icon(Symbols.my_location_rounded,
                  size: 24, color: AppColors.primary),
              const SizedBox(height: 2),
              Text(
                '내 위치',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Asset for the "you are here" marker. No longer used for the marker itself
/// (that reverted to the plain [myLocationColor] dot below) — kept as a
/// reusable icon for other "current location"-themed spots (e.g. the
/// 장소 정보 페이지 방문 CTA heading).
const myLocationAsset = 'assets/illustrations/icon/current_location.png';

/// The "you are here" marker — a solid [myLocationColor] dot with a white
/// ring, matching the vector maps' canvas-drawn pin ([mini_korea_map.dart]'s
/// `_paintPin`, `map_screen.dart`'s `_paintMyLocation`).
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
        ),
      ),
    );
  }
}

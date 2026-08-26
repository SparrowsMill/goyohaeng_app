import 'package:flutter/material.dart';

/// Color tokens defined in CLAUDE.md — Global Design System §1.
/// Do not hardcode hex values in screens; reference these constants instead.
abstract final class AppColors {
  // Core
  static const primary = Color(0xFF7E8442);
  static const primaryPressed = Color(0xFF626730);
  static const primaryHover = Color(0xFF72793B);
  static const secondaryAccent = Color(0xFFE89A45);
  static const secondaryAccentPressed = Color(0xFFCF8136);

  // Surfaces
  static const appBackground = Color(0xFFF8F2E8);
  static const surface = Color(0xFFFFFDF8);
  static const surfaceSelected = Color(0xFFEEF0DE);
  static const surfaceDisabled = Color(0xFFE9E3D9);

  // Text
  static const textPrimary = Color(0xFF4C3927);
  static const textSecondary = Color(0xFF8A7A66);
  static const textDisabled = Color(0xFFB7AA9A);
  static const textOnPrimaryButton = Color(0xFFFFFFFF);

  // Border and divider
  static const border = Color(0xFFE5DAC8);
  static const divider = Color(0xFFEEE6DA);
  static const focusBorder = Color(0xFF7E8442);

  // Status
  static const success = Color(0xFF66743C);
  static const successBackground = Color(0xFFEAF0D8);
  static const error = Color(0xFFB75E4D);
  static const errorBackground = Color(0xFFF8E6E1);
  static const warning = Color(0xFFC88432);
  static const warningBackground = Color(0xFFFBECD8);
  static const info = Color(0xFF6E7A8E);
  static const infoBackground = Color(0xFFE8EDF3);

  // Icons (functional)
  static const iconPrimary = textPrimary;
  static const iconActive = primary;
  static const iconInactive = textSecondary;
  static const iconDisabled = textDisabled;
  static const iconOnPrimaryButton = textOnPrimaryButton;
}

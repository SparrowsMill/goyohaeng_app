import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale defined in CLAUDE.md — Global Design System §2.
///
/// Korean text uses "Gowun Batang"; English/numerals use "Noto Serif".
/// [korean] applies both fonts (Gowun Batang first) so mixed Korean/English
/// strings render correctly; use [latin] only for pure English/numeral
/// content (e.g. verification codes, scores) where a Noto Serif-only look
/// is wanted.
abstract final class AppTextStyles {
  static TextStyle korean(TextStyle style) =>
      GoogleFonts.gowunBatang(textStyle: style).copyWith(
        fontFamilyFallback: [GoogleFonts.notoSerif().fontFamily!, 'serif'],
      );

  static TextStyle latin(TextStyle style) =>
      GoogleFonts.notoSerif(textStyle: style).copyWith(
        fontFamilyFallback: const ['serif'],
      );

  static const _color = AppColors.textPrimary;

  static final display = korean(const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 42 / 32,
    letterSpacing: -0.5,
    color: _color,
  ));

  static final h1 = korean(const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 38 / 28,
    letterSpacing: -0.4,
    color: _color,
  ));

  static final h2 = korean(const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 34 / 24,
    letterSpacing: -0.3,
    color: _color,
  ));

  static final h3 = korean(const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 30 / 20,
    letterSpacing: -0.2,
    color: _color,
  ));

  static final title = korean(const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 28 / 18,
    letterSpacing: -0.1,
    color: _color,
  ));

  static final bodyLarge = korean(const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 25 / 16,
    color: _color,
  ));

  static final bodyMedium = korean(const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 22 / 14,
    color: _color,
  ));

  static final bodySmall = korean(const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 20 / 13,
    color: _color,
  ));

  static final caption = korean(const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    color: AppColors.textSecondary,
  ));

  static final buttonLarge = korean(const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
  ));

  static final buttonMedium = korean(const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  ));

  static final numericScore = latin(const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
    letterSpacing: 0.5,
    color: _color,
  ));

  static final verificationCode = latin(const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 52 / 40,
    letterSpacing: 5,
    color: _color,
  ));
}

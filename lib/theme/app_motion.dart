import 'package:flutter/animation.dart';

/// Motion tokens — CLAUDE.md §8. Calm, subtle motion only:
/// soft fade, slight vertical slide, or gentle scale. No bouncy curves.
abstract final class AppMotion {
  static const standard = Duration(milliseconds: 200);
  static const pageTransition = Duration(milliseconds: 250);
  static const modalTransition = Duration(milliseconds: 300);
  static const pressFeedback = Duration(milliseconds: 120);

  /// cubic-bezier(0.2, 0, 0, 1)
  static const curve = Cubic(0.2, 0, 0, 1);
}

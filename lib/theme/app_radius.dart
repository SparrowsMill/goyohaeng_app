import 'package:flutter/widgets.dart';

/// Border radius tokens — CLAUDE.md §4.
abstract final class AppRadius {
  static const primaryButton = 16.0;
  static const secondaryButton = 14.0;
  static const smallButton = 12.0;
  static const pill = 999.0;
  static const card = 20.0;
  static const largeCard = 24.0;
  static const listRow = 16.0;
  static const inputField = 14.0;
  static const modal = 24.0;
  static const iconContainer = 12.0;

  static const bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(28),
    topRight: Radius.circular(28),
  );
}

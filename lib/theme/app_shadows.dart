import 'package:flutter/material.dart';

/// Shadow tokens — CLAUDE.md §5. Warm, subtle, low-opacity only;
/// never use harsh black or strong elevation shadows.
abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: Color.fromRGBO(76, 57, 39, 0.08),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  static const elevatedCard = [
    BoxShadow(
      color: Color.fromRGBO(76, 57, 39, 0.10),
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  static const primaryButton = [
    BoxShadow(
      color: Color.fromRGBO(98, 103, 48, 0.20),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
  ];

  static const modalOrBottomSheet = [
    BoxShadow(
      color: Color.fromRGBO(76, 57, 39, 0.12),
      offset: Offset(0, -8),
      blurRadius: 24,
    ),
  ];

  static const pressed = [
    BoxShadow(
      color: Color.fromRGBO(76, 57, 39, 0.08),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}

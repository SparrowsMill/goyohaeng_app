import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A horizontal grip the user drags up/down to resize the panel it sits on —
/// used between `<지역별 랭킹>`'s map and list, and on the `<지도>` 즐겨찾기
/// panel. [onDrag] is called with the vertical delta (logical px, +down) each
/// pointer move; the parent turns that into a new height.
///
/// [bordered] draws the hairline top/bottom rules + surface fill (the ranking
/// divider look); leave it off to render just the grip in a transparent touch
/// strip (for a panel that already has its own rounded top).
class DragToResizeHandle extends StatelessWidget {
  const DragToResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.bordered = true,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => onDragStart?.call(),
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        onVerticalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          alignment: Alignment.center,
          decoration: bordered
              ? const BoxDecoration(
                  color: AppColors.appBackground,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: AppColors.divider),
                  ),
                )
              : null,
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

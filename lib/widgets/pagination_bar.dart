import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// 목록 하단 페이지 이동 바 — `‹ 1 2 3 4 5 ›`. 현재 페이지 주변 [windowSize]개의
/// 번호만 보여주고(페이지가 많아도 한 줄에 들어가도록), 양끝 화살표로 이전/다음
/// 페이지로 넘어간다. 페이지가 1개 이하면 아무것도 그리지 않는다. 페이지는
/// 1부터 시작한다.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
    this.windowSize = 5,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int windowSize;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final window = math.min(windowSize, totalPages);
    final start = math.max(
      1,
      math.min(page - window ~/ 2, totalPages - window + 1),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageButton(
          icon: Symbols.chevron_left_rounded,
          tooltip: '이전 페이지',
          onTap: page > 1 ? () => onPageChanged(page - 1) : null,
        ),
        for (var p = start; p < start + window; p++) ...[
          const SizedBox(width: AppSpacing.xs),
          _PageButton(
            label: '$p',
            selected: p == page,
            onTap: p == page ? null : () => onPageChanged(p),
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        _PageButton(
          icon: Symbols.chevron_right_rounded,
          tooltip: '다음 페이지',
          onTap: page < totalPages ? () => onPageChanged(page + 1) : null,
        ),
      ],
    );
  }
}

/// [PaginationBar]의 한 칸 — 36px 정사각 Small Button 규격. 번호 칸은 현재
/// 페이지면 [selected]로 올리브 채움, 화살표 칸은 [onTap]이 null이면(맨 처음/맨
/// 끝) 비활성 색으로 표시한다.
class _PageButton extends StatelessWidget {
  const _PageButton({
    this.label,
    this.icon,
    this.tooltip,
    this.selected = false,
    required this.onTap,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.smallButton);
    final enabled = onTap != null;
    final foreground = selected
        ? AppColors.textOnPrimaryButton
        : enabled
        ? AppColors.primaryPressed
        : AppColors.textDisabled;

    final button = Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: selected ? null : Border.all(color: AppColors.border),
          ),
          child: label != null
              ? Text(
                  label!,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                )
              : Icon(icon, size: 20, color: foreground),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

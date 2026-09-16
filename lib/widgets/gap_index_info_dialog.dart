import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/mock_map_regions.dart' show gapIndexAccent;
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Opens `<갭지수 설명 페이지>` (user_flow §6) as a centered modal. Shared by
/// the `<지도>` and `<지역별 랭킹>` screens via their "갭지수란?" buttons, and
/// by the place detail page's 갭지수 카드.
void showGapIndexInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
    builder: (_) => const _GapIndexInfoDialog(),
  );
}

/// Small outlined pill button that opens [showGapIndexInfo].
class GapIndexInfoButton extends StatelessWidget {
  const GapIndexInfoButton({super.key, this.onTap});

  /// Defaults to opening the shared dialog; override only to intercept.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap ?? () => showGapIndexInfo(context),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.help_rounded,
                size: 16,
                color: AppColors.primaryPressed,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '고요 지수란?',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.primaryPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular icon-only button that opens [showGapIndexInfo] — for
/// inline placement right beside a "갭지수" label (e.g. the place detail
/// page's 갭지수 카드), where a full pill button would be too wide.
class GapIndexInfoIconButton extends StatelessWidget {
  const GapIndexInfoIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showGapIndexInfo(context),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(
            Symbols.help_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// `<갭지수 설명 페이지>` — a centered modal. Scrolls between a pinned close
/// button (top) and a pinned "확인" button (bottom).
class _GapIndexInfoDialog extends StatelessWidget {
  const _GapIndexInfoDialog();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.84;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.huge,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                      AppSpacing.lg,
                    ),
                    child: const _GapIndexInfoBody(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.sm,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('확인'),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: _DialogCloseButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapIndexInfoBody extends StatelessWidget {
  const _GapIndexInfoBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '고요 지수란?',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Image.asset(
            'assets/illustrations/sparrow/sparrow_gap_score_info.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(height: 120),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '검색은 많이 되지만 실제로는 \n잘 찾지 않는 곳을 발견하는 지표예요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceSelected,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GapMetricBar(
                icon: Symbols.search_rounded,
                label: '검색 관심도',
                value: 100,
                color: AppColors.info,
              ),
              const SizedBox(height: AppSpacing.md),
              const _GapMetricBar(
                icon: Symbols.footprint_rounded,
                label: '실제 방문',
                value: 30,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '관심은 큰데 방문은 적을수록 고요 지수가 커요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _GapCompareCard(
                  title: '고요 지수 높음',
                  bodyIcon: Symbols.trending_up_rounded,
                  tag: '주목받지만 한적한 곳',
                  background: AppColors.infoBackground,
                  foreground: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _GapCompareCard(
                  title: '고요 지수 낮음',
                  bodyIcon: Symbols.trending_down_rounded,
                  tag: '북적이는 유명한 곳',
                  background: AppColors.errorBackground,
                  foreground: AppColors.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('지도 색상 범례', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '지도의 색으로 지역별 고요 지수를 확인할 수 있어요.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _GapLegendDot(
                color: gapIndexAccent(80),
                label: '매우 높음',
                subLabel: '숨은 여행지',
              ),
            ),
            Expanded(
              child: _GapLegendDot(color: gapIndexAccent(65), label: '높음'),
            ),
            Expanded(
              child: _GapLegendDot(color: gapIndexAccent(50), label: '보통'),
            ),
            Expanded(
              child: _GapLegendDot(color: gapIndexAccent(35), label: '낮음'),
            ),
            Expanded(
              child: _GapLegendDot(
                color: gapIndexAccent(20),
                label: '매우 낮음',
                subLabel: '이미 알려짐',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One labelled progress bar inside the highlighted metric box — "검색
/// 관심도" / "실제 방문", each with an icon, a 0~100 value, and a filled
/// track proportional to it.
class _GapMetricBar extends StatelessWidget {
  const _GapMetricBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$value',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            height: 10,
            color: AppColors.surfaceDisabled,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// One of the paired "갭지수 높음" / "갭지수 낮음" example cards, tinted with
/// the app's existing error/info status colors.
class _GapCompareCard extends StatelessWidget {
  const _GapCompareCard({
    required this.title,
    required this.bodyIcon,
    required this.tag,
    required this.background,
    required this.foreground,
  });

  final String title;
  final IconData bodyIcon;
  final String tag;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(child: Icon(bodyIcon, size: 32, color: foreground)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              tag,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w700, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dot + label in the "지도 색상 범례" row — [subLabel] is only set on the
/// two ends of the scale (매우 높음/매우 낮음), matching the app's own
/// [gapIndexAccent] scale rather than an arbitrary new color set.
class _GapLegendDot extends StatelessWidget {
  const _GapLegendDot({required this.color, required this.label, this.subLabel});

  final Color color;
  final String label;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subLabel != null)
          Text(
            '($subLabel)',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              height: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// Circular outlined close button pinned to the dialog's top-right corner.
class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Symbols.close_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

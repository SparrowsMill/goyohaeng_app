import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/mock_map_regions.dart' show gapIndexGradient;
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Opens `<갭지수 설명 페이지>` (user_flow §6) as a centered modal. Shared by
/// the `<지도>` and `<지역별 랭킹>` screens via their "갭지수란?" buttons.
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
                '갭지수란?',
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

/// `<갭지수 설명 페이지>` — a centered modal. Scrolls between a pinned close
/// button (top) and a pinned "확인" button (bottom).
///
/// * TODO: 갭지수 정의·산출 공식 텍스트가 하드코딩 — 백엔드 실제 산출식과
///   일치하는지 확정 후 필요 시 문구/공식 갱신 (또는 CMS로 분리).
///
/// Watercolor art below is placeholder — nothing renders until these files
/// are supplied (asset request pending):
///   - assets/illustrations/map/map_gap_hero.png  (참새 + 지도 일러스트)
///   - assets/illustrations/map/map_gap_high.png  ("갭지수 높음" 카드)
///   - assets/illustrations/map/map_gap_low.png   ("갭지수 낮음" 카드)
///
/// * TODO(asset): 위 3개 파일 + `assets/illustrations/map/` 폴더 자체가
///   `pubspec.yaml`의 assets 목록에 없음 — 파일 납품 시 폴더 등록도 함께 필요.
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
          '갭지수란?',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Image.asset(
            'assets/illustrations/sparrow/sparrow_gap_score_info.png',
            height: 132,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(height: 132),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '잘 알려져 있지만 실제 방문은 많지 않은\n장소를 발견하기 위한 지표예요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceSelected,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/branding/leaf_ornament.png',
                width: 30,
                height: 30,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(width: 30),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '갭지수가 높을수록 알려져 있지만 방문은 많지 않은 장소예요.',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('갭지수 산출 방식', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.inputField),
          ),
          child: Text(
            'Gap Score = normalize(검색 관심도) − normalize(실제 방문 집중도)',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _TermLine(
          term: '검색 관심도',
          description: '장소가 얼마나 많이 검색되는지 나타낸 값',
        ),
        const SizedBox(height: AppSpacing.xs),
        const _TermLine(
          term: '실제 방문 집중도',
          description: '실제 방문이 얼마나 집중되는지 나타낸 값',
        ),
        const SizedBox(height: AppSpacing.lg),
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _GapCompareCard(
                  title: '갭지수 높음',
                  description: '검색 관심도에 비해 실제 방문 집중도가 낮은 장소',
                  art: 'assets/illustrations/map/map_gap_high.png',
                  emphasized: true,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _GapCompareCard(
                  title: '갭지수 낮음',
                  description: '두 값의 차이가 작은 장소',
                  art: 'assets/illustrations/map/map_gap_low.png',
                  emphasized: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              Text(
                '지도에서는 이렇게 표시돼요',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text('낮음', style: AppTextStyles.caption),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        gradient: gapIndexGradient,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('높음', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '남청색에 가까울수록 평균 갭지수가 높고,\n붉은색에 가까울수록 낮은 지역이에요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A term rendered bold, followed by its plain-text definition, on one line
/// (wrapping as needed) — the "검색 관심도: …" / "실제 방문 집중도: …" rows.
class _TermLine extends StatelessWidget {
  const _TermLine({required this.term, required this.description});

  final String term;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(
            text: '$term  ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(text: description),
        ],
      ),
    );
  }
}

/// One of the paired "갭지수 높음" / "갭지수 낮음" example cards. The
/// [emphasized] one uses the filled olive treatment.
class _GapCompareCard extends StatelessWidget {
  const _GapCompareCard({
    required this.title,
    required this.description,
    required this.art,
    required this.emphasized,
  });

  final String title;
  final String description;
  final String art;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final foreground =
        emphasized ? AppColors.textOnPrimaryButton : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary : AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600, color: foreground),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              color: emphasized
                  ? AppColors.textOnPrimaryButton.withValues(alpha: 0.85)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: _PlaceholderArt(asset: art, height: 30),
          ),
        ],
      ),
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

/// Watercolor illustration slot — renders nothing (just reserves height)
/// until the asset is supplied.
class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.asset, required this.height});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => SizedBox(height: height),
    );
  }
}

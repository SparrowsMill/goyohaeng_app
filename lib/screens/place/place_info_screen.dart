import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../trend/trend_summary_screen.dart';
import 'visit_prepare_screen.dart';
import 'visit_unavailable_screen.dart';

/// `<장소 정보 페이지>` (user_flow §6) — one tourist spot's detail page,
/// reached by tapping a spot on `<지역별 랭킹 페이지>` (or the region map).
///
/// Shows the visit state (미방문 / 방문 인증 완료), name, 갭지수 + a short
/// plain-language reading of it, the big 방문 인증 CTA (with the obtainable
/// ingredient + store benefit beside it), a small 길찾기 button, then the
/// category / 주소 / 운영시간 / 주인의 소개 block, optional 문의처, and the
/// 트렌드 요약 keywords.
///
/// * TODO: 방문 인증 흐름 연결 (user_flow §6 — admin 토글에 따라 방문 인증
///   페이지 또는 방문 불가 페이지로 분기)
/// * TODO: 길찾기·전화하기·홈페이지 — 외부 앱/브라우저 연동
class PlaceInfoScreen extends StatelessWidget {
  const PlaceInfoScreen({super.key, required this.spot});

  final MockTouristSpot spot;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = spot.phone != null || spot.homepage != null;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('장소 정보'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _VisitStatePill(state: spot.visitState),
          const SizedBox(height: AppSpacing.md),
          Text(spot.name, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.xs),
          _CategoryLine(spot: spot),
          const SizedBox(height: AppSpacing.md),
          _DirectionsButton(
            onTap: () => _todo(context, '${spot.name} 길찾기는 지도 앱 연동 후 이용할 수 있어요.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _GapCard(spot: spot),
          const SizedBox(height: AppSpacing.lg),
          _VisitCtaCard(
            spot: spot,
            // user_flow §6: 방문 인증 가능 → 방문 인증 페이지, 불가 → 방문 불가.
            onVerify: () {
              if (spot.visitVerifiable) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VisitPrepareScreen(spot: spot),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VisitUnavailableScreen(spot: spot),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _DetailCard(spot: spot, onDirections: () {
            _todo(context, '${spot.name} 길찾기는 지도 앱 연동 후 이용할 수 있어요.');
          }),
          if (hasContact) ...[
            const SizedBox(height: AppSpacing.xl),
            _ContactSection(
              spot: spot,
              onCall: () => _todo(context, '전화 앱 연동 후 바로 걸 수 있어요.'),
              onHomepage: () => _todo(context, '홈페이지는 브라우저 연동 후 열 수 있어요.'),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _TrendSection(
            spot: spot,
            onOpenTrend: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrendSummaryScreen(spot: spot),
              ),
            ),
            onKeyword: (keyword) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TrendSummaryScreen(spot: spot, focusKeyword: keyword),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1 || index == 2) {
            Navigator.of(context).maybePop();
          }
          // * TODO: 기록 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }
}

/// "미방문" / "방문 인증 완료" outlined pill at the top of the page.
class _VisitStatePill extends StatelessWidget {
  const _VisitStatePill({required this.state});

  final VisitState state;

  @override
  Widget build(BuildContext context) {
    final verified = state == VisitState.verified;
    final color = verified ? AppColors.success : AppColors.textSecondary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Symbols.verified_rounded : Symbols.location_on_rounded,
              size: 15,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              state.label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// "액티비티 · 갭지수 89 ●" — the category + 갭지수 line under the name, with
/// the scale-colored dot at the end.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            '${spot.category.label} · 갭지수 ${spot.gapIndex}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: gapIndexColor(spot.gapIndex),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Small outlined "길찾기" button beneath the name.
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.smallButton),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.navigation_rounded,
                  size: 16,
                  color: AppColors.primaryPressed,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '길찾기',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.primaryPressed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable page card — surface fill, warm border, soft shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// The "이곳의 갭지수" card: big number + scale tick on the left, a plain-
/// language reading of the score on the right.
class _GapCard extends StatelessWidget {
  const _GapCard({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 56,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: gapIndexColor(spot.gapIndex),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이곳의 갭지수',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${spot.gapIndex}',
                style: AppTextStyles.display.copyWith(
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                spot.gapDescription,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "이곳을 방문해 보세요" — leaf-headed card with the big 방문 인증 CTA and,
/// beneath it, the obtainable ingredient + store benefit.
class _VisitCtaCard extends StatelessWidget {
  const _VisitCtaCard({required this.spot, required this.onVerify});

  final MockTouristSpot spot;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final ingredientLabel = spot.ingredient == null
        ? '획득 재료 없음'
        : '획득 재료: ${spot.ingredient} ${spot.ingredientCount}개';
    final benefitLabel = spot.storeBenefit ?? '제공 혜택 없음';

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/branding/leaf_ornament.png',
                width: 36,
                height: 36,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.eco_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이곳을 방문해 보세요', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '방문 인증을 완료하면 재료와 혜택을 받을 수 있어요',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onVerify,
              icon: const Icon(Symbols.where_to_vote_rounded, size: 22),
              label: const Text('방문 인증'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: _RewardBox(
                  icon: Symbols.eco_rounded,
                  label: ingredientLabel,
                  active: spot.ingredient != null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RewardBox(
                  icon: Symbols.redeem_rounded,
                  label: benefitLabel,
                  active: spot.storeBenefit != null,
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBox extends StatelessWidget {
  const _RewardBox({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.successBackground : AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 카테고리 / 주소 / 운영시간 / 주인의 소개 block.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.spot, required this.onDirections});

  final MockTouristSpot spot;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Symbols.eco_rounded,
            label: '카테고리',
            child: Text(
              '${spot.spotType} · ${spot.category.label}',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.location_on_rounded,
            label: '주소',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(spot.address, style: AppTextStyles.bodyMedium),
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniButton(
                  icon: Symbols.navigation_rounded,
                  label: '길찾기',
                  onTap: onDirections,
                ),
              ],
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.schedule_rounded,
            label: '운영시간',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in spot.hours)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(line, style: AppTextStyles.bodyMedium),
                  ),
              ],
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.person_rounded,
            label: '주인의 소개',
            child: Text(
              spot.ownerIntro,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.iconInactive),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.divider);
  }
}

/// Compact outlined button used inside detail rows and the contact section.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.smallButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primaryPressed),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryPressed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "문의 및 공식 정보" — phone number + 전화하기 / 홈페이지 보기 buttons.
class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.spot,
    required this.onCall,
    required this.onHomepage,
  });

  final MockTouristSpot spot;
  final VoidCallback onCall;
  final VoidCallback onHomepage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문의 및 공식 정보', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (spot.phone != null) ...[
                Row(
                  children: [
                    const Icon(
                      Symbols.call_rounded,
                      size: 18,
                      color: AppColors.iconInactive,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(spot.phone!, style: AppTextStyles.bodyMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  if (spot.phone != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.call_rounded,
                        label: '전화하기',
                        onTap: onCall,
                      ),
                    ),
                  if (spot.phone != null && spot.homepage != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (spot.homepage != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.language_rounded,
                        label: '홈페이지 보기',
                        onTap: onHomepage,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "요즘 이곳은 이런 이야기로 들려요" — the 트렌드 요약 entry point plus the
/// most-mentioned keywords as tappable chips.
class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.spot,
    required this.onOpenTrend,
    required this.onKeyword,
  });

  final MockTouristSpot spot;
  final VoidCallback onOpenTrend;
  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('요즘 이곳은 이런 이야기로 들려요', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '방문자들이 가장 많이 언급한 키워드예요.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: AppColors.surfaceSelected,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
            onTap: onOpenTrend,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.chat_rounded,
                    size: 18,
                    color: AppColors.primaryPressed,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '트렌드 요약',
                    style: AppTextStyles.buttonMedium
                        .copyWith(color: AppColors.primaryPressed),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 키워드는 한 줄로 세우고, 넘치면 옆으로 스크롤.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < spot.trendKeywords.length; i++) ...[
                if (i != 0) const SizedBox(width: AppSpacing.sm),
                _KeywordChip(
                  label: spot.trendKeywords[i],
                  onTap: () => onKeyword(spot.trendKeywords[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$label',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

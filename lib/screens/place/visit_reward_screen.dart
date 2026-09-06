import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// 재료 이름 → 전용 일러스트 경로. 아직 그림이 없는 재료(단풍잎/느티나무잎/갈대/
/// 홍어 등)는 `null`을 반환해 `_IngredientCard`가 범용 잎사귀 아이콘으로 대체한다.
String? _ingredientAssetPath(String? ingredient) {
  switch (ingredient) {
    case '대나무잎':
      return 'assets/illustrations/rewards/ingredient_bamboo.png';
    case '녹차잎':
      return 'assets/illustrations/rewards/ingredient_greentea.png';
    case '콩나물':
      return 'assets/illustrations/rewards/ingredient_beansprout.png';
    default:
      return null;
  }
}

/// `<방문 인증 보상 페이지>` (user_flow §6) — reached when 방문 인증이 성공했을 때
/// `<방문 인증 확인 페이지>`에서 넘어온다. 방앗간 재료 + 귀여운 일러스트, 해당
/// 재료로 만들 수 있는 음식 추천, 공유 버튼 2개(SNS / 기록용 플랫폼), 확인 옵션을
/// 보여준다.
///
/// * TODO(backend): 추천 음식 연동 (§4 `<음식 정보>` 화면 필요)
/// * TODO: SNS/기록용 플랫폼 공유 연동 (§7)
class VisitRewardScreen extends StatelessWidget {
  const VisitRewardScreen({super.key, required this.spot});

  final MockTouristSpot spot;

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('방문 인증 보상'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/illustrations/scenes/reward_success_bg.png',
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
                Image.asset(
                  'assets/illustrations/sparrow/sparrow_happy.png',
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Symbols.celebration_rounded,
                    size: 64,
                    color: AppColors.secondaryAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RewardTitle(spot: spot),
          const SizedBox(height: AppSpacing.xs),
          const _RewardSubtitle(),
          const SizedBox(height: AppSpacing.xl),
          _RewardSummaryCard(spot: spot),
          const SizedBox(height: AppSpacing.lg),
          _RecommendedFoodCard(
            onTap: () => _todo(context, '추천 음식 정보는 준비 중이에요.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ShareSection(
            onShareSns: () => _todo(context, 'SNS 공유는 앱 연동 후 이용할 수 있어요.'),
            onShareRecord: () => _todo(context, '기록용 플랫폼 공유는 준비 중이에요.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "대나무잎 1개 획득" — 재료 이름은 진하게, 개수는 강조색으로.
class _RewardTitle extends StatelessWidget {
  const _RewardTitle({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    if (spot.ingredient == null) {
      return Text(
        '방문 인증을 완료했어요!',
        textAlign: TextAlign.center,
        style: AppTextStyles.h1,
      );
    }
    return Text.rich(
      TextSpan(
        style: AppTextStyles.h1,
        children: [
          TextSpan(text: '${spot.ingredient} '),
          TextSpan(
            text: '${spot.ingredientCount}개',
            style: const TextStyle(color: AppColors.success),
          ),
          const TextSpan(text: ' 획득'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// "🍃 이번 여행의 선물 🍃" — 양옆에 작은 잎 장식.
class _RewardSubtitle extends StatelessWidget {
  const _RewardSubtitle();

  @override
  Widget build(BuildContext context) {
    Widget leaf({required bool flip}) {
      final img = Image.asset(
        'assets/branding/leaf_ornament.png',
        width: 14,
        height: 14,
        errorBuilder: (context, error, stackTrace) => const SizedBox(width: 14),
      );
      return flip ? Transform.flip(flipX: true, child: img) : img;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leaf(flip: true),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '이번 여행의 선물',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        leaf(flip: false),
      ],
    );
  }
}

/// "담양 죽녹원 방문 완료 / 대나무잎 1개 획득 / 입장권 10% 할인 혜택" 요약 카드.
class _RewardSummaryCard extends StatelessWidget {
  const _RewardSummaryCard({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final ingredientPath = _ingredientAssetPath(spot.ingredient);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSelected,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 여행의 선물',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            assetPath: 'assets/illustrations/icon/main_verified_icon.png',
            fallbackIcon: Symbols.verified_rounded,
            text: '${spot.name} 방문 완료',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            assetPath: ingredientPath,
            fallbackIcon: Symbols.eco_rounded,
            text: spot.ingredient == null
                ? '획득 재료 없음'
                : '${spot.ingredient} ${spot.ingredientCount}개 획득',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            assetPath: 'assets/illustrations/icon/reward_benefit_icon.png',
            fallbackIcon: Symbols.redeem_rounded,
            text: spot.storeBenefit == null
                ? '제공 혜택 없음'
                : '${spot.storeBenefit} 혜택',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.assetPath,
    required this.fallbackIcon,
    required this.text,
  });

  final String? assetPath;
  final IconData fallbackIcon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: assetPath == null
              ? Icon(fallbackIcon, size: 32, color: AppColors.primary)
              : Image.asset(
                  assetPath!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(fallbackIcon, size: 32, color: AppColors.primary),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedFoodCard extends StatelessWidget {
  const _RecommendedFoodCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              const Icon(
                Symbols.restaurant_rounded,
                size: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이 재료로 만들 수 있는 음식',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('추천 음식 보러 가기', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 22,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.onShareSns, required this.onShareRecord});

  final VoidCallback onShareSns;
  final VoidCallback onShareRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShareSns,
            icon: const Icon(Symbols.share_rounded, size: 18),
            label: const Text('SNS에 공유'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShareRecord,
            icon: const Icon(Symbols.edit_note_rounded, size: 18),
            label: const Text('기록 플랫폼'),
          ),
        ),
      ],
    );
  }
}

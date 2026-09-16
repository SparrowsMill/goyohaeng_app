import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../food/ingredient_bag_screen.dart';
import '../record/footprint_write_screen.dart';

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
/// `<방문 인증 확인 페이지>`에서 넘어온다. 방앗간 재료 + 귀여운 일러스트, 재료
/// 가방 바로가기, 기록용 플랫폼 공유 버튼, 확인 옵션을 보여준다.
///
/// [placeId]가 있으면(실 방문 인증 세션 경로) `GET /visit-verifications/{id}`가
/// `VERIFIED` 상태와 함께 즉시 내려주는 [reward]로 실제 지급 재료(이름/개수/
/// 등급)를 그대로 보여준다(스펙 §8.2, 2026-09-13 반영) — 별도 폴링/추론이
/// 필요 없다. [reward]가 없으면(목업 경로) [spot.ingredient]/
/// [spot.ingredientCount]를 대신 쓴다.
class VisitRewardScreen extends StatelessWidget {
  const VisitRewardScreen({
    super.key,
    required this.spot,
    this.placeId,
    this.visitVerificationId,
    this.benefit,
    this.reward,
  });

  final MockTouristSpot spot;

  /// `<방문 인증 페이지>`에서 이미 조회해 넘겨준 실 방문 혜택. null이면 목업
  /// `spot.storeBenefit`을 그대로 쓴다.
  final String? benefit;

  /// 실 방문 인증 세션의 장소 ID. `null`이면 목업 경로.
  final int? placeId;

  /// 실 방문 인증 세션의 ID(`VERIFIED` 상태) — "기록 플랫폼" 공유로 넘어갈 때
  /// `FootprintWriteScreen`에 그대로 실어 `RecordService().create()`가
  /// `visitVerificationId`를 함께 보낼 수 있게 한다. `null`이면 목업 경로.
  final int? visitVerificationId;

  /// 실 방문 인증 세션에서 승인 즉시 지급된 실제 재료(스펙 §8.2). `null`이면
  /// 목업 경로 — [spot.ingredient]/[spot.ingredientCount]를 대신 쓴다.
  final VisitVerificationReward? reward;

  String? get _ingredientName => reward?.name ?? spot.ingredient;
  int get _ingredientCount => reward?.quantity ?? spot.ingredientCount;

  /// "재료 가방 바로가기" → `<재료 가방>`. 지급된 재료 이름을 알고 있으므로
  /// 그 재료가 속한 등급 탭을 미리 선택해준다.
  void _openIngredientBag(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            IngredientBagScreen(initialIngredientName: _ingredientName),
      ),
    );
  }

  /// "기록 플랫폼" 공유 → `<기록 플랫폼 글쓰기>` (user_flow §6→§8). 방문 날짜·
  /// 장소·획득 재료 일러스트를 미리 채워 진입한다.
  void _shareToRecord(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FootprintWriteScreen(
          initialPlaceId: placeId,
          initialPlace: spot.name,
          initialPhotoAssets: [?_ingredientAssetPath(_ingredientName)],
          initialVisitVerificationId: visitVerificationId,
        ),
      ),
    );
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
                  height: 150,
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
          _RewardTitle(
            ingredientName: _ingredientName,
            ingredientCount: _ingredientCount,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _RewardSubtitle(),
          const SizedBox(height: AppSpacing.xl),
          _RewardSummaryCard(
            spot: spot,
            ingredientName: _ingredientName,
            ingredientCount: _ingredientCount,
            benefit: benefit,
          ),
          const SizedBox(height: AppSpacing.lg),
          _IngredientBagLinkCard(
            onTap: () => _openIngredientBag(context),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ShareSection(
            onShareRecord: () => _shareToRecord(context),
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
  const _RewardTitle({required this.ingredientName, required this.ingredientCount});

  final String? ingredientName;
  final int ingredientCount;

  @override
  Widget build(BuildContext context) {
    if (ingredientName == null) {
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
          TextSpan(text: '$ingredientName '),
          TextSpan(
            text: '$ingredientCount개',
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
  const _RewardSummaryCard({
    required this.spot,
    required this.ingredientName,
    required this.ingredientCount,
    this.benefit,
  });

  final MockTouristSpot spot;
  final String? ingredientName;
  final int ingredientCount;
  final String? benefit;

  @override
  Widget build(BuildContext context) {
    final ingredientPath = _ingredientAssetPath(ingredientName);
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
            assetPath: 'assets/illustrations/icon/verified.png',
            fallbackIcon: Symbols.verified_rounded,
            text: '${spot.name} 방문 완료',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            assetPath: ingredientPath,
            fallbackIcon: Symbols.eco_rounded,
            text: ingredientName == null
                ? '획득 재료 없음'
                : '$ingredientName $ingredientCount개 획득',
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            assetPath: 'assets/illustrations/icon/benefit.png',
            fallbackIcon: Symbols.redeem_rounded,
            text: benefit == null ? '제공 혜택 없음' : '$benefit 혜택',
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

/// "재료 가방 바로가기" — `<재료 가방>`으로 이동하는 카드형 버튼.
class _IngredientBagLinkCard extends StatelessWidget {
  const _IngredientBagLinkCard({required this.onTap});

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
              SizedBox(
                width: 24,
                height: 24,
                child: Image.asset(
                  'assets/illustrations/icon/ingredient_2.png',
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Symbols.shopping_bag_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '재료 가방 바로가기',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('재료를 확인하세요', style: AppTextStyles.caption),
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
  const _ShareSection({required this.onShareRecord});

  final VoidCallback onShareRecord;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onShareRecord,
        child: const Text('기록 플랫폼'),
      ),
    );
  }
}

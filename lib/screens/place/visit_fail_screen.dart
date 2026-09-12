import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// `<방문 인증 실패>` (user_flow §6) — `<방문 인증 확인 페이지>`에서 설정된
/// 시간(도착 예정 창)이 초과됐을 때 도달한다. 슬퍼하는 참새 일러스트와
/// "다시 도전" / "뒤로 가기" 버튼을 보여준다.
///
/// - 다시 도전 → `<방문 인증 페이지>`(`VisitPrepareScreen`)로 되돌아가 새
///   인증을 시작한다.
/// - 뒤로 가기 → `<장소 정보 페이지>`로 되돌아간다.
class VisitFailScreen extends StatelessWidget {
  const VisitFailScreen({
    super.key,
    required this.spot,
    this.window = const Duration(minutes: 30),
    this.status,
    this.failReason,
  });

  final MockTouristSpot spot;

  /// 인증 확인 화면에서 설정했던 도착 예정 창 — 안내 카드에 그대로 표시한다.
  final Duration window;

  /// 서버가 내려준 최종 상태 — `EXPIRED`(시간 만료) 또는 `FAILED`(관리자 반려,
  /// 스펙 §8.4). `null`이면(로컬 타이머 종료 등) 기존처럼 시간 만료로 표시한다.
  final String? status;

  /// `FAILED`일 때 관리자가 남겼을 수 있는 반려 사유.
  final String? failReason;

  bool get _isRejected => status == 'FAILED';

  String get _windowLabel {
    final minutes = window.inMinutes;
    return minutes >= 60 ? '1시간 이내' : '$minutes분 이내';
  }

  void _retry(BuildContext context) {
    // 인증 확인 화면은 이 실패 화면으로 pushReplacement 되어 스택에서 이미
    // 빠진 상태 — 한 번만 pop하면 방문 인증(준비) 화면으로 돌아간다.
    Navigator.of(context).pop();
  }

  void _backToPlaceInfo(BuildContext context) {
    // 방문 인증(준비) 화면까지 제거하고 장소 정보로.
    Navigator.of(context).pop();
    Navigator.of(context).pop();
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
        title: const Text('방문 인증 실패'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
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
                  'assets/illustrations/scenes/reward_fail_bg.png',
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
                Image.asset(
                  'assets/illustrations/sparrow/sparrow_sad.png',
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Symbols.schedule_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _isRejected ? '방문 인증이 반려됐어요' : '방문 인증 시간이 지났어요',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _isRejected
                ? (failReason?.trim().isNotEmpty ?? false)
                    ? failReason!.trim()
                    : '매장에서 이번 방문 인증을 확인하지 못했어요.\n다음에 다시 도전해 볼까요?'
                : '설정한 도착 예정 시간 안에 인증이 완료되지 않았어요.\n다음에 다시 도전해 볼까요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FailInfoCard(
            spot: spot,
            windowLabel: _windowLabel,
            rejected: _isRejected,
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _retry(context),
              icon: const Icon(Symbols.refresh_rounded, size: 22),
              label: const Text('다시 도전'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _backToPlaceInfo(context),
              child: const Text('뒤로 가기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "담양 죽녹원 / 도착 예정 시간 / 인증 상태" 요약 카드.
class _FailInfoCard extends StatelessWidget {
  const _FailInfoCard({
    required this.spot,
    required this.windowLabel,
    this.rejected = false,
  });

  final MockTouristSpot spot;
  final String windowLabel;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Image.asset(
                'assets/illustrations/icon/place_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.forest_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                spot.name,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.divider),
          Row(
            children: [
              const Icon(
                Symbols.schedule_rounded,
                size: 28,
                color: AppColors.secondaryAccent,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '도착 예정 시간: $windowLabel',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                rejected
                    ? Symbols.cancel_rounded
                    : Symbols.hourglass_bottom_rounded,
                size: 28,
                color: rejected ? AppColors.error : AppColors.iconDisabled,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '인증 상태: ',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                rejected ? '반려됨' : '시간 만료',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: rejected ? AppColors.error : AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

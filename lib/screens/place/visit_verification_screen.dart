import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_region_ranking.dart';
import '../../data/visit_verification_overlay.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'visit_fail_screen.dart';
import 'visit_reward_screen.dart';

/// `<방문 인증 확인 페이지>` (user_flow §6) — the screen a visitor shows to a
/// store employee. A 6-digit code sits under the place name/address; the
/// employee checks it on the admin side to complete 방문 인증.
///
/// 두 가지 모드로 동작한다:
///
/// * [session]이 있으면 (백엔드 연동 경로): 서버가 발급한 `verificationCode` /
///   `expiresAt`을 그대로 쓰고, `GET /visit-verifications/{id}`를 폴링해
///   `VERIFIED`면 보상 화면, `EXPIRED`면 실패 화면으로 넘어간다 (스펙 §7).
/// * [session]이 없으면 (목업 경로 — 랭킹/지도가 아직 실 장소 ID를 주지 않음):
///   기존처럼 로컬 랜덤 코드 + 타이머로만 동작하고, 성공은 QA 버튼으로만 낸다.
///
/// 실제 타이머/폴링은 이 화면이 아니라 [VisitVerificationOverlay] 싱글턴이
/// 소유한다 — 그래야 탭 전환 등으로 이 화면이 dispose돼도 카운트다운이 계속
/// 돌아가고, 앱 전역 떠 있는 배지(`VisitTimerOverlay`)로 계속 보여줄 수 있다.
/// 이 State는 그 상태를 구독해 그리기만 한다.
class VisitVerificationScreen extends StatefulWidget {
  const VisitVerificationScreen({
    super.key,
    required this.spot,
    this.window = const Duration(minutes: 15),
    this.session,
    this.benefit,
  });

  final MockTouristSpot spot;

  /// 도착 예정 시간까지 남은 창 (user_flow §6 — 방문 인증 페이지에서 선택).
  final Duration window;

  /// `POST /visit-verifications` 응답. null이면 목업 경로.
  final VisitVerification? session;

  /// `<방문 인증 페이지>`에서 이미 조회해 넘겨준 실 방문 혜택. null이면 목업
  /// `spot.storeBenefit`을 그대로 쓴다.
  final String? benefit;

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  final _overlay = VisitVerificationOverlay.instance;

  bool _navigated = false;
  bool _forcing = false;

  bool get _live => _overlay.live;

  @override
  void initState() {
    super.initState();
    _overlay.start(
      spot: widget.spot,
      session: widget.session,
      benefit: widget.benefit ?? widget.spot.storeBenefit,
      window: widget.window,
    );
    _overlay.screenOpen = true;
    _overlay.addListener(_onOverlayChange);
  }

  @override
  void dispose() {
    _overlay.removeListener(_onOverlayChange);
    // 오버레이 자체(타이머/폴링)는 지우지 않는다 — 대기 중이면 배지로 계속
    // 살아 있어야 한다. 여기서 지우는 건 "이 화면이 지금 안 떠 있다"뿐.
    _overlay.screenOpen = false;
    super.dispose();
  }

  void _onOverlayChange() {
    if (!mounted || _navigated) return;
    switch (_overlay.status) {
      case VisitOverlayStatus.verified:
        _navigated = true;
        final spot = widget.spot;
        final session = _overlay.session;
        final benefit = _overlay.benefit;
        final reward = _overlay.reward;
        _overlay.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VisitRewardScreen(
              spot: spot,
              placeId: session?.placeId,
              visitVerificationId: session?.id,
              benefit: benefit,
              reward: reward,
            ),
          ),
        );
        break;
      case VisitOverlayStatus.expired:
      case VisitOverlayStatus.failed:
        _navigated = true;
        final spot = widget.spot;
        final window = _overlay.window;
        final status = _overlay.status == VisitOverlayStatus.failed
            ? 'FAILED'
            : 'EXPIRED';
        final failReason = _overlay.failReason;
        _overlay.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VisitFailScreen(
              spot: spot,
              window: window,
              status: status,
              failReason: failReason,
            ),
          ),
        );
        break;
      case VisitOverlayStatus.pending:
        setState(() {});
        break;
    }
  }

  /// "인증 상태 확인" 버튼 — 매장 관리자가 이미 승인/반려했는지 즉시 다시
  /// 조회한다. 사용자가 직접 인증을 완료시키는 API는 없다(스펙 §7.4/§10).
  Future<void> _checkNow() async {
    if (_navigated || _forcing || !_live) return;
    setState(() => _forcing = true);
    final message = await _overlay.checkNow();
    if (!mounted) return;
    if (message != null) _snack(message);
    setState(() => _forcing = false);
  }

  /// "신청 취소" — 대기 중(`ISSUED`)인 인증만 취소할 수 있다(스펙 §7.3).
  Future<void> _cancel() async {
    if (_navigated || _forcing || !_live) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
        title: const Text('방문 인증을 취소할까요?'),
        content: const Text('취소하면 이 코드는 더 이상 사용할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('취소할게요'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _forcing = true);
    final message = await _overlay.cancel();
    if (!mounted) return;
    if (message != null) {
      _snack(message);
      setState(() => _forcing = false);
    } else {
      _navigated = true;
      Navigator.of(context).maybePop();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _formattedCode {
    final code = _overlay.code;
    return code.length >= 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;
  }

  String get _formattedTime {
    final remaining = _overlay.remaining;
    final m = remaining.inMinutes.toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final expired = _overlay.remaining == Duration.zero;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('방문 인증 확인'),
      ),
      body: ListView(
        padding: AppBottomNavBar.scrollPadding(
          context,
          const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
        ),
        children: [
          Text(spot.name, textAlign: TextAlign.center, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(
            spot.address,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _CodeCard(
            code: _formattedCode,
            time: _formattedTime,
            expired: expired,
          ),
          const SizedBox(height: AppSpacing.lg),
          _RewardsCard(
            spot: spot,
            benefit: widget.benefit ?? spot.storeBenefit,
            isRealVisit: _live,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _StaffHintCard(),
          const SizedBox(height: AppSpacing.xl),
          if (_live)
            _LiveHintCard(
              onCheckNow: _forcing ? null : _checkNow,
              onCancel: _forcing ? null : _cancel,
            )
          else
            _DebugTransitionRow(
              onForceSuccess: () =>
                  _overlay.forceStatus(VisitOverlayStatus.verified),
              onForceFailure: () =>
                  _overlay.forceStatus(VisitOverlayStatus.expired),
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }
}

/// The bamboo-tinted card holding the "직원에게 이 번호를 보여주세요" code and
/// the countdown.
class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.time,
    required this.expired,
  });

  final String code;
  final String time;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSelected,
            borderRadius: BorderRadius.circular(AppRadius.largeCard),
            boxShadow: AppShadows.card,
          ),
          child: _CodeCardContent(code: code, time: time, expired: expired),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.largeCard),
              child: Image.asset(
                'assets/illustrations/icon/visit_number_icon.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeCardContent extends StatelessWidget {
  const _CodeCardContent({
    required this.code,
    required this.time,
    required this.expired,
  });

  final String code;
  final String time;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '직원에게 이 번호를 보여주세요',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            code,
            style: AppTextStyles.verificationCode.copyWith(
              fontSize: 40,
              height: 1.0,
              color: expired
                  ? AppColors.textDisabled
                  : AppColors.primaryPressed,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '매장 직원이 인증번호를 확인하면\n방문 인증이 완료돼요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CountdownPill(time: time, expired: expired),
      ],
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.time, required this.expired});

  final String time;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.schedule_rounded,
            size: 18,
            color: expired ? AppColors.error : AppColors.secondaryAccent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            expired ? '인증 시간 만료' : '남은 시간',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!expired) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              time,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "이번 방문에서 받을 수 있어요" — visit benefit + obtainable ingredient.
class _RewardsCard extends StatelessWidget {
  const _RewardsCard({
    required this.spot,
    this.benefit,
    required this.isRealVisit,
  });

  final MockTouristSpot spot;
  final String? benefit;

  /// 실 세션(placeId 있음)이면 확률표 합이 1.0이라 방문 인증 시 항상 무언가는
  /// 지급된다(스펙 §7.5) — 어떤 재료인지만 미리 알 수 없을 뿐이라
  /// "획득 재료 없음"이라고 하면 안 된다. 목업 스팟만 `spot.ingredient`로
  /// 있음/없음을 그대로 보여준다.
  final bool isRealVisit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Text(
            '이번 방문에서 받을 수 있어요',
            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RewardRow(
            assetPath: 'assets/illustrations/icon/benefit.png',
            fallbackIcon: Symbols.redeem_rounded,
            iconColor: AppColors.secondaryAccent,
            label: '방문 혜택',
            value: benefit ?? '방문 혜택 없음',
            muted: benefit == null,
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.divider),
          _RewardRow(
            assetPath: 'assets/illustrations/icon/ingredient_4.png',
            fallbackIcon: Symbols.eco_rounded,
            iconColor: AppColors.primary,
            label: '획득 가능한 재료',
            value: isRealVisit
                ? '방문 인증 시 랜덤 재료 획득'
                : (spot.ingredient == null
                      ? '획득 재료 없음'
                      : '${spot.ingredient} ${spot.ingredientCount}개'),
            muted: !isRealVisit && spot.ingredient == null,
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.assetPath,
    required this.fallbackIcon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.muted,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final Color iconColor;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Opacity(
            opacity: muted ? 0.4 : 1.0,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                fallbackIcon,
                size: 32,
                color: muted ? AppColors.iconDisabled : iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 백엔드 연동 경로 — 직원이 admin에서 확인하면 자동으로 다음 화면으로 넘어간다.
/// "인증 상태 확인" 버튼은 즉시 `GET /visit-verifications/{id}`를 다시 조회하고,
/// "신청 취소"는 `POST /visit-verifications/{id}/cancel`을 호출한다 (스펙 §8).
class _LiveHintCard extends StatelessWidget {
  const _LiveHintCard({required this.onCheckNow, required this.onCancel});

  final VoidCallback? onCheckNow;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final busy = onCheckNow == null && onCancel == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.sync_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '직원 확인을 기다리는 중이에요. 확인되면 자동으로 넘어가요.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onCheckNow,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('인증 상태 확인'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('신청 취소'),
          ),
        ],
      ),
    );
  }
}

/// QA 전용 (목업 경로) — 실제 대기 없이 성공/실패 화면 전환을 확인하는 버튼.
class _DebugTransitionRow extends StatelessWidget {
  const _DebugTransitionRow({
    required this.onForceSuccess,
    required this.onForceFailure,
  });

  final VoidCallback onForceSuccess;
  final VoidCallback onForceFailure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QA 전용 — 실제 서비스에는 없는 버튼이에요',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onForceSuccess,
                  child: const Text('바로 성공 처리'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onForceFailure,
                  child: const Text('바로 실패 처리'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "이 화면을 매장 직원에게 보여주세요" reassurance card.
class _StaffHintCard extends StatelessWidget {
  const _StaffHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              'assets/illustrations/icon/staff_desk_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.point_of_sale_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '이 화면을 매장 직원에게 보여주세요.\n직원 확인 후 방문 인증이 완료됩니다.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

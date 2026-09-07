import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'visit_fail_screen.dart';
import 'visit_reward_screen.dart';

/// `<방문 인증 확인 페이지>` (user_flow §6) — the screen a visitor shows to a
/// store employee. A random 6-digit code sits under the place name/address;
/// the employee checks it on the admin side to complete 방문 인증. Also lists
/// the visit benefit + obtainable ingredient and counts down the remaining
/// time.
///
/// * TODO(backend): 인증번호 발급/검증 API 연동 (지금은 로컬 랜덤 생성)
/// * TODO(backend): 직원의 인증 완료를 실시간 수신 (폴링/푸시/소켓) — 지금은
///   화면에서 성공을 감지할 방법이 없음.
/// * TODO: 인증 성공 → `<방문 인증 보상 페이지>`, 시간 초과 → `<방문 인증 실패>`
///   (두 화면 모두 미구현)
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class VisitVerificationScreen extends StatefulWidget {
  const VisitVerificationScreen({
    super.key,
    required this.spot,
    this.window = const Duration(minutes: 15),
  });

  final MockTouristSpot spot;

  /// 도착 예정 시간까지 남은 창 (user_flow §6 — 방문 인증 페이지에서 선택).
  final Duration window;

  @override
  State<VisitVerificationScreen> createState() =>
      _VisitVerificationScreenState();
}

/// One in-flight 방문 인증 attempt. Held in [_activeSessions] (in-memory only —
/// a real backend owns this) so the code and countdown survive leaving the
/// screen and coming back, instead of resetting each visit.
///
/// * TODO(backend): 서버가 발급한 인증번호/만료시각으로 대체
class _VerificationSession {
  const _VerificationSession(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;
}

final Map<String, _VerificationSession> _activeSessions = {};

class _VisitVerificationScreenState extends State<VisitVerificationScreen> {
  late final String _code;
  late final DateTime _expiresAt;
  late Duration _remaining;
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final key = widget.spot.name;
    final now = DateTime.now();
    final existing = _activeSessions[key];

    if (existing != null && existing.expiresAt.isAfter(now)) {
      // Resume the attempt already running for this place.
      _code = existing.code;
      _expiresAt = existing.expiresAt;
    } else {
      // 랜덤 6자리 (100000-999999).
      _code = (100000 + Random().nextInt(900000)).toString();
      _expiresAt = now.add(widget.window);
      _activeSessions[key] = _VerificationSession(_code, _expiresAt);
    }

    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _computeRemaining());
      if (_remaining == Duration.zero) {
        _timer?.cancel();
        _handleFailure();
      }
    });
  }

  Duration _computeRemaining() {
    final left = _expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 실제로는 매장 직원이 admin 쪽에서 인증번호를 확인하면 성공 처리된다
  // (user_flow §6). 그 연동 전까지 테스트용으로 화면 하단 버튼으로 즉시
  // 성공/실패 전환을 트리거할 수 있게 해둠 — 백엔드 연동 후 제거 대상.
  void _handleSuccess() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    _activeSessions.remove(widget.spot.name);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VisitRewardScreen(spot: widget.spot)),
    );
  }

  void _handleFailure() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    _activeSessions.remove(widget.spot.name);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            VisitFailScreen(spot: widget.spot, window: widget.window),
      ),
    );
  }

  String get _formattedCode => '${_code.substring(0, 3)} ${_code.substring(3)}';

  String get _formattedTime {
    final m = _remaining.inMinutes.toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final expired = _remaining == Duration.zero;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
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
          _RewardsCard(spot: spot),
          const SizedBox(height: AppSpacing.lg),
          const _StaffHintCard(),
          const SizedBox(height: AppSpacing.xl),
          // TODO(backend): 실제로는 매장 직원의 admin 확인으로 성공 처리되고
          // 시간 초과로만 자동 실패 처리됨. 그 연동 전까지 QA용으로 즉시
          // 전환할 수 있는 버튼 — 백엔드 연동 후 이 블록 통째로 제거.
          _DebugTransitionRow(
            onForceSuccess: _handleSuccess,
            onForceFailure: _handleFailure,
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
  const _RewardsCard({required this.spot});

  final MockTouristSpot spot;

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
            assetPath: 'assets/illustrations/icon/reward_benefit_icon.png',
            fallbackIcon: Symbols.redeem_rounded,
            iconColor: AppColors.secondaryAccent,
            label: '방문 혜택',
            value: spot.storeBenefit ?? '방문 혜택 없음',
            muted: spot.storeBenefit == null,
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.divider),
          _RewardRow(
            assetPath: 'assets/illustrations/icon/reward_ingredient_icon.png',
            fallbackIcon: Symbols.eco_rounded,
            iconColor: AppColors.primary,
            label: '획득 가능한 재료',
            value: spot.ingredient == null
                ? '획득 재료 없음'
                : '${spot.ingredient} ${spot.ingredientCount}개',
            muted: spot.ingredient == null,
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

/// QA 전용 — 실제 대기 없이 성공/실패 화면 전환을 즉시 확인하기 위한 버튼.
/// 매장 직원 admin 확인 연동이 붙으면 통째로 제거한다.
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

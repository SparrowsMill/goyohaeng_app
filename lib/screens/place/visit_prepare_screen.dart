import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'visit_verification_screen.dart';

/// `<방문 인증 페이지>` (user_flow §6) — the step between `<장소 정보 페이지>`'s
/// 방문 인증 button and `<방문 인증 확인 페이지>`. Shows the visit benefit +
/// obtainable ingredient, then asks for an estimated arrival window
/// (10분 / 30분 / 1시간 이내). "갈 준비 완료!" carries the chosen window into
/// the verification screen.
///
/// * TODO: 인증 실패 → `<방문 인증 실패>` 연결 (user_flow §6)
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class VisitPrepareScreen extends StatefulWidget {
  const VisitPrepareScreen({super.key, required this.spot});

  final MockTouristSpot spot;

  @override
  State<VisitPrepareScreen> createState() => _VisitPrepareScreenState();
}

class _VisitPrepareScreenState extends State<VisitPrepareScreen> {
  static const _options = <({String label, Duration window})>[
    (label: '10분 이내', window: Duration(minutes: 10)),
    (label: '30분 이내', window: Duration(minutes: 30)),
    (label: '1시간 이내', window: Duration(minutes: 60)),
  ];

  int _selected = 1;

  void _confirm() {
    // * TODO(backend): 선택한 도착 예정 시간으로 방문 인증 세션 생성 요청 —
    //   서버가 인증번호/만료시각을 발급하도록.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitVerificationScreen(
          spot: widget.spot,
          window: _options[_selected].window,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('방문 인증'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _Header(spot: spot),
          const SizedBox(height: AppSpacing.xl),
          _RewardCard(
            icon: Symbols.redeem_rounded,
            iconColor: AppColors.secondaryAccent,
            label: '방문 혜택',
            value: spot.storeBenefit ?? '방문 혜택 없음',
            note: '방문 인증 완료 후 현장에서 혜택을\n확인할 수 있어요.',
            muted: spot.storeBenefit == null,
          ),
          const SizedBox(height: AppSpacing.lg),
          _RewardCard(
            icon: Symbols.eco_rounded,
            iconColor: AppColors.primary,
            label: '획득 가능한 재료',
            value: spot.ingredient == null
                ? '획득 재료 없음'
                : '${spot.ingredient} ${spot.ingredientCount}개',
            note: '방문 인증을 완료하면 재료가\n자동으로 지급돼요.',
            muted: spot.ingredient == null,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ArrivalCard(
            options: [for (final o in _options) o.label],
            selected: _selected,
            onChanged: (i) => setState(() => _selected = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: const Icon(Symbols.backpack_rounded, size: 22),
              label: const Text('갈 준비 완료!'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _leaf(flip: true),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '도착 후 장소에서 방문 인증을 완료해 주세요.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: AppSpacing.xs),
              _leaf(flip: false),
            ],
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

  Widget _leaf({required bool flip}) {
    final img = Image.asset(
      'assets/branding/leaf_ornament.png',
      width: 14,
      height: 14,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 14),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // * TODO(asset): 장소 대표 이미지 — 준비 전까지 아이콘 플레이스홀더
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceSelected,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Icon(
            Symbols.forest_rounded,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.name, style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '방문을 준비하면 아래 혜택을 받을 수 있어요',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.note,
    required this.muted,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String note;
  final bool muted;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // * TODO(asset): 방문 혜택/재료 일러스트 — 준비 전까지 아이콘 사용
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceSelected,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: muted ? AppColors.iconDisabled : iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(
                    color:
                        muted ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  note,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Text(
            '언제쯤 도착할 예정인가요?',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '도착 예정 시간을 알려주시면 방문 인증을 준비할게요.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < options.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.sm),
            _ArrivalOption(
              label: options[i],
              selected: i == selected,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrivalOption extends StatelessWidget {
  const _ArrivalOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Symbols.check_circle_rounded
                    : Symbols.radio_button_unchecked_rounded,
                size: 20,
                color: selected
                    ? AppColors.textOnPrimaryButton
                    : AppColors.iconInactive,
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.textOnPrimaryButton
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

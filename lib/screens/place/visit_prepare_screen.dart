import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_region_ranking.dart';
import '../../data/place_business_status_cache.dart';
import '../../data/place_verification_cache.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/category_illustration.dart';
import 'visit_verification_screen.dart';

/// `<방문 인증 페이지>` (user_flow §6) — the step between `<장소 정보 페이지>`'s
/// 방문 인증 button and `<방문 인증 확인 페이지>`. Shows the visit benefit +
/// obtainable ingredient, then asks for an estimated arrival window
/// (10분 / 30분 / 1시간 이내). "갈 준비 완료!" carries the chosen window into
/// the verification screen.
///
/// [placeId]가 있으면 "갈 준비 완료!"에서 `POST /visit-verifications`로 실제
/// 세션을 만들어 서버 발급 인증번호/만료시각을 다음 화면에 넘긴다 (스펙 §7.1).
/// 없으면 (랭킹/지도가 아직 목업) 로컬 시뮬레이션 경로로 진행한다.
///
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class VisitPrepareScreen extends StatefulWidget {
  const VisitPrepareScreen({super.key, required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  @override
  State<VisitPrepareScreen> createState() => _VisitPrepareScreenState();
}

class _VisitPrepareScreenState extends State<VisitPrepareScreen> {
  static const _options = <({String label, int minutes, Duration window})>[
    (label: '10분 이내', minutes: 10, window: Duration(minutes: 10)),
    (label: '30분 이내', minutes: 30, window: Duration(minutes: 30)),
    (label: '1시간 이내', minutes: 60, window: Duration(minutes: 60)),
  ];

  int _selected = 1;
  bool _submitting = false;
  String? _liveBenefit;

  final _service = VisitVerificationService();

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .detail(id)
          .then((place) {
            PlaceVerificationCache.set(
              id,
              place.verification?.enabled ?? false,
            );
            PlaceBusinessStatusCache.set(id, place.isOpenNow);
            if (mounted) setState(() => _liveBenefit = place.benefitLabel);
          })
          .catchError((_) {
            /* 목업 값 유지 */
          });
      // 화면 최초 진입 1회만, fire-and-forget — 실패해도 화면엔 영향 없음.
      AnalyticsService()
          .logEvent(placeId: id, eventType: 'VISIT_AUTH_PAGE_ENTER')
          .catchError((_) {});
    }
  }

  String? get _benefit => _liveBenefit ?? widget.spot.storeBenefit;

  Future<void> _confirm() async {
    final option = _options[_selected];

    if (widget.placeId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisitVerificationScreen(
            spot: widget.spot,
            window: option.window,
            benefit: _benefit,
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final session = await _service.create(
        placeId: widget.placeId!,
        arrivalOptionMinutes: option.minutes,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisitVerificationScreen(
            spot: widget.spot,
            window: option.window,
            session: session,
            benefit: _benefit,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          _Header(spot: spot),
          const SizedBox(height: AppSpacing.xl),
          _RewardCard(
            assetPath: 'assets/illustrations/icon/benefit.png',
            fallbackIcon: Symbols.redeem_rounded,
            iconColor: AppColors.secondaryAccent,
            label: '방문 혜택',
            value: _benefit ?? '방문 혜택 없음',
            note: '방문 인증 완료 후 현장에서 혜택을\n확인할 수 있어요.',
            muted: _benefit == null,
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
            child: ElevatedButton(
              onPressed: _submitting ? null : _confirm,
              child: _submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimaryButton,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text('준비 중...'),
                      ],
                    )
                  : const Text('갈 준비 완료!'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _leaf(flip: true),
              const SizedBox(width: AppSpacing.xs),
              Text('도착 후 장소에서 방문 인증을 완료해 주세요.', style: AppTextStyles.caption),
              const SizedBox(width: AppSpacing.xs),
              _leaf(flip: false),
            ],
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _leaf({required bool flip}) {
    final img = Image.asset(
      'assets/branding/leaf_ornament_3.png',
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
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceSelected,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: CategoryIllustration(spot: spot, size: 72),
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
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
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
    required this.assetPath,
    required this.fallbackIcon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.note,
    required this.muted,
  });

  final String assetPath;
  final IconData fallbackIcon;
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
          SizedBox(
            width: 34,
            height: 34,
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
                  style: AppTextStyles.h3.copyWith(
                    color: muted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
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
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
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

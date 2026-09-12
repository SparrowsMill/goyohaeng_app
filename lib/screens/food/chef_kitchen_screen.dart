import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_food_info.dart';
import '../../data/mock_foods.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../share/sns_share_sheet.dart';
import 'my_food_screen.dart';

/// `<셰프의 주방>` (user_flow §4) — 음식 정보에서 "만들기"를 눌렀을 때. 음식
/// 이름·소모 재료 표시 → 제작 → 완성 일러스트 → 공유(SNS / 기록용 플랫폼) 또는
/// "확인".
///
/// 뼈대만 구현 — "요리 시작" → `_CookingDialog`(요리 중 모달, 진행 점) 을 띄우고
/// 2.2초 뒤 스스로 닫히면 완성 카드로 전환. 공유 플로우(§7)는 미구현이라 스낵바.
///
/// * TODO: 제작 애니메이션 (현재는 `_CookingDialog` 진행 점 + 시간 경과로 대체).
/// * TODO: SNS 공유 → `<SNS에 공유>` (§7).
/// * TODO: 기록용 플랫폼 공유 → `<기록용 플랫폼에 공유>` (§7).
/// * TODO(backend): "요리 시작" 시 재료 소모 반영 API 연동.
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/chef_kitchen_bg.png` (§9, 주방 헤더 밴드 PNG).
class ChefKitchenScreen extends StatefulWidget {
  const ChefKitchenScreen({super.key, required this.info});

  final FoodInfo info;

  @override
  State<ChefKitchenScreen> createState() => _ChefKitchenScreenState();
}

enum _Phase { prep, done }

class _ChefKitchenScreenState extends State<ChefKitchenScreen> {
  _Phase _phase = _Phase.prep;

  void _todo(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startCooking() async {
    // 제작 "애니메이션" 대체 — 요리 중 모달을 띄우고, 지정 시간 뒤 스스로 닫히면
    // 완성 상태로 전환한다. (* TODO: 실제 제작 애니메이션)
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8C1E160E),
      builder: (_) => const _CookingDialog(
        duration: Duration(milliseconds: 2200),
      ),
    );
    if (mounted) setState(() => _phase = _Phase.done);
  }

  /// "확인" — 방금 만든 음식을 "내가 만든 음식" 맨 앞에 추가하고 `<본인 음식 보기>`
  /// 로 돌아간다. (스택에 없으면 첫 화면까지 pop)
  void _finish(BuildContext context, FoodInfo info) {
    MyFoodsStore.instance.markMade(
      slug: info.slug,
      name: info.name,
      description: info.description,
    );
    Navigator.of(context).popUntil(
      (route) => route.settings.name == MyFoodScreen.routeName || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderBar(
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 상단 헤더 밴드 scene. 납품 전까지 errorBuilder 로 아무것도
                    // 그리지 않고 #FAE7C0 base 가 그대로 보이게 둔다.
                    Image.asset(
                      'assets/illustrations/scenes/chef_kitchen_bg.png',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                      ),
                      child: _phase == _Phase.done
                          ? _DoneCard(
                              info: info,
                              onShareSns: () => showSnsShareSheet(context),
                              onShareRecord: () =>
                                  _todo('기록용 플랫폼 공유는 준비 중이에요.'),
                              onConfirm: () => _finish(context, info),
                            )
                          : _PrepCard(info: info),
                    ),
                  ],
                ),
              ),
            ),
            if (_phase == _Phase.prep)
              _PrepBottomBar(onStart: _startCooking),
          ],
        ),
      ),
    );
  }
}

/// 요리 중 모달 — 셰프 참새 일러스트 + 진행 점. [duration] 이 끝나면 스스로 닫힌다.
///
/// * TODO(asset): `assets/illustrations/sparrow/sparrow_cooking.png` 미납품 —
///   그 전까지 냄비 아이콘 placeholder.
class _CookingDialog extends StatefulWidget {
  const _CookingDialog({required this.duration});

  final Duration duration;

  @override
  State<_CookingDialog> createState() => _CookingDialogState();
}

class _CookingDialogState extends State<_CookingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).pop();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.huge,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  'assets/illustrations/sparrow/sparrow_cooking.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Symbols.skillet_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('보글보글 요리 중...', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '셰프 참새가 정성껏 만들고 있어요!',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    const Expanded(
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Leaf(flip: false),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _ProgressDots(progress: _controller.value),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Icon(
                Symbols.soup_kitchen_rounded,
                size: 20,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 진행 점 — [progress] (0~1) 에 비례해 왼쪽부터 채워진다.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.progress});

  final double progress;

  static const _count = 8;

  @override
  Widget build(BuildContext context) {
    const count = _count;
    final filled = (progress * count).round().clamp(0, count);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i != 0) const SizedBox(width: AppSpacing.sm),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? AppColors.primary : Colors.transparent,
              border: i < filled
                  ? null
                  : Border.all(color: AppColors.border, width: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Leaf(flip: true),
                const SizedBox(width: AppSpacing.sm),
                Text('셰프의 주방', style: AppTextStyles.h2),
                const SizedBox(width: AppSpacing.sm),
                _Leaf(flip: false),
              ],
            ),
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Symbols.arrow_back_rounded),
                  color: AppColors.iconPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 제작 전 카드 — 이름, 설명, 실루엣 일러스트, 소모 재료.
class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.info});

  final FoodInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('오늘 만들 음식'),
          const SizedBox(height: AppSpacing.sm),
          Text(info.name, textAlign: TextAlign.center, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            info.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FoodIllustration(info: info, revealed: false),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceSelected,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Symbols.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '필요한 재료가 모두 준비되었어요',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ing in info.ingredients)
                      Expanded(child: _ConsumedTile(ingredient: ing)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 완성 카드 — 컬러 일러스트 + 완성 배너 + 특별 재료 + 공유하기.
class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.info,
    required this.onShareSns,
    required this.onShareRecord,
    required this.onConfirm,
  });

  final FoodInfo info;
  final VoidCallback onShareSns;
  final VoidCallback onShareRecord;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('오늘 만든 음식'),
          const SizedBox(height: AppSpacing.sm),
          Text(info.name, textAlign: TextAlign.center, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            info.completedText,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              _FoodIllustration(info: info, revealed: true),
              const Positioned(top: -12, child: _CompletionBanner()),
            ],
          ),
          if (info.specialNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const _MiniLabel('특별 재료'),
            const SizedBox(height: AppSpacing.md),
            _SpecialNotesRow(notes: info.specialNotes),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _MiniLabel('공유하기'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  label: 'SNS 공유',
                  icon: Symbols.share_rounded,
                  background: AppColors.primary,
                  onTap: onShareSns,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ShareButton(
                  label: '기록용 플랫폼 공유',
                  icon: Symbols.menu_book_rounded,
                  background: AppColors.textSecondary,
                  onTap: onShareRecord,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onConfirm,
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일러스트 상단에 얹히는 "요리 완성!" 초록 배너.
class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.eco_rounded, size: 13,
              color: AppColors.textOnPrimaryButton),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '요리 완성!',
            style: AppTextStyles.buttonMedium
                .copyWith(color: AppColors.textOnPrimaryButton),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Symbols.eco_rounded, size: 13,
              color: AppColors.textOnPrimaryButton),
        ],
      ),
    );
  }
}

/// 특별 재료 2열 카드.
class _SpecialNotesRow extends StatelessWidget {
  const _SpecialNotesRow({required this.notes});

  final List<SpecialNote> notes;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            if (i != 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _SpecialNoteCard(note: notes[i])),
          ],
        ],
      ),
    );
  }
}

class _SpecialNoteCard extends StatelessWidget {
  const _SpecialNoteCard({required this.note});

  final SpecialNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Image.asset(
              note.illustrationPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Symbols.grocery_rounded,
                size: 26,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(note.note, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 채워진 공유 버튼(색 지정).
class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.textOnPrimaryButton),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.textOnPrimaryButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 가운데 정렬 잎 장식 라벨 (특별 재료 / 공유하기).
class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Leaf(flip: true),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.title),
        const SizedBox(width: AppSpacing.sm),
        _Leaf(flip: false),
      ],
    );
  }
}

class _FoodIllustration extends StatelessWidget {
  const _FoodIllustration({required this.info, required this.revealed});

  final FoodInfo info;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          color: AppColors.surfaceSelected,
          alignment: Alignment.center,
          child: Opacity(
            opacity: revealed ? 1 : 0.35,
            child: Image.asset(
              info.illustrationPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Symbols.ramen_dining_rounded,
                  size: 56,
                  color: AppColors.iconInactive,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 소모 재료 하나 — 아이콘 + 이름 + "n / n" + 체크.
class _ConsumedTile extends StatelessWidget {
  const _ConsumedTile({required this.ingredient});

  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          ingredient.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            ingredient.illustrationPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Symbols.grocery_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${ingredient.required} / ${ingredient.required}',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Icon(
          Symbols.check_circle_rounded,
          size: 14,
          color: AppColors.success,
        ),
      ],
    );
  }
}

/// 제작 전 하단 고정 영역 — 안내 + "요리 시작".
class _PrepBottomBar extends StatelessWidget {
  const _PrepBottomBar({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _HelperLine(text: '지금 가진 재료로 만들 수 있어요.'),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Symbols.soup_kitchen_rounded, size: 20),
                label: const Text('요리 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelperLine extends StatelessWidget {
  const _HelperLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Leaf(flip: true),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _Leaf(flip: false),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Leaf(flip: true),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Leaf(flip: false),
      ],
    );
  }
}

/// 브랜드 잎 장식(작게). 아직 파일이 없을 때를 대비해 errorBuilder 로 대체.
class _Leaf extends StatelessWidget {
  const _Leaf({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/branding/leaf_ornament.png',
      width: 16,
      height: 16,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 16),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}

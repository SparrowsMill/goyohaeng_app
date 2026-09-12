import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../record/footprint_write_screen.dart';
import '../share/sns_share_sheet.dart';
import 'my_food_screen.dart';

/// `<셰프의 주방>` (user_flow §4) — 음식 정보에서 "만들기"를 눌렀을 때. 음식
/// 이름·소모 재료 표시 → 실제 제작(`POST /foods/{id}/make`, 스펙 §10.3) → 완성
/// 일러스트 → 공유(SNS / 기록용 플랫폼) 또는 "확인".
///
/// "요리 시작"을 누르면 `_CookingDialog`(요리 중 모달, 진행 점 애니메이션)를
/// 띄운 채로 실제 네트워크 요청을 기다린다 — 더 이상 고정 시간 뒤 자동 성공하지
/// 않는다. 재료 부족(`MakeFoodShortage`)이면 완성 카드 없이 안내만 보여주고
/// 준비 화면에 머문다.
///
/// * TODO: SNS 공유 → `<SNS에 공유>` (§7).
/// * TODO: 기록용 플랫폼 공유 → `<기록용 플랫폼에 공유>` (§7).
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/chef_kitchen_bg.png` (§9, 주방 헤더 밴드 PNG).
class ChefKitchenScreen extends StatefulWidget {
  const ChefKitchenScreen({super.key, required this.food});

  final Food food;

  @override
  State<ChefKitchenScreen> createState() => _ChefKitchenScreenState();
}

enum _Phase { prep, done }

class _ChefKitchenScreenState extends State<ChefKitchenScreen> {
  _Phase _phase = _Phase.prep;

  /// 제작 성공 후 서버가 내려준 결과(특별 재료 등) — 완성 카드에 사용.
  MakeFoodResult? _result;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _shortageMessage(MakeFoodShortage e) {
    if (e.missing.isEmpty) return e.message;
    final parts = e.missing.map((m) => '${m.name} ${m.shortage}개 부족').join(', ');
    return '재료가 부족해요: $parts';
  }

  Future<void> _startCooking() async {
    if (!AuthStore.instance.isSignedIn) {
      _snack('로그인이 필요해요.');
      return;
    }

    // 요리 중 모달을 띄운 채로 실제 `POST /foods/{id}/make` 요청을 기다린다.
    // 애니메이션은 반복 재생만 하고, 요청이 끝나면 화면에서 직접 닫는다.
    final outcome = await showDialog<_CookOutcome>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8C1E160E),
      builder: (_) => _CookingDialog(task: () => FoodService().make(widget.food.id)),
    );
    if (!mounted || outcome == null) return;

    final error = outcome.error;
    if (error != null) {
      if (error is MakeFoodShortage) {
        _snack(_shortageMessage(error));
      } else if (error is ApiException) {
        _snack(error.message);
      } else {
        _snack('음식을 만들지 못했어요.');
      }
      return;
    }

    final result = outcome.result!;
    DashboardStore.instance.refresh();
    setState(() {
      _result = result;
      _phase = _Phase.done;
    });
  }

  /// "기록 플랫폼" 공유 → `<기록 플랫폼 글쓰기>` (user_flow §4→§8). 방금 만든
  /// 음식을 `initialUserFoodId`로 실어 넘겨서, 저장 시 `RecordService().
  /// create()`가 그 `UserFood`를 기록에 연결할 수 있게 한다(`visit_reward_
  /// screen.dart`의 같은 공유 버튼과 동일한 패턴).
  void _shareToRecord(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FootprintWriteScreen(
          initialUserFoodId: _result?.userFood?.id,
          initialUserFoodName: widget.food.name,
        ),
      ),
    );
  }

  /// "확인" — `<본인 음식 보기>` 를 새로 열어 방금 만든 음식이 반영된 최신
  /// 목록을 보여준다(이전 화면 스택을 그대로 재사용하면 이미 불러온 목록이
  /// 갱신되지 않으므로, 첫 화면까지 스택을 정리하고 새 인스턴스를 띄운다).
  void _finish(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyFoodScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
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
                              food: food,
                              result: _result,
                              onShareSns: () => showSnsShareSheet(
                                context,
                                shareText: '고요행에서 ${food.name}을(를) 만들었어요!',
                              ),
                              onShareRecord: () => _shareToRecord(context),
                              onConfirm: () => _finish(context),
                            )
                          : _PrepCard(food: food),
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

/// `_CookingDialog` 의 결과 — 성공 시 [result], 실패 시 [error] 중 하나만 채워진다.
class _CookOutcome {
  const _CookOutcome.success(this.result) : error = null;
  const _CookOutcome.failure(this.error) : result = null;

  final MakeFoodResult? result;
  final Object? error;
}

/// 요리 중 모달 — 셰프 참새 일러스트 + 진행 점(반복 재생). [task] 가 끝나면
/// (성공/실패 모두) 스스로 결과를 안고 닫힌다.
///
/// * TODO(asset): `assets/illustrations/sparrow/sparrow_cooking.png` 미납품 —
///   그 전까지 냄비 아이콘 placeholder.
class _CookingDialog extends StatefulWidget {
  const _CookingDialog({required this.task});

  final Future<MakeFoodResult> Function() task;

  @override
  State<_CookingDialog> createState() => _CookingDialogState();
}

class _CookingDialogState extends State<_CookingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await widget.task();
      if (mounted) Navigator.of(context).pop(_CookOutcome.success(result));
    } catch (e) {
      if (mounted) Navigator.of(context).pop(_CookOutcome.failure(e));
    }
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

/// 진행 점 — [progress] (0~1, 반복) 에 비례해 왼쪽부터 채워진다.
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
  const _PrepCard({required this.food});

  final Food food;

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
          Text(food.name, textAlign: TextAlign.center, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            food.description ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FoodIllustration(food: food, revealed: false),
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
                    for (final ing in food.ingredients)
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
    required this.food,
    required this.result,
    required this.onShareSns,
    required this.onShareRecord,
    required this.onConfirm,
  });

  final Food food;
  final MakeFoodResult? result;
  final VoidCallback onShareSns;
  final VoidCallback onShareRecord;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // `MakeFoodResult.userFood`엔 specialIngredients가 안 들어있다 — RARE/
    // LEGENDARY 여부는 top-level `usedIngredients[].rarity`로 판단한다
    // (스펙 §8.3 실제 응답 예시로 확인됨, 2026-09-13).
    final specialIngredients = (result?.usedIngredients ?? const [])
        .where((i) => i.rarity == 'RARE' || i.rarity == 'LEGENDARY')
        .toList();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('오늘 만든 음식'),
          const SizedBox(height: AppSpacing.sm),
          Text(food.name, textAlign: TextAlign.center, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            food.description ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              _FoodIllustration(food: food, revealed: true),
              const Positioned(top: -12, child: _CompletionBanner()),
            ],
          ),
          if (specialIngredients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const _MiniLabel('특별 재료'),
            const SizedBox(height: AppSpacing.md),
            _SpecialIngredientsRow(items: specialIngredients),
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

/// 특별 재료(RARE/LEGENDARY, `MakeFoodResult.usedIngredients`에서 걸러냄)
/// 2열 카드. 서버 응답에는 재료별 이미지 URL 이 없으므로 항상 범용 아이콘을
/// 쓴다.
class _SpecialIngredientsRow extends StatelessWidget {
  const _SpecialIngredientsRow({required this.items});

  final List<UserFoodSpecialIngredient> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _SpecialIngredientCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

const _rarityNoteLabels = <String, String>{
  'COMMON': '일반 등급 재료',
  'UNCOMMON': '고급 등급 재료',
  'RARE': '희귀 등급 재료',
  'LEGENDARY': '전설 등급 재료',
};

class _SpecialIngredientCard extends StatelessWidget {
  const _SpecialIngredientCard({required this.item});

  final UserFoodSpecialIngredient item;

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
          const Icon(
            Symbols.grocery_rounded,
            size: 26,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _rarityNoteLabels[item.rarity] ?? '특별 재료',
                  style: AppTextStyles.caption,
                ),
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
  const _FoodIllustration({required this.food, required this.revealed});

  final Food food;
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
            child: _NetOrIcon(
              url: food.imageUrl ?? food.illustrationUrl,
              icon: Symbols.ramen_dining_rounded,
              color: AppColors.iconInactive,
              fit: BoxFit.cover,
              iconSize: 56,
            ),
          ),
        ),
      ),
    );
  }
}

/// 소모 재료 하나 — 아이콘 + 이름 + "필요량 / 필요량" + 체크.
class _ConsumedTile extends StatelessWidget {
  const _ConsumedTile({required this.ingredient});

  final FoodIngredient ingredient;

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
          child: _NetOrIcon(
            url: ingredient.imageUrl ?? ingredient.illustrationUrl,
            icon: Symbols.grocery_rounded,
            color: AppColors.primary,
            iconSize: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${ingredient.requiredQuantity} / ${ingredient.requiredQuantity}',
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

/// 서버 이미지 URL 이 있으면 네트워크 이미지를, 없거나 로드 실패 시 아이콘을
/// 보여준다 (§6 — placeholder 대신 기존 errorBuilder 패턴 유지).
class _NetOrIcon extends StatelessWidget {
  const _NetOrIcon({
    required this.url,
    required this.icon,
    required this.color,
    this.fit = BoxFit.contain,
    this.iconSize,
  });

  final String? url;
  final IconData icon;
  final Color color;
  final BoxFit fit;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return Center(child: Icon(icon, size: iconSize, color: color));
    }
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Center(child: Icon(icon, size: iconSize, color: color)),
    );
  }
}

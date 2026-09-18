import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/food_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/reward_image.dart';
import 'food_info_screen.dart';

/// `<재료 상세 페이지>` (user_flow §5) — 재료 가방에서 재료 하나를 눌렀을 때 뜨는
/// 모달. 재료 이름·보유 개수·재료 특성·사용되는 음식·GAP 기반 획득 방법을
/// 보여준다.
///
/// `GET /ingredients/{ingredientId}` (스펙 §9.1) 로 실 데이터를 읽는다.
/// "사용되는 음식" 탭 시 실제 `foodId` 로 `<음식 정보>` 로 이동한다.
///
/// * TODO(backend gap): 예전 mock 의 "획득 가능한 장소"(구체적인 장소 이름 목록)
///   에 대응하는 API 필드가 없다 — `acquisitionPlaces` 는 스펙상 일반 GAP 방문
///   보상 출처로 쓰지 않게 명시되어 있음. 대신 `acquisition.description` +
///   `dropProbabilities` (GAP 구간별 확률) 을 그대로 표시한다.
Future<void> showIngredientDetail(
  BuildContext context, {
  required int ingredientId,
  String? initialName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x8C1E160E),
    builder: (_) => _IngredientDetailDialog(
      ingredientId: ingredientId,
      initialName: initialName,
    ),
  );
}

const _rarityLabels = <String, String>{
  'COMMON': '일반',
  'UNCOMMON': '고급',
  'RARE': '희귀',
  'LEGENDARY': '전설',
};

class _IngredientDetailDialog extends StatefulWidget {
  const _IngredientDetailDialog({required this.ingredientId, this.initialName});

  final int ingredientId;
  final String? initialName;

  @override
  State<_IngredientDetailDialog> createState() =>
      _IngredientDetailDialogState();
}

typedef _IngredientDetailData = ({
  IngredientDetail detail,
  List<IngredientUsedFood> usedFoods,
});

class _IngredientDetailDialogState extends State<_IngredientDetailDialog> {
  late Future<_IngredientDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_IngredientDetailData> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    final detail = await IngredientService().detail(widget.ingredientId);
    // 아직 안 연 콘텐츠(비수도권 전설 음식 등, `FoodCatalog.isOpen` 참고)는
    // 음식 도감/재료 가방과 마찬가지로 여기서도 걸러 숨긴다 — 에셋만 없는
    // 게 아니라 애초에 지금 열려 있지 않은 음식이라 목록에 보이면 안 된다.
    final usedFoods = detail.usedFoods
        .where((food) => FoodCatalog.isOpen(food.name))
        .toList();
    return (detail: detail, usedFoods: usedFoods);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.huge,
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FutureBuilder<_IngredientDetailData>(
          future: _future,
          builder: (context, snapshot) {
            final detail = snapshot.data?.detail;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  title: detail?.name ?? widget.initialName ?? '재료 정보',
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: LoadingOverlay(
                      loading:
                          snapshot.connectionState != ConnectionState.done,
                      child: _buildBody(context, snapshot),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<_IngredientDetailData> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      // The LoadingOverlay above already shows the loading pill.
      return const SizedBox(height: AppSpacing.massive);
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '재료 정보를 불러오지 못했어요.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final detail = snapshot.data!.detail;
    final usedFoods = snapshot.data!.usedFoods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CharacteristicsSection(detail: detail),
        if (usedFoods.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionLabel('사용되는 음식'),
          const SizedBox(height: AppSpacing.md),
          _UsedInFoodsGrid(
            foods: usedFoods,
            onTapFood: (food) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FoodInfoScreen(foodId: food.foodId),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        const _SectionLabel('획득 방법'),
        const SizedBox(height: AppSpacing.md),
        _AcquisitionSection(acquisition: detail.acquisition),
      ],
    );
  }
}

/// 가운데 정렬 제목 + 닫기(X).
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.md,
        0,
      ),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(title, style: AppTextStyles.h2),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Symbols.close_rounded),
                color: AppColors.iconInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 재료 일러스트 + "재료 특성" 카드.
class _CharacteristicsSection extends StatelessWidget {
  const _CharacteristicsSection({required this.detail});

  final IngredientDetail detail;

  @override
  Widget build(BuildContext context) {
    final regionName = detail.acquisition?.region?['name'] as String?;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: detail.obtained ? 1 : 0.4,
          child: SizedBox(
            width: 108,
            height: 108,
            child: RewardImage(
              name: detail.name,
              folder: RewardAssetFolder.ingredient,
              networkUrl: detail.imageUrl ?? detail.illustrationUrl,
              icon: Symbols.grocery_rounded,
              color: detail.obtained
                  ? AppColors.primary
                  : AppColors.iconDisabled,
              iconSize: 56,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '재료 특성',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.md),
                _CharRow(
                  icon: Symbols.inventory_2_rounded,
                  label: '보유 수량',
                  trailing: '${detail.quantity}개',
                  trailingColor: detail.obtained
                      ? AppColors.success
                      : AppColors.textDisabled,
                ),
                const SizedBox(height: AppSpacing.sm),
                _CharRow(
                  icon: Symbols.eco_rounded,
                  label: detail.ingredientType == 'REGIONAL'
                      ? '지역별 재료'
                      : '기본 재료',
                ),
                if (detail.rarity != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CharRow(
                    icon: Symbols.auto_awesome_rounded,
                    label:
                        '희귀도: ${_rarityLabels[detail.rarity] ?? detail.rarity}',
                  ),
                ],
                if (detail.description != null &&
                    detail.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CharRow(
                    icon: Symbols.nutrition_rounded,
                    label: detail.description!,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _CharRow(
                  icon: Symbols.location_on_rounded,
                  label: detail.regionId != null
                      ? (regionName != null ? '$regionName 특산 재료' : '지역 특산 재료')
                      : '지역 특산 재료 아님',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CharRow extends StatelessWidget {
  const _CharRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: trailingColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// 왼쪽 정렬 섹션 제목 — 양옆에 작은 잎 장식.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.title),
        const SizedBox(width: AppSpacing.xs),
        _Leaf(flip: true),
      ],
    );
  }
}

class _UsedInFoodsGrid extends StatelessWidget {
  const _UsedInFoodsGrid({required this.foods, required this.onTapFood});

  final List<IngredientUsedFood> foods;
  final ValueChanged<IngredientUsedFood> onTapFood;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: foods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 96,
      ),
      itemBuilder: (context, index) {
        final food = foods[index];
        return _UsedFoodTile(food: food, onTap: () => onTapFood(food));
      },
    );
  }
}

class _UsedFoodTile extends StatelessWidget {
  const _UsedFoodTile({required this.food, required this.onTap});

  final IngredientUsedFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.surfaceSelected,
                    child: RewardImage(
                      name: food.name,
                      folder: RewardAssetFolder.dish,
                      networkUrl: food.imageUrl ?? food.illustrationUrl,
                      icon: Symbols.dinner_dining_rounded,
                      color: AppColors.iconInactive,
                      fit: BoxFit.cover,
                      iconSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
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

/// GAP 정책 코드 → "자세히 보기" 구간 목록에서 표시할 순서(낮음 → 높음).
const _tierOrder = ['GAP_LOW', 'GAP_MID', 'GAP_HIGH', 'GAP_TOP'];

/// GAP 기반 획득 방법 — 서버 설명 + 정책별 확률을 그대로 표시한다(스펙 §9.1,
/// §14-14: 프론트에서 확률을 계산하거나 예측하지 않는다). "자세히 보기"를
/// 누르면 구간별 확률 막대가 펼쳐진다.
class _AcquisitionSection extends StatefulWidget {
  const _AcquisitionSection({required this.acquisition});

  final IngredientAcquisition? acquisition;

  @override
  State<_AcquisitionSection> createState() => _AcquisitionSectionState();
}

class _AcquisitionSectionState extends State<_AcquisitionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final acq = widget.acquisition;
    if (acq == null ||
        ((acq.description == null || acq.description!.trim().isEmpty) &&
            acq.dropProbabilities.isEmpty)) {
      return Text(
        '획득 방법 정보가 없어요.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }

    final byPolicy = {for (final p in acq.dropProbabilities) p.policyCode: p};
    final tierProbabilities = [
      for (final code in _tierOrder)
        if (byPolicy[code] != null) byPolicy[code]!,
    ];
    final noGap = byPolicy['NO_GAP'];

    // 실제 데이터 기준으로 "낮음/높음" 카드 문구를 정한다 — 일반 재료는 갭지수
    // 낮은(잘 알려진) 곳에서 잘 나오지만, 희귀 재료는 반대일 수 있어 방향을
    // 하드코딩하지 않는다.
    final lowP = byPolicy['GAP_LOW']?.probability;
    final topP = byPolicy['GAP_TOP']?.probability;
    final favorsLowGap = !(lowP != null && topP != null && topP > lowP);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (acq.description != null && acq.description!.trim().isNotEmpty)
          _AcquisitionHint(description: acq.description!),
        if (tierProbabilities.length >= 2) ...[
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _GapDirectionCard(
                    title: '고요 지수 높음',
                    icon: Symbols.trending_up_rounded,
                    resultLabel:
                        favorsLowGap ? '등장 확률이\n낮아요!' : '등장 확률이\n높아요!',
                    caption: '주목받지만\n한적한 곳이에요.',
                    color: AppColors.info,
                    background: AppColors.infoBackground,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _GapDirectionCard(
                    title: '고요 지수 낮음',
                    icon: Symbols.trending_down_rounded,
                    resultLabel:
                        favorsLowGap ? '등장 확률이\n높아요!' : '등장 확률이\n낮아요!',
                    caption: '북적이는\n유명한 곳이에요.',
                    color: AppColors.error,
                    background: AppColors.errorBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (tierProbabilities.isNotEmpty || noGap != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _DetailToggleRow(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: _ProbabilityBreakdown(
                tierProbabilities: tierProbabilities,
                noGap: noGap,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 참새 아이콘 + 서버가 내려준 획득 방법 설명을 얹은 하이라이트 박스.
/// `<갭지수 설명 페이지>`(gap_index_info_dialog.dart)의 잎 장식 콜아웃과
/// 같은 톤(surfaceSelected)을 재사용해 다이얼로그 전체 톤을 맞춘다.
class _AcquisitionHint extends StatelessWidget {
  const _AcquisitionHint({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/illustrations/sparrow/sparrow_default.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Symbols.emoji_nature_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "갭지수 낮음"/"갭지수 높음" 비교 카드 — 화살표 + 결과 문구 + 구간 설명.
class _GapDirectionCard extends StatelessWidget {
  const _GapDirectionCard({
    required this.title,
    required this.icon,
    required this.resultLabel,
    required this.caption,
    required this.color,
    required this.background,
  });

  final String title;
  final IconData icon;
  final String resultLabel;
  final String caption;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(icon, size: 28, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            resultLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.smallButton),
            ),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// "자세히 보기 (구간별 등장 확률 확인하기)" 토글 행.
class _DetailToggleRow extends StatelessWidget {
  const _DetailToggleRow({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Row(
            children: [
              const Icon(
                Symbols.bar_chart_rounded,
                size: 20,
                color: AppColors.primaryPressed,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                    children: const [
                      TextSpan(text: '자세히 보기 '),
                      TextSpan(
                        text: '(구간별 등장 확률 확인하기)',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                expanded
                    ? Symbols.expand_less_rounded
                    : Symbols.expand_more_rounded,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 펼친 "갭지수 구간별 등장 확률" — 구간별 막대 + 정보 없음 안내.
class _ProbabilityBreakdown extends StatelessWidget {
  const _ProbabilityBreakdown({
    required this.tierProbabilities,
    required this.noGap,
  });

  final List<IngredientDropProbability> tierProbabilities;
  final IngredientDropProbability? noGap;

  @override
  Widget build(BuildContext context) {
    final maxP = tierProbabilities.isEmpty
        ? 1.0
        : tierProbabilities
            .map((p) => p.probability)
            .reduce((a, b) => a > b ? a : b);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('고요 지수 구간별 등장 확률', style: AppTextStyles.bodyMedium
              .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          for (final p in tierProbabilities) ...[
            _ProbabilityBar(
              label: _tierLabel(p),
              probability: p.probability,
              fraction: maxP <= 0 ? 0 : p.probability / maxP,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (noGap != null) ...[
            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.infoBackground,
                borderRadius: BorderRadius.circular(AppRadius.smallButton),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '고요 지수 정보 없음',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(noGap!.probability * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Symbols.info_rounded,
                        size: 14,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '고요 지수를 아직 계산할 수 없는 장소에서는 '
                          '${(noGap!.probability * 100).toStringAsFixed(0)}% '
                          '확률로 등장해요.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _tierNames = <String, String>{
  'GAP_LOW': '하위',
  'GAP_MID': '중위',
  'GAP_HIGH': '상위',
  'GAP_TOP': '최상위',
};

String _tierLabel(IngredientDropProbability probability) {
  final name = _tierNames[probability.policyCode] ?? probability.policyCode;
  final min = probability.minGapPercentile;
  final max = probability.maxGapPercentile;
  if (min == null && max == null) return name;

  String percent(double value) => (value * 100).toStringAsFixed(0);
  final range = switch ((min, max)) {
    (final lower?, final upper?) => '${percent(lower)}~${percent(upper)}%',
    (final lower?, null) => '${percent(lower)}%~',
    (null, final upper?) => '~${percent(upper)}%',
    _ => '',
  };
  return '$name ($range)';
}

/// 구간 라벨 + 확률 막대 + 퍼센트 한 행.
class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({
    required this.label,
    required this.probability,
    required this.fraction,
  });

  final String label;
  final double probability;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: AppTextStyles.caption),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 10,
              color: AppColors.surfaceDisabled,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0, 1),
                child: Container(color: AppColors.primary),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(probability * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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

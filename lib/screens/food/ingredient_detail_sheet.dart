import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
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

/// GAP 정책 코드 → 화면에 보여줄 한국어 라벨.
const _policyLabels = <String, String>{
  'NO_GAP': '갭지수 정보 없음',
  'GAP_LOW': '갭지수 하위 (0~50%)',
  'GAP_MID': '갭지수 중위 (50~80%)',
  'GAP_HIGH': '갭지수 상위 (80~95%)',
  'GAP_TOP': '갭지수 최상위 (95%~)',
};

const _rarityLabels = <String, String>{
  'COMMON': '일반',
  'UNCOMMON': '고급',
  'RARE': '희귀',
  'LEGENDARY': '전설',
};

class _IngredientDetailDialog extends StatefulWidget {
  const _IngredientDetailDialog({
    required this.ingredientId,
    this.initialName,
  });

  final int ingredientId;
  final String? initialName;

  @override
  State<_IngredientDetailDialog> createState() =>
      _IngredientDetailDialogState();
}

class _IngredientDetailDialogState extends State<_IngredientDetailDialog> {
  late Future<IngredientDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<IngredientDetail> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    return IngredientService().detail(widget.ingredientId);
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
        child: FutureBuilder<IngredientDetail>(
          future: _future,
          builder: (context, snapshot) {
            final detail = snapshot.data;
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
                    child: _buildBody(context, snapshot),
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
    AsyncSnapshot<IngredientDetail> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
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
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final detail = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CharacteristicsSection(detail: detail),
        if (detail.usedFoods.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionLabel('사용되는 음식'),
          const SizedBox(height: AppSpacing.md),
          _UsedInFoodsGrid(
            foods: detail.usedFoods,
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

/// 가운데 정렬 제목 + 닫기(X) + 잎 장식.
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
      child: Column(
        children: [
          SizedBox(
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Leaf(flip: true),
              const SizedBox(width: AppSpacing.xs),
              _Leaf(flip: false),
            ],
          ),
        ],
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
            child: _NetOrIcon(
              url: detail.imageUrl ?? detail.illustrationUrl,
              icon: Symbols.grocery_rounded,
              color: detail.obtained ? AppColors.primary : AppColors.iconDisabled,
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
                    label: '희귀도: ${_rarityLabels[detail.rarity] ?? detail.rarity}',
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
                      ? (regionName != null
                          ? '$regionName 특산 재료'
                          : '지역 특산 재료')
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
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
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
                    child: _NetOrIcon(
                      url: food.imageUrl ?? food.illustrationUrl,
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

/// GAP 기반 획득 방법 — 서버 설명 + 정책별 확률을 그대로 표시한다(스펙 §9.1,
/// §14-14: 프론트에서 확률을 계산하거나 예측하지 않는다).
class _AcquisitionSection extends StatelessWidget {
  const _AcquisitionSection({required this.acquisition});

  final IngredientAcquisition? acquisition;

  @override
  Widget build(BuildContext context) {
    final acq = acquisition;
    if (acq == null ||
        ((acq.description == null || acq.description!.trim().isEmpty) &&
            acq.dropProbabilities.isEmpty)) {
      return Text(
        '획득 방법 정보가 없어요.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (acq.description != null && acq.description!.trim().isNotEmpty)
            Text(
              acq.description!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
          if (acq.dropProbabilities.isNotEmpty) ...[
            if (acq.description != null && acq.description!.trim().isNotEmpty)
              const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.md),
            for (final p in acq.dropProbabilities) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _policyLabels[p.policyCode] ?? p.policyCode,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Text(
                      '${(p.probability * 100).toStringAsFixed(1)}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPressed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
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

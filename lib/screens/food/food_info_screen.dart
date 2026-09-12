import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';
import 'chef_kitchen_screen.dart';

/// `<음식 정보>` (user_flow §4) — 음식 도감에서 아직 만들지 못한(또는 재료가
/// 거의 모인) 음식을 눌렀을 때. 필요 재료(보유/필요 수량), "만들기" 버튼
/// (모든 재료 구비 시 활성화)을 보여준다.
///
/// `GET /foods/{id}` (스펙 §10.2) 로 실 데이터를 읽는다. "만들기" 는
/// `<셰프의 주방>` 으로 이동만 하고, 실제 `POST /foods/{id}/make` 호출은
/// `chef_kitchen_screen.dart` 의 "요리 시작" 단계에서 수행한다(기존 UX —
/// 제작 애니메이션을 거친 뒤 완성 여부를 보여주는 흐름 — 를 그대로 유지하기
/// 위함).
///
/// * TODO(backend gap): 예전 mock 의 "부족한 재료를 얻을 수 있는 장소" 절은
///   대응하는 API 가 없다 — GAP 기반 방문 보상은 특정 장소를 짚어 추천하지
///   않으므로(스펙 §8.5, §9.1) 해당 섹션은 제거했다. 재료 상세(§9.1)의
///   `acquisition.description`/`dropProbabilities` 로 안내를 대신한다.
class FoodInfoScreen extends StatefulWidget {
  const FoodInfoScreen({super.key, required this.foodId});

  final int foodId;

  @override
  State<FoodInfoScreen> createState() => _FoodInfoScreenState();
}

class _FoodInfoScreenState extends State<FoodInfoScreen> {
  late Future<Food> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Food> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    return FoodService().detail(widget.foodId);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBar(onBack: () => Navigator.of(context).maybePop()),
              // 상단 헤더 밴드 scene. 납품 전까지 errorBuilder 로 아무것도
              // 그리지 않고 #FAE7C0 base 가 그대로 보이게 둔다.
              Image.asset(
                'assets/illustrations/scenes/food_dex_bg.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: FutureBuilder<Food>(
                  future: _future,
                  builder: (context, snapshot) => _buildBody(context, snapshot),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
          // * TODO: 랭킹 탭 — 해당 화면 구현 후 연결.
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<Food> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '음식 정보를 불러오지 못했어요.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
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

    final food = snapshot.data!;
    final ownedCount = food.ingredients.where((i) => i.enough).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCard(food: food),
        const SizedBox(height: AppSpacing.xxl),
        _RequiredHeader(owned: ownedCount, total: food.ingredients.length),
        const SizedBox(height: AppSpacing.md),
        _IngredientGrid(ingredients: food.ingredients),
        const SizedBox(height: AppSpacing.xxl),
        _MakeSection(
          food: food,
          onMake: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChefKitchenScreen(food: food),
            ),
          ),
        ),
      ],
    );
  }
}

/// 뒤로가기 + 가운데 정렬 제목.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('음식 정보', style: AppTextStyles.h2),
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

/// 음식 일러스트(제작 가능 여부에 따라 실루엣/자물쇠 또는 실컬러) + 이름 +
/// 설명 + 상태 칩.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final canMake = food.canMake;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              width: 120,
              height: 120,
              color: AppColors.surfaceSelected,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: canMake ? 1 : 0.3,
                    child: _NetOrIcon(
                      url: food.imageUrl ?? food.illustrationUrl,
                      icon: Symbols.dinner_dining_rounded,
                      color: AppColors.iconInactive,
                      fit: BoxFit.cover,
                      iconSize: 40,
                    ),
                  ),
                  if (!canMake)
                    const Icon(
                      Symbols.lock_rounded,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: AppTextStyles.h2),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  food.description ?? '',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canMake
                            ? Symbols.check_circle_rounded
                            : Symbols.hourglass_empty_rounded,
                        size: 14,
                        color: canMake
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        canMake ? '지금 만들 수 있어요' : '아직 만들지 못했어요',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
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

/// "🌿 필요한 재료" + 우측 "현재 N / M 재료 보유" 뱃지.
class _RequiredHeader extends StatelessWidget {
  const _RequiredHeader({required this.owned, required this.total});

  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SectionLabel('필요한 재료'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
              children: [
                const TextSpan(text: '현재 '),
                TextSpan(
                  text: '$owned / $total',
                  style: TextStyle(
                    color: owned == total
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' 재료 보유'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientGrid extends StatelessWidget {
  const _IngredientGrid({required this.ingredients});

  final List<FoodIngredient> ingredients;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: ingredients.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 152,
      ),
      itemBuilder: (context, index) =>
          _IngredientCard(ingredient: ingredients[index]),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.ingredient});

  final FoodIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final ok = ingredient.enough;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: _NetOrIcon(
              url: ingredient.imageUrl ?? ingredient.illustrationUrl,
              icon: Symbols.grocery_rounded,
              color: AppColors.primary,
              iconSize: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ingredient.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${ingredient.ownedQuantity} / ${ingredient.requiredQuantity}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: ok ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatusChip(ok: ok),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBackground : AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ok) ...[
            const Icon(
              Symbols.check_rounded,
              size: 12,
              color: AppColors.success,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            ok ? '보유완료' : '부족',
            style: AppTextStyles.caption.copyWith(
              color: ok ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "재료 N개 더 필요" 안내 + "만들기" 버튼(모든 재료 구비 시 활성화).
class _MakeSection extends StatelessWidget {
  const _MakeSection({required this.food, required this.onMake});

  final Food food;
  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) {
    final canMake = food.canMake;
    final missingCount =
        food.ingredients.where((i) => !i.enough).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              children: canMake
                  ? const [TextSpan(text: '필요한 재료를 모두 모았어요!')]
                  : [
                      const TextSpan(text: '재료 '),
                      TextSpan(
                        text: '$missingCount개',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const TextSpan(text: '가 더 필요해요.'),
                    ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canMake ? onMake : null,
              icon: const Icon(Symbols.soup_kitchen_rounded, size: 20),
              label: const Text('만들기'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canMake
                ? '지금 바로 만들 수 있어요.'
                : '모든 재료를 모으면 만들기 버튼이 활성화돼요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// 왼쪽 정렬 섹션 제목 — 앞에 작은 잎 장식.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.h3),
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
      width: 18,
      height: 18,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 18),
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

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/reward_image.dart';

/// `<음식 히스토리>` (user_flow §4) — 음식 도감에서 이미 만든 음식을 눌렀을 때.
/// 만든 날짜, 사용된 재료(특별/일반)를 보여준다.
///
/// `GET /food-histories/{historyId}` (스펙 §11.1) 로 실 데이터를 읽는다.
/// `historyId` 는 `foodId` 가 아니라 실제 `UserFood.id` 다.
///
/// * TODO(backend gap): 예전 mock 의 "특별 재료를 얻은 관광 스팟" 절은 대응하는
///   API 가 없다 — 재료 획득처를 FIFO 단위로 추적하지 않아 특정 관광 스팟을
///   짚어줄 수 없다(스펙 §11.1, §15). 대신 특별 재료 카드에 `obtainedPlace`가
///   있을 때만 함께 보여준다(없으면 그 줄 자체를 생략). "음식의 특징" 절도
///   대응 필드가 없어(설명은 `food.description` 하나뿐) 제거했다.
class FoodHistoryScreen extends StatefulWidget {
  const FoodHistoryScreen({super.key, required this.userFoodId});

  final int userFoodId;

  @override
  State<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> {
  /// `food_history_bg.png`'s native aspect ratio (1588×990) — used to size the
  /// fixed header scene at its full, uncropped height for any screen width,
  /// and to clear that much space before the scrollable content starts.
  static const _kBgAspectRatio = 1588 / 990;

  late Future<FoodHistoryDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FoodHistoryDetail> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    return FoodHistoryService().detail(widget.userFoodId);
  }

  void _reload() => setState(() => _future = _load());

  String _dateText(DateTime? d) {
    if (d == null) return '정보 없음';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}.$m.$day';
  }

  @override
  Widget build(BuildContext context) {
    final bgHeight = MediaQuery.sizeOf(context).width / _kBgAspectRatio;
    final fadeHeight = bgHeight * 0.3;
    // Pull the content block up slightly into the fade zone (not the crisp
    // illustration above it) so it sits a bit closer to the scene without
    // covering more of it.
    final contentClearance = bgHeight - fadeHeight * 0.6;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 52,
        titleSpacing: 0,
        title: _HeaderBar(onBack: () => Navigator.of(context).maybePop()),
      ),
      // `SizedBox.expand` guarantees the Stack itself fills the screen via a
      // tight constraint from *outside* it, regardless of `fit` or how many
      // children are `Positioned`.
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Fixed background scene, shown in full (not cropped) — stays put
            // while the content below scrolls over it.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/illustrations/scenes/food_history_bg.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
            // Soft fade at the scene's bottom edge into the flat app
            // background, so it doesn't cut off abruptly.
            Positioned(
              top: bgHeight - fadeHeight,
              left: 0,
              right: 0,
              height: fadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.appBackground.withValues(alpha: 0),
                        AppColors.appBackground,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: FutureBuilder<FoodHistoryDetail>(
                  future: _future,
                  builder: (context, snapshot) => LoadingOverlay(
                    loading: snapshot.connectionState != ConnectionState.done,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: contentClearance),
                          Padding(
                            padding: AppBottomNavBar.scrollPadding(
                              context,
                              const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.lg,
                                AppSpacing.xl,
                                AppSpacing.xxl,
                              ),
                            ),
                            child: _buildBody(context, snapshot),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<FoodHistoryDetail> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      // The LoadingOverlay above already shows the loading pill.
      return const SizedBox(height: AppSpacing.huge);
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '음식 히스토리를 불러오지 못했어요.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
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

    final history = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCard(food: history.food),
        const SizedBox(height: AppSpacing.lg),
        _MadeDateCard(dateText: _dateText(history.food.madeAt)),
        if (history.specialIngredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionLabel('사용된 특별 재료'),
          const SizedBox(height: AppSpacing.md),
          _WideIngredientRow(items: history.specialIngredients),
        ],
        if (history.normalIngredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const _SectionLabel('일반 재료'),
          const SizedBox(height: AppSpacing.md),
          _IngredientGrid(items: history.normalIngredients),
        ],
      ],
    );
  }
}

/// 뒤로가기 + 가운데 정렬 제목 + 잎 장식.
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Leaf(flip: true),
                const SizedBox(width: AppSpacing.sm),
                Text('음식 히스토리', style: AppTextStyles.h2),
                const SizedBox(width: AppSpacing.sm),
                _Leaf(flip: false),
              ],
            ),
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

/// 음식 일러스트 + 이름 + 설명.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.food});

  final FoodHistoryFoodRef food;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              width: 116,
              height: 116,
              color: AppColors.surfaceSelected,
              child: RewardImage(
                name: food.name,
                folder: RewardAssetFolder.dish,
                networkUrl: food.imageUrl ?? food.illustrationUrl,
                icon: Symbols.dinner_dining_rounded,
                color: AppColors.iconInactive,
                fit: BoxFit.cover,
                iconSize: 40,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(food.name, style: AppTextStyles.h3)),
                    const SizedBox(width: AppSpacing.xs),
                    _Leaf(flip: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  food.description ?? '',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
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

/// "만든 날짜 ......... 2026.08.15" 카드.
class _MadeDateCard extends StatelessWidget {
  const _MadeDateCard({required this.dateText});

  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Image.asset(
              'assets/illustrations/icon/calendar.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.calendar_month_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '만든 날짜',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            dateText,
            style: AppTextStyles.numericScore.copyWith(
              fontSize: 18,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// 특별 재료 — 아이콘 + 이름 + 획득 장소(있을 때만) 를 가로로 나열한 넓은
/// 카드들. 재료별 실제 워터컬러 에셋(`RewardImage`, 이름으로 매칭)을 쓰고,
/// 없으면 범용 아이콘으로 폴백.
class _WideIngredientRow extends StatelessWidget {
  const _WideIngredientRow({required this.items});

  final List<FoodHistoryIngredient> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _WideIngredientCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _WideIngredientCard extends StatelessWidget {
  const _WideIngredientCard({required this.item});

  final FoodHistoryIngredient item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: RewardImage(
              name: item.name,
              folder: RewardAssetFolder.ingredient,
              icon: Symbols.grocery_rounded,
              color: AppColors.primary,
              iconSize: 36,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.obtainedPlace != null) ...[
            const SizedBox(height: 2),
            Text(
              item.obtainedPlace!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 일반 재료 — 4열 그리드(아이콘 + 이름). 재료별 실제 워터컬러 에셋
/// (`RewardImage`, 이름으로 매칭)을 쓰고, 없으면 범용 아이콘으로 폴백.
class _IngredientGrid extends StatelessWidget {
  const _IngredientGrid({required this.items});

  final List<FoodHistoryIngredient> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: RewardImage(
                  name: item.name,
                  folder: RewardAssetFolder.ingredient,
                  icon: Symbols.grocery_rounded,
                  color: AppColors.primary,
                  iconSize: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
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

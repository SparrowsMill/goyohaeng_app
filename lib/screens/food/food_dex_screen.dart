import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/food_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/reward_image.dart';
import 'food_history_screen.dart';
import 'food_info_screen.dart';

/// `<음식 도감>` (user_flow §4) — 내 음식 보기에서 "음식 도감"을 눌렀을 때. 만든
/// 음식 / 곧 만들 수 있는 음식 / 아직 못 만든 음식을 보여준다.
/// 공통·수도권 음식 중 기본 재료와 수도권 지역 재료만 사용하는 레시피를 포함한다.
///
/// `GET /foods` (스펙 §10.1) + `GET /users/me/foods` (스펙 §3.9) 를 함께 읽어
/// 각 음식의 도감 상태(만듦/거의/잠김)를 계산한다. 이미 만든 음식 탭 → 실제
/// `UserFood.id` 로 `<음식 히스토리>`, 미제작 음식 탭 → 실제 `foodId` 로
/// `<음식 정보>` 로 연결된다.
class FoodDexScreen extends StatefulWidget {
  const FoodDexScreen({super.key});

  @override
  State<FoodDexScreen> createState() => _FoodDexScreenState();
}

/// 도감 상태 — 백엔드에 대응 필드가 없어 [Food.canMake] + 사용자 제작 이력으로
/// 프론트에서 계산한다.
enum _DexFoodState {
  /// 이미 만든 적이 있는 음식(`UserService.getFoods()` 에 존재) — 탭 시
  /// `<음식 히스토리>`.
  made,

  /// 아직 안 만들었지만 지금 바로 만들 수 있는 음식(`canMake == true`).
  almost,

  /// 재료가 많이 부족한 음식.
  locked,
}

class _DexEntry {
  const _DexEntry({
    required this.food,
    required this.state,
    required this.difficulty,
    this.userFoodId,
  });

  final _Difficulty? difficulty;

  final Food food;
  final _DexFoodState state;

  /// [state] 가 [_DexFoodState.made] 일 때 히스토리 조회에 쓸 `UserFood.id`
  /// (가장 최근에 만든 기록).
  final int? userFoodId;
}

enum _Difficulty {
  low('하', '일반'),
  medium('중', '고급'),
  high('상', '희귀'),
  legendary('최상', '전설');

  const _Difficulty(this.label, this.filterLabel);
  final String label;
  final String filterLabel;
}

/// 레시피의 재료 ID를 전체 재료 목록 및 지역 정보와 대조한다.
typedef _DexData = ({
  List<Food> foods,
  List<UserFood> made,
  Map<int, String?> ingredientRarities,
});

class _FoodDexScreenState extends State<FoodDexScreen> {
  static const _kBgAspectRatio = 1588 / 990;

  late Future<_DexData> _future;
  _Difficulty? _difficulty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DexData> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    final results = await Future.wait([
      FoodService().list(),
      UserService().getFoods(limit: 100),
      UserService().getIngredients(),
    ]);
    return (
      foods: results[0] as List<Food>,
      made: (results[1] as Paged<UserFood>).items,
      ingredientRarities: {
        for (final ingredient in (results[2] as UserIngredients).items)
          ingredient.id: ingredient.rarity,
      },
    );
  }

  void _reload() => setState(() => _future = _load());

  /// [food_info_screen.dart] 의 "거의" 판정과 동일한 휴리스틱(§ingredient_bag
  /// 참고) — canMake 는 아니지만 재료 중 하나 이상은 이미 충분히 모은 경우.
  bool _isAlmost(Food food) =>
      !food.canMake && food.ingredients.any((i) => i.enough);

  List<_DexEntry> _buildEntries(_DexData data) {
    return [
      for (final food in data.foods)
        if (FoodCatalog.isOpen(food.name))
          _entryFor(food, data.made, _difficultyFor(food, data)),
    ];
  }

  _Difficulty? _difficultyFor(Food food, _DexData data) {
    var level = _Difficulty.low;
    for (final ingredient in food.ingredients) {
      final rarity = data.ingredientRarities[ingredient.id];
      final current = switch (rarity) {
        'COMMON' => _Difficulty.low,
        'UNCOMMON' => _Difficulty.medium,
        'RARE' => _Difficulty.high,
        'LEGENDARY' => _Difficulty.legendary,
        _ => null,
      };
      if (current == null) return null;
      if (current.index > level.index) level = current;
    }
    return level;
  }

  _DexEntry _entryFor(Food food, List<UserFood> made, _Difficulty? difficulty) {
    final matches = made.where((f) => f.foodId == food.id).toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) {
        final am = a.madeAt;
        final bm = b.madeAt;
        if (am == null || bm == null) return 0;
        return bm.compareTo(am);
      });
      return _DexEntry(
        food: food,
        difficulty: difficulty,
        state: _DexFoodState.made,
        userFoodId: matches.first.id,
      );
    }
    return _DexEntry(
      food: food,
      difficulty: difficulty,
      state: (food.canMake || _isAlmost(food))
          ? _DexFoodState.almost
          : _DexFoodState.locked,
    );
  }

  void _onTapEntry(_DexEntry entry) {
    if (entry.state == _DexFoodState.made && entry.userFoodId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FoodHistoryScreen(userFoodId: entry.userFoodId!),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FoodInfoScreen(foodId: entry.food.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgHeight = MediaQuery.sizeOf(context).width / _kBgAspectRatio;
    final fadeHeight = bgHeight * 0.3;
    final contentClearance = bgHeight - fadeHeight * 0.6;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 52,
        titleSpacing: 0,
        title: _HeaderBar(onBack: () => Navigator.of(context).maybePop()),
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
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
                child: FutureBuilder<_DexData>(
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

  Widget _buildBody(BuildContext context, AsyncSnapshot<_DexData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      // The LoadingOverlay above already shows the loading pill.
      return const SizedBox(height: AppSpacing.huge);
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '음식 도감을 불러오지 못했어요.';
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

    final entries = _buildEntries(snapshot.data!)
        .where(
          (entry) => _difficulty == null || entry.difficulty == _difficulty,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RegionSectionHeader(region: '기본 · 수도권 재료 음식'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '가장 획득하기 어려운 재료 기준 · 하: 일반 / 중: 고급 / 상: 희귀 / 최상: 전설',
          style: AppTextStyles.caption,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('전체'),
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.textOnPrimaryButton,
              labelStyle: TextStyle(
                color: _difficulty == null
                    ? AppColors.textOnPrimaryButton
                    : AppColors.textSecondary,
              ),
              selected: _difficulty == null,
              onSelected: (_) => setState(() => _difficulty = null),
            ),
            for (final difficulty in _Difficulty.values)
              ChoiceChip(
                label: Text(difficulty.filterLabel),
                selectedColor: AppColors.primary,
                checkmarkColor: AppColors.textOnPrimaryButton,
                labelStyle: TextStyle(
                  color: _difficulty == difficulty
                      ? AppColors.textOnPrimaryButton
                      : AppColors.textSecondary,
                ),
                selected: _difficulty == difficulty,
                onSelected: (_) => setState(() => _difficulty = difficulty),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              _difficulty == null ? '표시할 음식이 없어요.' : '이 난이도에 해당하는 음식이 없어요.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          _DexFoodGrid(entries: entries, onTapEntry: _onTapEntry),
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
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Leaf(flip: true),
                    const SizedBox(width: AppSpacing.sm),
                    Text('음식 도감', style: AppTextStyles.h2),
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
        ],
      ),
    );
  }
}

/// "📍 전주 ————————" 지역 섹션 헤더.
class _RegionSectionHeader extends StatelessWidget {
  const _RegionSectionHeader({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Symbols.location_on_rounded,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(region, style: AppTextStyles.h3)),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: Divider(height: 1, color: AppColors.border)),
        const SizedBox(width: AppSpacing.xs),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.border,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _DexFoodGrid extends StatelessWidget {
  const _DexFoodGrid({required this.entries, required this.onTapEntry});

  final List<_DexEntry> entries;
  final ValueChanged<_DexEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 204,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _DexFoodCard(entry: entry, onTap: () => onTapEntry(entry));
      },
    );
  }
}

class _DexFoodCard extends StatelessWidget {
  const _DexFoodCard({required this.entry, required this.onTap});

  final _DexEntry entry;
  final VoidCallback onTap;

  bool get _locked => entry.state == _DexFoodState.locked;

  @override
  Widget build(BuildContext context) {
    final food = entry.food;
    return Stack(
      children: [
        _buildCard(context, food),
        // 이미 만든 음식 뱃지 (user_flow §4).
        if (entry.state == _DexFoodState.made)
          Positioned(
            top: 6,
            right: 6,
            child: SizedBox(
              width: 26,
              height: 26,
              child: Image.asset(
                'assets/illustrations/icon/verified.png',
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.verified_rounded,
                  size: 26,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, Food food) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.surfaceSelected,
                    // 미제작 음식은 실루엣처럼 흐리게 (user_flow §4).
                    child: Opacity(
                      opacity: _locked ? 0.3 : 1,
                      child: RewardImage(
                        name: food.name,
                        folder: RewardAssetFolder.dish,
                        networkUrl: food.imageUrl ?? food.illustrationUrl,
                        icon: Symbols.dinner_dining_rounded,
                        color: _locked
                            ? AppColors.iconDisabled
                            : AppColors.iconInactive,
                        fit: BoxFit.cover,
                        iconSize: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (entry.state == _DexFoodState.almost) ...[
                    const Icon(
                      Symbols.hourglass_empty_rounded,
                      size: 14,
                      color: AppColors.secondaryAccent,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _locked
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.difficulty == null
                    ? '난이도 미정'
                    : '난이도 ${entry.difficulty!.label}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
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
      width: 18,
      height: 18,
      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 18),
    );
    return flip ? Transform.flip(flipX: true, child: img) : img;
  }
}

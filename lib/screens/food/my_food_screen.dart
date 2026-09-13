import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../ranking/ranking_screen.dart';
import '../record/my_footprint_screen.dart';
import 'food_dex_screen.dart';
import 'food_history_screen.dart';
import 'ingredient_bag_screen.dart';

/// `<본인 음식 보기>` (user_flow §4) — 지금까지 만든 음식을 보고, 재료 가방 /
/// 음식 도감으로 이동할 수 있는 페이지. 방앗간 홈의 "내 음식 보기" CTA 에서 진입.
///
/// `GET /users/me/foods` (스펙 §3.9) 로 실 데이터를 읽는다. 같은 음식을 여러 번
/// 만들었으면 각각 별개의 `UserFood` 카드로 보여준다. 카드 탭 시 실제
/// `UserFood.id` 로 `<음식 히스토리>` 로 이동한다.
///
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/my_food_bg.png` (§9, 불투명 헤더 밴드 PNG,
///   #FAE7C0 위에 그려진 채로 납품). 그 전까지 평면 #FAE7C0 위에 콘텐츠만 표시.
class MyFoodScreen extends StatefulWidget {
  const MyFoodScreen({super.key});

  /// 셰프의 주방에서 요리 완성 후 이 화면까지 돌아오기 위한 라우트 이름
  /// (`mill_home_screen.dart` 에서 사용).
  static const routeName = 'my_food';

  static const _sceneHeight = 220.0;

  @override
  State<MyFoodScreen> createState() => _MyFoodScreenState();
}

class _MyFoodScreenState extends State<MyFoodScreen> {
  /// 목록 화면이라 한 번에 최대 100개까지 불러온다 — 그보다 많이 만든 사용자는
  /// 아직 페이지네이션(무한 스크롤)이 없어 최신 100개만 보인다.
  static const _limit = 100;

  late Future<Paged<UserFood>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Paged<UserFood>> _load() async {
    if (!AuthStore.instance.isSignedIn) {
      throw ApiException('로그인이 필요해요.');
    }
    return UserService().getFoods(limit: _limit);
  }

  void _reload() => setState(() => _future = _load());

  void _openHistory(BuildContext context, UserFood food) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FoodHistoryScreen(userFoodId: food.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Stack(
        children: [
          // 상단 헤더 밴드 scene. 불투명 PNG 납품 전까지 errorBuilder 로
          // 아무것도 그리지 않고 #FAE7C0 base 가 그대로 보이게 둔다.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/illustrations/scenes/my_food_bg.png',
              height: MyFoodScreen._sceneHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(height: MyFoodScreen._sceneHeight),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBar(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  // scene 밴드의 그림 영역을 지나 콘텐츠가 시작되도록 여백 확보.
                  const SizedBox(height: 132),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: FutureBuilder<Paged<UserFood>>(
                      future: _future,
                      builder: (context, snapshot) =>
                          _buildBody(context, snapshot),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<Paged<UserFood>> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : '내가 만든 음식을 불러오지 못했어요.';
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

    final page = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CompletedSummaryCard(count: page.total),
        const SizedBox(height: AppSpacing.lg),
        _ShortcutRow(
          onOpenBag: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IngredientBagScreen(),
            ),
          ),
          onOpenDex: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FoodDexScreen(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _SectionLabel('내가 만든 음식'),
        const SizedBox(height: AppSpacing.md),
        if (page.items.isEmpty)
          Text(
            '아직 만든 음식이 없어요.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          )
        else
          _MyFoodsGrid(
            foods: page.items,
            onTapFood: (food) => _openHistory(context, food),
          ),
      ],
    );
  }
}

/// 뒤로가기(원형 버튼) + 가운데 정렬 제목. scene 밴드 위에 얹힌다.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('내 음식 보기', style: AppTextStyles.h3),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                elevation: 0,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      Symbols.arrow_back_rounded,
                      size: 24,
                      color: AppColors.iconPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "완성한 음식 N개" 요약 카드 — 왼쪽에 잎 장식 + 큰 숫자, 오른쪽에 안내 문구.
class _CompletedSummaryCard extends StatelessWidget {
  const _CompletedSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(radius: AppRadius.largeCard),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Leaf(flip: true),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '완성한 음식',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Leaf(flip: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.h1.copyWith(color: AppColors.success),
                    children: [
                      TextSpan(text: '$count'),
                      TextSpan(
                        text: '개',
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Container(width: 1, color: AppColors.divider),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지금까지 만든 음식을\n모아봤어요.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '맛있는 여정이 계속되고 있어요!',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 재료 가방 / 음식 도감으로 가는 두 개의 바로가기 카드.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.onOpenBag, required this.onOpenDex});

  final VoidCallback onOpenBag;
  final VoidCallback onOpenDex;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ShortcutCard(
              // * TODO(asset): assets/illustrations/icon/main_bag_icon.png 미납품.
              iconAsset: 'assets/illustrations/icon/main_bag_icon.png',
              fallbackIcon: Symbols.backpack_rounded,
              title: '재료 가방',
              subtitle: '모은 재료를\n확인해요',
              onTap: onOpenBag,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ShortcutCard(
              // * TODO(asset): assets/illustrations/icon/main_book_icon.png 미납품.
              iconAsset: 'assets/illustrations/icon/main_book_icon.png',
              fallbackIcon: Symbols.menu_book_rounded,
              title: '음식 도감',
              subtitle: '완성한 음식과\n새로운 음식을 살펴봐요',
              onTap: onOpenDex,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.iconAsset,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        fallbackIcon,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Symbols.chevron_right_rounded,
                    size: 20,
                    color: AppColors.iconInactive,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
      children: [
        _Leaf(flip: false),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.h3),
      ],
    );
  }
}

/// 완성한 음식 2열 그리드.
class _MyFoodsGrid extends StatelessWidget {
  const _MyFoodsGrid({required this.foods, required this.onTapFood});

  final List<UserFood> foods;
  final ValueChanged<UserFood> onTapFood;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: foods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 272,
      ),
      itemBuilder: (context, index) {
        final food = foods[index];
        return _FoodCard(food: food, onTap: () => onTapFood(food));
      },
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.food, required this.onTap});

  final UserFood food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 음식 일러스트. 납품 전까지 범용 접시 아이콘 placeholder.
              AspectRatio(
                aspectRatio: 1.15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                  child: Container(
                    color: AppColors.surfaceSelected,
                    child: _NetOrIcon(
                      url: food.imageUrl ?? food.illustrationUrl,
                      icon: Symbols.dinner_dining_rounded,
                      color: AppColors.iconInactive,
                      fit: BoxFit.cover,
                      iconSize: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: 2),
              Text(
                food.description ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _CompletedChip(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "완성" 상태 칩 — §7 Status Chip.
class _CompletedChip extends StatelessWidget {
  const _CompletedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.check_circle_rounded,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            '완성',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
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

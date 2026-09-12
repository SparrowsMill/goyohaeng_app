import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_food_dex.dart';
import '../../data/mock_food_history.dart';
import '../../data/mock_food_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../map/map_screen.dart';
import '../record/my_footprint_screen.dart';
import 'food_history_screen.dart';
import 'food_info_screen.dart';

/// `<음식 도감>` (user_flow §4) — 내 음식 보기에서 "음식 도감"을 눌렀을 때. 만든
/// 음식 / 곧 만들 수 있는 음식 / 아직 못 만든 음식을 도감 형태로 보여준다. "구분"
/// 드롭다운으로 전체 보기 / 지역별 보기를 고르고, 지역별 보기일 때만 옆의 "지역"
/// 드롭다운이 활성화된다.
///
/// 뼈대만 구현 — 데이터는 `mock_food_dex` placeholder. 이미 만든 음식 탭 →
/// `<음식 히스토리>`, 미제작 음식 탭 → `<음식 정보>` 로 연결됨 (각각
/// `mock_food_history` / `mock_food_info` 에 데이터 있는 slug 만).
///
/// * TODO(asset): 이 화면 배경 scene 미납품 —
///   `assets/illustrations/scenes/food_dex_bg.png` (§9, 펼친 책 헤더 밴드 PNG).
///   그 전까지 평면 #FAE7C0 위에 콘텐츠만 표시.
class FoodDexScreen extends StatefulWidget {
  const FoodDexScreen({super.key});

  @override
  State<FoodDexScreen> createState() => _FoodDexScreenState();
}

enum _DexView { all, byRegion }

class _FoodDexScreenState extends State<FoodDexScreen> {
  _DexView _view = _DexView.byRegion;

  /// 지역별 보기에서 선택된 지역. 전체 보기일 때는 무시된다.
  String _region = mockDexRegions.first;

  void _todo(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onTapFood(DexFood food) {
    if (food.state == DexFoodState.made) {
      final history = foodHistoryFor(food.slug);
      if (history == null) {
        _todo('${food.name} 히스토리는 준비 중이에요.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FoodHistoryScreen(history: history)),
      );
    } else {
      final info = foodInfoFor(food.slug);
      if (info == null) {
        _todo('${food.name} 정보는 준비 중이에요.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FoodInfoScreen(info: info)),
      );
    }
  }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DexControls(
                      view: _view,
                      region: _region,
                      onViewChanged: (v) => setState(() => _view = v),
                      onRegionChanged: (r) => setState(() => _region = r),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_view == _DexView.all)
                      _DexFoodGrid(
                        foods: mockFoodDex,
                        onTapFood: _onTapFood,
                      )
                    else ...[
                      _RegionSectionHeader(region: _region),
                      const SizedBox(height: AppSpacing.md),
                      _DexFoodGrid(
                        foods: dexFoodsByRegion(_region),
                        onTapFood: _onTapFood,
                      ),
                    ],
                  ],
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

/// "구분" 드롭다운 + "지역" 드롭다운. 지역 드롭다운은 구분이 "지역별 보기"일
/// 때만 활성화된다.
class _DexControls extends StatelessWidget {
  const _DexControls({
    required this.view,
    required this.region,
    required this.onViewChanged,
    required this.onRegionChanged,
  });

  final _DexView view;
  final String region;
  final ValueChanged<_DexView> onViewChanged;
  final ValueChanged<String> onRegionChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LabeledDropdown<_DexView>(
            label: '구분',
            value: view,
            items: const {
              _DexView.all: '전체 보기',
              _DexView.byRegion: '지역별 보기',
            },
            onChanged: (v) => onViewChanged(v!),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _LabeledDropdown<String>(
            label: '지역',
            value: region,
            enabled: view == _DexView.byRegion,
            items: {for (final r in mockDexRegions) r: r},
            onChanged: (v) => onRegionChanged(v!),
          ),
        ),
      ],
    );
  }
}

/// 라벨 + 드롭다운 한 세트. 디자인 시스템 입력 필드 스타일(§7)에 맞춘 외형.
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.surfaceDisabled,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.inputField),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              value: value,
              onChanged: enabled ? onChanged : null,
              icon: Icon(
                Symbols.expand_more_rounded,
                size: 20,
                color: enabled ? AppColors.iconPrimary : AppColors.iconDisabled,
              ),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.inputField),
              style: AppTextStyles.bodyMedium.copyWith(
                color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final entry in items.entries)
                  DropdownMenuItem<T>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
            ),
          ),
        ),
      ],
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
        const Icon(Symbols.location_on_rounded, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(region, style: AppTextStyles.h3),
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
  const _DexFoodGrid({required this.foods, required this.onTapFood});

  final List<DexFood> foods;
  final ValueChanged<DexFood> onTapFood;

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
        mainAxisExtent: 184,
      ),
      itemBuilder: (context, index) {
        final food = foods[index];
        return _DexFoodCard(food: food, onTap: () => onTapFood(food));
      },
    );
  }
}

class _DexFoodCard extends StatelessWidget {
  const _DexFoodCard({required this.food, required this.onTap});

  final DexFood food;
  final VoidCallback onTap;

  bool get _locked => food.state == DexFoodState.locked;

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
                      child: Image.asset(
                        food.illustrationPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Symbols.dinner_dining_rounded,
                            size: 32,
                            color: _locked
                                ? AppColors.iconDisabled
                                : AppColors.iconInactive,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (food.state == DexFoodState.almost) ...[
                    const Icon(
                      Symbols.star_rounded,
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

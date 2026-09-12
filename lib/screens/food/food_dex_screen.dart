import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
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
/// `GET /foods` (스펙 §10.1) + `GET /users/me/foods` (스펙 §3.9) 를 함께 읽어
/// 각 음식의 도감 상태(만듦/거의/잠김)를 계산한다. 이미 만든 음식 탭 → 실제
/// `UserFood.id` 로 `<음식 히스토리>`, 미제작 음식 탭 → 실제 `foodId` 로
/// `<음식 정보>` 로 연결된다.
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
  const _DexEntry({required this.food, required this.state, this.userFoodId});

  final Food food;
  final _DexFoodState state;

  /// [state] 가 [_DexFoodState.made] 일 때 히스토리 조회에 쓸 `UserFood.id`
  /// (가장 최근에 만든 기록).
  final int? userFoodId;
}

/// 이 화면이 한 번에 필요로 하는 두 응답 — 전체 음식 목록 + 내가 만든 음식 목록.
typedef _DexData = ({List<Food> foods, List<UserFood> made});

class _FoodDexScreenState extends State<FoodDexScreen> {
  _DexView _view = _DexView.byRegion;

  /// 지역별 보기에서 선택된 지역. 전체 보기일 때는 무시된다.
  String? _region;

  late Future<_DexData> _future;

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
    ]);
    return (
      foods: results[0] as List<Food>,
      made: (results[1] as Paged<UserFood>).items,
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
        _entryFor(food, data.made),
    ];
  }

  _DexEntry _entryFor(Food food, List<UserFood> made) {
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
        state: _DexFoodState.made,
        userFoodId: matches.first.id,
      );
    }
    return _DexEntry(
      food: food,
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
                child: FutureBuilder<_DexData>(
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

  Widget _buildBody(BuildContext context, AsyncSnapshot<_DexData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Center(child: CircularProgressIndicator()),
      );
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
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final entries = _buildEntries(snapshot.data!);
    final regions = <String>{
      for (final e in entries)
        if (e.food.regionName != null && e.food.regionName!.isNotEmpty)
          e.food.regionName!,
    }.toList()
      ..sort();
    final region = _region ?? (regions.isEmpty ? null : regions.first);
    final visible = _view == _DexView.all
        ? entries
        : entries.where((e) => e.food.regionName == region).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DexControls(
          view: _view,
          region: region,
          regions: regions,
          onViewChanged: (v) => setState(() => _view = v),
          onRegionChanged: (r) => setState(() => _region = r),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_view == _DexView.byRegion && region != null) ...[
          _RegionSectionHeader(region: region),
          const SizedBox(height: AppSpacing.md),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              '표시할 음식이 없어요.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          _DexFoodGrid(entries: visible, onTapEntry: _onTapEntry),
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

/// "구분" 드롭다운 + "지역" 드롭다운. 지역 드롭다운은 구분이 "지역별 보기"일
/// 때만 활성화된다.
class _DexControls extends StatelessWidget {
  const _DexControls({
    required this.view,
    required this.region,
    required this.regions,
    required this.onViewChanged,
    required this.onRegionChanged,
  });

  final _DexView view;
  final String? region;
  final List<String> regions;
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
          child: regions.isEmpty
              ? _LabeledDropdown<String>(
                  label: '지역',
                  value: '',
                  enabled: false,
                  items: const {'': '지역 정보 없음'},
                  onChanged: (_) {},
                )
              : _LabeledDropdown<String>(
                  label: '지역',
                  value: region ?? regions.first,
                  enabled: view == _DexView.byRegion,
                  items: {for (final r in regions) r: r},
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
        mainAxisExtent: 184,
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
                      child: _NetOrIcon(
                        url: food.imageUrl ?? food.illustrationUrl,
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

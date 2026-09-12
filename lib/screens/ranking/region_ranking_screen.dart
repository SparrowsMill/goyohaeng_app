import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart' show Category;
import '../../data/favorites.dart';
import '../../data/gap_spots.dart';
import '../../data/mock_map_regions.dart' show gapIndexAccent;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/drag_to_resize_handle.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../map/region_spot_map.dart';
import '../place/place_info_screen.dart';
import '../record/my_footprint_screen.dart';

/// `<지역별 랭킹 페이지>` (user_flow §6) — the tourist spots in one region,
/// ranked by 갭지수. Reached by tapping a 시군구/구 on `<지도>`. The top ~40%
/// is a real tile map (`RegionSpotMap`) and the rest is the ranked list; tap a
/// card to drop/highlight its pin on the map, tap again (or the pin) to open
/// `<장소 정보 페이지>`. Category filter + 갭지수 asc/desc sort (default: 전체 ·
/// 내림차순); the chosen filter/sort should persist across visits.
///
/// The map's bottom-left "즐겨찾기" toggle (`MapToggleButton` on `RegionSpotMap`)
/// also narrows this list to the region's favorited spots — it's bound to
/// [Favorites.mapOverlayActive], so arriving here with it already on (from
/// `<지도>`) starts filtered, and flipping it anywhere keeps map + list in sync.
///
/// * TODO(backend): 필터·정렬 설정 영속화 (user_flow §6 "다음 방문 시에도 유지")
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class RegionRankingScreen extends StatefulWidget {
  const RegionRankingScreen({
    super.key,
    required this.regionKey,
    required this.regionName,
    this.initialSpotName,
  });

  final String regionKey;
  final String regionName;

  /// When opened from `<지도>` search for one place: pre-select that spot —
  /// its pin drops on the map, its card highlights and scrolls into view, and
  /// the "자세히 보기" button appears.
  final String? initialSpotName;

  @override
  State<RegionRankingScreen> createState() => _RegionRankingScreenState();
}

class _RegionRankingScreenState extends State<RegionRankingScreen> {
  /// 선택된 카테고리 id (`GET /categories` level 1). `null` == 전체. 서버가
  /// `/places/gap/map`에서 이 id의 하위 categoryId까지 cascade로 걸러준다
  /// (2026-09-12 배포로 검증됨) — 그래서 값이 바뀌면 [_loadSpots]를 다시 호출한다.
  int? _category;
  bool _descending = true;

  /// 이 지역의 스팟. 목업으로 즉시 채우고, GAP API(`/places/gap/map` + 폴리곤
  /// 필터) 응답이 오면 교체한다. [_loaded]가 실제 로드 완료를 표시.
  late List<MockTouristSpot> _allSpots = rankingForRegion(widget.regionKey);

  /// 필터 칩용 level-1 카테고리.
  List<Category> _categories = const [];

  /// The spot highlighted on the map. Tapping a selected spot (card or pin)
  /// again opens its `<장소 정보 페이지>`.
  MockTouristSpot? _selected;

  final ScrollController _listController = ScrollController();
  final GlobalKey _selectedCardKey = GlobalKey();
  bool _didAutoScroll = false;

  /// Fraction of the screen height the map takes — the user drags the grip
  /// between map and list to change it (the list gets the rest).
  double _mapFraction = 0.42;

  /// "즐겨찾기만" — the same shared toggle the map's 즐겨찾기 button drives.
  ValueNotifier<bool> get _favoritesOnly => Favorites.instance.mapOverlayActive;

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onFavoritesChanged);
    _favoritesOnly.addListener(_onFavoritesChanged);
    final name = widget.initialSpotName;
    if (name != null) {
      for (final spot in _allSpots) {
        if (spot.name == name) {
          _selected = spot;
          break;
        }
      }
    }
    _loadSpots();
    GapSpots.instance.level1Categories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    }).catchError((_) {/* 필터 전체만 노출 */});
  }

  Future<void> _loadSpots() async {
    final spots = await GapSpots.instance
        .spotsInRegion(widget.regionKey, categoryId: _category);
    if (!mounted) return;
    setState(() {
      _allSpots = spots;
      final name = widget.initialSpotName;
      if (name != null && _selected == null) {
        for (final spot in spots) {
          if (spot.name == name) {
            _selected = spot;
            break;
          }
        }
      }
      // 카테고리 필터가 바뀌어 선택된 스팟이 결과에서 빠졌으면 선택 해제.
      final selected = _selected;
      if (selected != null && !spots.any((s) => s.name == selected.name)) {
        _selected = null;
      }
    });
  }

  /// 카테고리 필터 변경 — 서버가 걸러주므로 다시 조회한다.
  void _onCategoryChanged(int? categoryId) {
    setState(() => _category = categoryId);
    _loadSpots();
  }

  @override
  void dispose() {
    Favorites.instance.removeListener(_onFavoritesChanged);
    _favoritesOnly.removeListener(_onFavoritesChanged);
    _listController.dispose();
    super.dispose();
  }

  /// Favorites toggled (filter flipped, or a spot un-starred): rebuild, and drop
  /// the selection if it just fell out of the filtered list.
  void _onFavoritesChanged() {
    if (!mounted) return;
    setState(() {
      final s = _selected;
      if (s != null &&
          _favoritesOnly.value &&
          !Favorites.instance.contains(s.name)) {
        _selected = null;
      }
    });
  }

  /// 카테고리 필터는 이미 서버(`GapSpots.spotsInRegion`)가 적용해서 [_allSpots]로
  /// 들어오므로, 여기서는 즐겨찾기 필터 + 정렬만 한다.
  List<MockTouristSpot> get _visibleSpots {
    final favOnly = _favoritesOnly.value;
    final spots = _allSpots
        .where((s) => !favOnly || Favorites.instance.contains(s.name))
        .toList()
      ..sort((a, b) => _descending
          ? b.gapIndex.compareTo(a.gapIndex)
          : a.gapIndex.compareTo(b.gapIndex));
    return spots;
  }

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceInfoScreen(spot: spot, placeId: spot.placeId),
      ),
    );
  }

  /// Card or pin tap: highlight it (the map flies to a located spot). The
  /// selected card then shows a "자세히 보기" button → [_openSpot].
  void _select(MockTouristSpot spot) {
    setState(() => _selected = _selected == spot ? null : spot);
  }

  /// One-shot: bring the search-selected card into view. Retries across a few
  /// frames because the card's element may not be laid out on the first one
  /// (page-push transition, async map sizing).
  void _maybeAutoScroll() {
    if (_didAutoScroll || _selected == null) return;
    _didAutoScroll = true;
    _revealSelectedCard(triesLeft: 5);
  }

  void _revealSelectedCard({required int triesLeft}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _selectedCardKey.currentContext;
      if (ctx == null) {
        if (triesLeft > 0) _revealSelectedCard(triesLeft: triesLeft - 1);
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final spots = _visibleSpots;
    final hasPins = spots.any((s) => s.hasLocation);
    final favOnly = _favoritesOnly.value;
    _maybeAutoScroll();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: Text('${widget.regionName} 관광스팟'),
      ),
      // Top: the region on the real map (pins for located spots); bottom list.
      // The grip between them is draggable to trade height between the two.
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * _mapFraction,
            child: RegionSpotMap(
              key: ValueKey('spotmap_${widget.regionKey}'),
              regionCode: widget.regionKey,
              spots: spots,
              selected: _selected,
              onMarkerTap: _select,
            ),
          ),
          DragToResizeHandle(
            onDrag: (dy) {
              final h = MediaQuery.sizeOf(context).height;
              setState(() {
                _mapFraction = (_mapFraction + dy / h).clamp(0.24, 0.62);
              });
            },
          ),
          // Fixed above the scrolling list — filter/sort stay put as cards move.
          _FilterBar(
            category: _category,
            categories: _categories,
            onCategory: _onCategoryChanged,
            descending: _descending,
            onSort: (value) => setState(() => _descending = value),
            hint: favOnly
                ? '즐겨찾기한 장소만 보고 있어요 · 지도 별 핀과 연동돼요'
                : hasPins
                    ? "장소를 누르면 지도에 표시돼요 · '자세히 보기'로 상세"
                    : '선택한 필터와 정렬은 다음에도 유지돼요',
          ),
          Expanded(child: _buildCardList(spots, favOnly: favOnly)),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).maybePop();
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildCardList(List<MockTouristSpot> spots, {required bool favOnly}) {
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            favOnly
                ? '이 지역엔 즐겨찾기한 장소가 없어요.'
                : '해당하는 관광 스팟이 아직 없어요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView(
      controller: _listController,
      // The list is short (a handful of spots); build every card up front so a
      // search-selected one that sits off-screen still has a laid-out element
      // for [_maybeAutoScroll] to reveal.
      scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        for (var i = 0; i < spots.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSpacing.xs),
          _RankingCard(
            key: spots[i] == _selected ? _selectedCardKey : null,
            rank: i + 1,
            spot: spots[i],
            selected: spots[i] == _selected,
            onTap: () => _select(spots[i]),
            onDetail: () => _openSpot(spots[i]),
          ),
        ],
      ],
    );
  }
}

/// Category + sort dropdowns (side by side) + hint line, pinned above the
/// scrolling ranking list (a subtle bottom divider marks it as fixed chrome).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.categories,
    required this.onCategory,
    required this.descending,
    required this.onSort,
    required this.hint,
  });

  /// 선택된 카테고리 id, `null` == 전체.
  final int? category;

  /// `GET /categories` level 1.
  final List<Category> categories;
  final ValueChanged<int?> onCategory;
  final bool descending;
  final ValueChanged<bool> onSort;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PillDropdown<int?>(
                  value: category,
                  onChanged: onCategory,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PillDropdown<bool>(
                  value: descending,
                  onChanged: (v) => onSort(v ?? true),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('갭지수 높은순')),
                    DropdownMenuItem(value: false, child: Text('갭지수 낮은순')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const GapIndexInfoButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// A compact pill-styled dropdown used for both the category and sort filters.
class _PillDropdown<T> extends StatelessWidget {
  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          icon: const Icon(Symbols.keyboard_arrow_down_rounded, size: 18),
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          dropdownColor: AppColors.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    super.key,
    required this.rank,
    required this.spot,
    required this.onTap,
    required this.onDetail,
    this.selected = false,
  });

  final int rank;
  final MockTouristSpot spot;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // The spot's map-pin colour (갭지수 scale) — used for the row's pin, the
    // emphasised 갭지수 text, and (when selected) the border / 자세히 보기 button.
    final accent = gapIndexAccent(spot.gapIndex);
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? AppColors.textOnPrimaryButton
            : AppColors.textPrimary;

    return Material(
      color: selected
          ? Color.alphaBlend(accent.withValues(alpha: 0.09), AppColors.surface)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RankBadge(rank: rank),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        spot.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: FavoriteStarButton(spotName: spot.name, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _GapValue(gapIndex: spot.gapIndex, accent: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Category · ingredient · visit-verify · business status, all
              // on one line; scrolls sideways rather than wrapping.
              Padding(
                padding: const EdgeInsets.only(left: 26 + AppSpacing.sm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      _Tag(label: spot.categoryName ?? spot.category.label),
                      const SizedBox(width: AppSpacing.xs),
                      _IngredientTag(ingredient: spot.ingredient),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusChip(
                        label: spot.visitVerifiable ? '방문 인증 가능' : '방문 인증 불가',
                        tone: spot.visitVerifiable
                            ? _ChipTone.positive
                            : _ChipTone.muted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusChip(
                        label: spot.businessStatus.label,
                        tone: switch (spot.businessStatus) {
                          BusinessStatus.open => _ChipTone.positive,
                          BusinessStatus.closed => _ChipTone.muted,
                          BusinessStatus.holiday => _ChipTone.negative,
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.xs),
                _DetailButton(
                  onTap: onDetail,
                  color: accent,
                  foreground: onAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "자세히 보기" — appears on the selected ranking card, opens `<장소 정보>`.
/// Filled with the spot's map-pin colour so the card reads as "this pin".
class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.onTap,
    required this.color,
    required this.foreground,
  });

  final VoidCallback onTap;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Symbols.arrow_forward_rounded, size: 18, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  // Medal colors are inherently gold/silver/bronze — not design tokens.
  // Used only as the fallback if the medal art fails to load.
  static const _medalColors = {
    1: Color(0xFFC9A34E),
    2: Color(0xFFACACAC),
    3: Color(0xFFB58150),
  };

  static const _medalAsset = {
    1: 'assets/illustrations/ranking/first.png',
    2: 'assets/illustrations/ranking/second.png',
    3: 'assets/illustrations/ranking/third.png',
  };

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return SizedBox(
        width: 26,
        child: Center(
          child: Text(
            '$rank',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final color = _medalColors[rank]!;
    return Image.asset(
      _medalAsset[rank]!,
      width: 26,
      height: 26,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textOnPrimaryButton,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The 갭지수, emphasised with the scale colour: a filled pin + a bold coloured
/// number, shown at the card's top-right.
class _GapValue extends StatelessWidget {
  const _GapValue({required this.gapIndex, required this.accent});

  final int gapIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.location_on_rounded, size: 18, fill: 1, color: accent),
        const SizedBox(width: 2),
        Text(
          '갭지수 $gapIndex',
          style: AppTextStyles.bodyMedium.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.iconAsset});

  final String label;
  final IconData? icon;

  /// Illustration asset shown instead of [icon] (takes precedence).
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            Image.asset(
              iconAsset!,
              width: 15,
              height: 15,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Symbols.eco_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 3),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IngredientTag extends StatelessWidget {
  const _IngredientTag({required this.ingredient});

  final String? ingredient;

  @override
  Widget build(BuildContext context) {
    if (ingredient == null) {
      return const _Tag(label: '획득 재료 없음', icon: Symbols.do_not_disturb_on_rounded);
    }
    return _Tag(
      label: '$ingredient 획득 가능',
      iconAsset: 'assets/illustrations/icon/ingredient_4.png',
    );
  }
}

enum _ChipTone { positive, muted, negative }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _ChipTone.positive => (AppColors.successBackground, AppColors.success),
      _ChipTone.muted => (AppColors.surfaceDisabled, AppColors.textSecondary),
      _ChipTone.negative => (AppColors.errorBackground, AppColors.error),
    };
    return Container(
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

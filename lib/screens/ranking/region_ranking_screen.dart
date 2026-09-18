import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart' show Category;
import '../../data/favorites.dart';
import '../../data/gap_spots.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/drag_to_resize_handle.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/ranking_card.dart';
import '../map/region_spot_map.dart';
import '../place/place_info_screen.dart';

/// `<지역별 랭킹 페이지>` (user_flow §6) — the tourist spots in one region,
/// ranked by 갭지수. Reached by tapping a 시군구/구 on `<지도>`. The top ~40%
/// is a real tile map (`RegionSpotMap`) and the rest is the ranked list; tap a
/// card to drop/highlight its pin on the map, tap again (or the pin) to open
/// `<장소 정보 페이지>`. Category filter + 갭지수 asc/desc sort (default: 전체 ·
/// 갭지수 높은순) live in a bottom sheet ([_RegionFilterSheet]) behind a
/// filter icon at the top-right of the slim [_RegionHintBar] above the list,
/// which otherwise just shows the current filter state.
///
/// The map's bottom-left "즐겨찾기" toggle (`MapToggleButton` on `RegionSpotMap`)
/// also narrows this list to the region's favorited spots — it's bound to
/// [Favorites.mapOverlayActive], so arriving here with it already on (from
/// `<지도>`) starts filtered, and flipping it anywhere keeps map + list in sync.
///
/// 카테고리·정렬·방문인증 필터는 저장되지 않는다 — 이 화면을 나갔다가 다시
/// 들어오면 항상 기본값(전체·고요 지수 높은순)으로 초기화된다. 현재 선택된
/// 필터는 [_RegionHintBar]에 "{지역}/{카테고리}/{정렬}" 한 줄로 보여준다.
///
/// [initialSpot]이 있으면(검색 결과 탭, 또는 `<전체 랭킹>` 카드 탭) 위 필터·정렬·
/// 즐겨찾기 좁히기는 전부 건너뛰고 그 장소 하나만 지도 핀+카드로 보여준다 —
/// 필터 아이콘·바텀시트 대신 [_SingleSpotBar]를 보여준다.
///
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class RegionRankingScreen extends StatefulWidget {
  const RegionRankingScreen({
    super.key,
    required this.regionKey,
    required this.regionName,
    this.initialSpot,
  });

  final String regionKey;
  final String regionName;

  /// When opened from a `<지도>`/`<전체 랭킹>` search result, or a card tap in
  /// `<전체 랭킹>`: show **only** this one spot instead of fetching the whole
  /// region's ranking — its pin drops on the map (already selected) and its
  /// card is the only row in the list. [regionKey] still positions the map
  /// (its polygon outline, if that region happens to be drawn) but is
  /// otherwise unused; a full region browse (tapping a 시군구 on `<지도>`)
  /// leaves this `null` and fetches/lists the whole region as before.
  final MockTouristSpot? initialSpot;

  @override
  State<RegionRankingScreen> createState() => _RegionRankingScreenState();
}

class _RegionRankingScreenState extends State<RegionRankingScreen> {
  /// 선택된 카테고리 id (`GET /categories` level 1). `null` == 전체. 서버가
  /// `/places/gap/map`에서 이 id의 하위 categoryId까지 cascade로 걸러준다
  /// (2026-09-12 배포로 검증됨) — 그래서 값이 바뀌면 [_loadSpots]를 다시 호출한다.
  int? _category;
  bool _descending = true;

  /// "방문 인증 가능만" — [_visibleSpots]에서 `visitVerifiable != true`인 스팟을
  /// 뺀다. 즐겨찾기 필터와 같은 위치(클라이언트 사이드)에서 적용된다.
  bool _visitVerifiableOnly = false;

  /// 이 지역의 스팟. 목업으로 즉시 채우고, GAP API(`/places/gap/map` + 폴리곤
  /// 필터) 응답이 오면 교체한다. [_loading]이 실제 로드 진행 상태를 표시 —
  /// 목업→실데이터로 예고 없이 바뀌면 렉처럼 보이므로 [LoadingOverlay]로 가린다.
  late List<MockTouristSpot> _allSpots = rankingForRegion(widget.regionKey);
  bool _loading = false;

  /// 필터 칩용 level-1 카테고리.
  List<Category> _categories = const [];

  /// The spot highlighted on the map. Tapping a selected spot (card or pin)
  /// again opens its `<장소 정보 페이지>`.
  MockTouristSpot? _selected;

  final ScrollController _listController = ScrollController();
  final GlobalKey _selectedCardKey = GlobalKey();
  bool _didAutoScroll = false;

  /// Fraction of the screen height the map takes — the user drags the grip
  /// between map and list to change it (the list gets the rest). Starts
  /// larger in 단일 스팟 모드([[_isSingleSpot]], set from [initState]) since
  /// the list is ever only one card and doesn't need much room — the map
  /// (the actual point of a search result) gets the rest instead.
  double _mapFraction = 0.42;
  static const _kSingleSpotMapFraction = 0.5;

  /// "즐겨찾기만" — the same shared toggle the map's 즐겨찾기 button drives.
  ValueNotifier<bool> get _favoritesOnly => Favorites.instance.mapOverlayActive;

  /// Single-spot mode — see [RegionRankingScreen.initialSpot].
  bool get _isSingleSpot => widget.initialSpot != null;

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onFavoritesChanged);
    _favoritesOnly.addListener(_onFavoritesChanged);
    final initial = widget.initialSpot;
    if (initial != null) {
      _allSpots = [initial];
      _selected = initial;
      _mapFraction = _kSingleSpotMapFraction;
    } else {
      _loading = true;
    }
    GapSpots.instance
        .level1Categories()
        .then((cats) {
          if (mounted) setState(() => _categories = cats);
        })
        .catchError((_) {
          /* 필터 전체만 노출 */
        });
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    // 단일 스팟 모드([[initialSpot]])면 지역 전체를 다시 조회하지 않는다 —
    // initState에서 이미 그 장소 하나로 [_allSpots]/[_selected]를 채웠다.
    if (_isSingleSpot) return;

    final spots = await GapSpots.instance.spotsInRegion(
      widget.regionKey,
      categoryId: _category,
    );
    if (!mounted) return;
    setState(() {
      _allSpots = spots;
      _loading = false;
      // 카테고리 필터가 바뀌어 선택된 스팟이 결과에서 빠졌으면 선택 해제.
      final selected = _selected;
      if (selected != null && !spots.any((s) => s.name == selected.name)) {
        _selected = null;
      }
    });
  }

  /// 카테고리 필터 변경 — 서버가 걸러주므로 다시 조회한다.
  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _category = categoryId;
      _loading = true;
    });
    _loadSpots();
  }

  /// 정렬/방문인증 필터는 순수 클라이언트 처리(재정렬/재필터)라 실제 지연은
  /// 없지만, 카테고리 필터(서버 재조회)와 같은 로딩 피드백을 줘서 세 필터가
  /// 일관되게 느껴지도록 짧게 [LoadingOverlay]를 보여준 뒤 적용한다.
  Future<void> _flashLoading(VoidCallback apply) async {
    setState(() => _loading = true);
    await Future.delayed(AppMotion.standard);
    if (!mounted) return;
    setState(() {
      apply();
      _loading = false;
    });
  }

  Future<void> _onSortChanged(bool descending) {
    return _flashLoading(() => _descending = descending);
  }

  Future<void> _onVisitVerifiableOnlyChanged(bool value) {
    return _flashLoading(() {
      _visitVerifiableOnly = value;
      final selected = _selected;
      if (selected != null && value && selected.visitVerifiable != true) {
        _selected = null;
      }
    });
  }

  /// Empty-result "필터 해제" button — clears category/정렬/방문인증만/즐겨찾기만
  /// back to defaults in one tap. [_favoritesOnly] is a shared `ValueNotifier`
  /// with `<지도>`'s toggle, so flipping it here fires [_onFavoritesChanged]
  /// on its own. Mirrors [_onCategoryChanged]: only re-fetch from the server
  /// when the category actually changed.
  void _resetFilters() {
    _favoritesOnly.value = false;
    final categoryChanged = _category != null;
    setState(() {
      _category = null;
      _descending = true;
      _visitVerifiableOnly = false;
      if (categoryChanged) _loading = true;
    });
    if (categoryChanged) _loadSpots();
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
      if (!_isSingleSpot &&
          s != null &&
          _favoritesOnly.value &&
          !Favorites.instance.contains(s.name)) {
        _selected = null;
      }
    });
  }

  /// 단일 스팟 모드([[initialSpot]])에선 필터/정렬 없이 그 하나만 그대로
  /// 보여준다. 그 외엔 카테고리 필터는 이미 서버(`GapSpots.spotsInRegion`)가
  /// 적용해서 [_allSpots]로 들어오므로, 여기서는 즐겨찾기 필터 + 정렬만 한다.
  List<MockTouristSpot> get _visibleSpots {
    if (_isSingleSpot) return _allSpots;
    final favOnly = _favoritesOnly.value;
    final spots =
        _allSpots
            .where((s) => !favOnly || Favorites.instance.contains(s.name))
            .where((s) => !_visitVerifiableOnly || s.visitVerifiable == true)
            .toList()
          ..sort(
            (a, b) => _descending
                ? b.gapIndex.compareTo(a.gapIndex)
                : a.gapIndex.compareTo(b.gapIndex),
          );
    return spots;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegionFilterSheet(
        categories: _categories,
        initialCategory: _category,
        initialDescending: _descending,
        initialVisitVerifiableOnly: _visitVerifiableOnly,
        onCategoryChanged: _onCategoryChanged,
        onSortChanged: _onSortChanged,
        onVisitVerifiableOnlyChanged: _onVisitVerifiableOnlyChanged,
      ),
    );
  }

  /// "{지역}/{카테고리}/{정렬}" 형태의 현재 필터 한 줄 요약 — 즐겨찾기만/방문
  /// 인증 가능만이 켜져 있으면 뒤에 덧붙인다.
  String get _filterSummary {
    String categoryLabel = '전체';
    for (final c in _categories) {
      if (c.id == _category) {
        categoryLabel = c.name;
        break;
      }
    }
    final sortLabel = _descending ? '고요 지수 높은순' : '고요 지수 낮은순';
    var summary = '${widget.regionName}/$categoryLabel/$sortLabel';
    if (_favoritesOnly.value) summary = '$summary · 즐겨찾기만';
    if (_visitVerifiableOnly) summary = '$summary · 방문 인증 가능만';
    return summary;
  }

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceInfoScreen(spot: spot, placeId: spot.placeId),
      ),
    );
  }

  /// Card or pin tap: highlight it (the map flies to a located spot). The
  /// selected card then shows a "자세히 보기" button → [_openSpot]. Tapping the
  /// already-selected spot again clears the highlight instead.
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
    final favOnly = _favoritesOnly.value;
    _maybeAutoScroll();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: Text(
          _isSingleSpot
              ? widget.initialSpot!.name
              : '${widget.regionName} 관광스팟',
        ),
      ),
      // Top: the region on the real map (pins for located spots); bottom list.
      // The grip between them is draggable to trade height between the two.
      body: LoadingOverlay(
        loading: _loading,
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * _mapFraction,
              child: RegionSpotMap(
                key: ValueKey('spotmap_${widget.regionKey}'),
                regionCode: widget.regionKey,
                spots: spots,
                selected: _selected,
                onMarkerTap: (spot) {
                  _select(spot);
                  _revealSelectedCard(triesLeft: 5);
                },
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
            // Fixed above the scrolling list — stays put as cards move. 단일
            // 스팟 모드([[initialSpot]])에선 필터가 의미 없으니(목록이 늘 하나뿐)
            // "검색 결과만 보여준다"는 안내만, 그 외엔 현재 필터 상태 힌트 +
            // 우측 필터 아이콘만 — 실제 카테고리/정렬/방문인증 조절은 그 아이콘의
            // 바텀시트로.
            if (_isSingleSpot)
              const _SingleSpotBar()
            else
              _RegionHintBar(
                text: _filterSummary,
                onFilterTap: _openFilterSheet,
              ),
            Expanded(child: _buildCardList(spots, favOnly: favOnly)),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildCardList(List<MockTouristSpot> spots, {required bool favOnly}) {
    if (spots.isEmpty) {
      // A filter (category/즐겨찾기만/방문인증만) narrowed the region's own
      // spots down to zero — offer a one-tap way back instead of making the
      // user find the filter icon again. Not shown when the region itself
      // just has nothing (no filter active), since resetting wouldn't help.
      final filtersActive = favOnly || _visitVerifiableOnly || _category != null;
      // Top-aligned, not vertically centered: the map above can take up to
      // 62% of the screen (_mapFraction), which would otherwise push this
      // message low enough to be hidden until the user drags the map/list
      // handle up to shrink the map first.
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                favOnly
                    ? '이 지역엔 즐겨찾기한 장소가 없어요.'
                    : _visitVerifiableOnly
                    ? '이 지역엔 방문 인증 가능한 장소가 없어요.'
                    : '해당하는 관광 스팟이 아직 없어요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (filtersActive) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _resetFilters,
                  child: const Text('필터 해제'),
                ),
              ],
            ],
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
      padding: AppBottomNavBar.scrollPadding(
        context,
        const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
      ),
      children: [
        for (var i = 0; i < spots.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSpacing.xs),
          RankingCard(
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

/// Shown instead of [_RegionHintBar] (so its filter icon disappears too) when
/// [_RegionRankingScreenState._isSingleSpot] — filtering a list of exactly
/// one place has nothing to do, so this just says why it's short.
class _SingleSpotBar extends StatelessWidget {
  const _SingleSpotBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.search_rounded,
            size: 16,
            color: AppColors.iconInactive,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('검색한 장소만 보여드려요', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Fixed above the list in the normal (region-browsing) mode — just the
/// current filter/즐겨찾기 상태 안내 + its own top-right filter icon. The
/// actual category/정렬/방문인증 controls live behind that icon, in
/// [_RegionFilterSheet].
class _RegionHintBar extends StatelessWidget {
  const _RegionHintBar({required this.text, required this.onFilterTap});

  final String text;

  /// Top-right filter icon — opens [_RegionFilterSheet]. Placed here (over
  /// the draggable map/list split), not the app bar, so it stays right above
  /// the list it controls.
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.caption)),
          IconButton(
            onPressed: onFilterTap,
            icon: const Icon(Symbols.tune_rounded, size: 20),
            color: AppColors.iconPrimary,
            visualDensity: VisualDensity.compact,
            tooltip: '필터',
          ),
        ],
      ),
    );
  }
}

/// `<지역별 랭킹>`의 필터 바텀시트 — 카테고리·정렬·방문인증, 앱바 필터
/// 아이콘 뒤에 숨겨져 있다가 탭하면 뜬다. 즉시 반영되는 컨트롤이라 로컬
/// 상태로 화면을 바로 갱신하면서, 실제 반영·저장은 부모의 콜백에 맡긴다.
class _RegionFilterSheet extends StatefulWidget {
  const _RegionFilterSheet({
    required this.categories,
    required this.initialCategory,
    required this.initialDescending,
    required this.initialVisitVerifiableOnly,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onVisitVerifiableOnlyChanged,
  });

  final List<Category> categories;
  final int? initialCategory;
  final bool initialDescending;
  final bool initialVisitVerifiableOnly;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<bool> onSortChanged;
  final ValueChanged<bool> onVisitVerifiableOnlyChanged;

  @override
  State<_RegionFilterSheet> createState() => _RegionFilterSheetState();
}

class _RegionFilterSheetState extends State<_RegionFilterSheet> {
  late int? _category = widget.initialCategory;
  late bool _descending = widget.initialDescending;
  late bool _visitVerifiableOnly = widget.initialVisitVerifiableOnly;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('필터', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: PillDropdown<int?>(
                    value: _category,
                    onChanged: (v) {
                      setState(() => _category = v);
                      widget.onCategoryChanged(v);
                    },
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체')),
                      for (final c in widget.categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PillDropdown<bool>(
                    value: _descending,
                    onChanged: (v) {
                      setState(() => _descending = v ?? true);
                      widget.onSortChanged(v ?? true);
                    },
                    items: const [
                      DropdownMenuItem(value: true, child: Text('고요 지수 높은순')),
                      DropdownMenuItem(value: false, child: Text('고요 지수 낮은순')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            VisitVerifiableFilterChip(
              active: _visitVerifiableOnly,
              onTap: () {
                setState(() => _visitVerifiableOnly = !_visitVerifiableOnly);
                widget.onVisitVerifiableOnlyChanged(_visitVerifiableOnly);
              },
            ),
          ],
        ),
      ),
    );
  }
}

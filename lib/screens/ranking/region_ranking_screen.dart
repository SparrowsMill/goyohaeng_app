import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api.dart' show Category;
import '../../data/favorites.dart';
import '../../data/gap_spots.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/drag_to_resize_handle.dart';
import '../../widgets/ranking_card.dart';
import '../map/region_spot_map.dart';
import '../place/place_info_screen.dart';
import 'ranking_screen.dart';
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
/// 카테고리·정렬 필터는 기기 로컬(`SharedPreferences`)에 저장돼 다음 방문 시에도
/// 유지된다(user_flow §6) — 서버 동기화가 필요한 값이 아니라 지역 무관 전역
/// 설정 하나로 취급한다.
///
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
  static const _kPrefCategory = 'ranking.filter.categoryId';
  static const _kPrefDescending = 'ranking.filter.descending';

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
    _restoreFilterPrefs();
    GapSpots.instance.level1Categories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    }).catchError((_) {/* 필터 전체만 노출 */});
  }

  /// 저장된 필터·정렬을 불러온 뒤 그 값으로 첫 조회를 시작한다. 저장된 값이
  /// 없으면 기본값(전체·내림차순)으로 곧장 [_loadSpots]를 부른다.
  Future<void> _restoreFilterPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _category =
          prefs.containsKey(_kPrefCategory) ? prefs.getInt(_kPrefCategory) : null;
      _descending = prefs.getBool(_kPrefDescending) ?? true;
    });
    _loadSpots();
  }

  Future<void> _saveCategoryPref(int? categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    if (categoryId == null) {
      await prefs.remove(_kPrefCategory);
    } else {
      await prefs.setInt(_kPrefCategory, categoryId);
    }
  }

  Future<void> _saveDescendingPref(bool descending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefDescending, descending);
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
    _saveCategoryPref(categoryId);
  }

  void _onSortChanged(bool descending) {
    setState(() => _descending = descending);
    _saveDescendingPref(descending);
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
          RankingFilterBar(
            category: _category,
            categories: _categories,
            onCategory: _onCategoryChanged,
            descending: _descending,
            onSort: _onSortChanged,
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

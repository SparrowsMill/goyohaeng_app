import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart' show Category, GapService;
import '../../data/gap_spots.dart';
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart' show kSidoShortName;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/place_search_bar.dart';
import '../../widgets/ranking_card.dart';
import '../../widgets/region_lock.dart';
import '../map/place_search_screen.dart';
import 'region_ranking_screen.dart';

/// `<전체 랭킹>` — the bottom nav "랭킹" tab's landing page. Unlike
/// `<지역별 랭킹>`(`RegionRankingScreen`, reached by tapping a 시군구 on
/// `<지도>`), this can browse any region's GAP 스팟, defaulting to 서울(the
/// only region with real GAP data, [[region_lock]]) instead of 전국. The app
/// bar's filter icon opens a bottom sheet with the 시도/시군구 dropdowns,
/// category, and sort/방문 인증 필터; the top of the body itself is a search
/// bar (`<지도>`와 같은 컴포넌트).
///
/// 필터는 저장되지 않는다 — 이 탭을 나갔다가 다시 들어오면(바텀 네비게이션이
/// 매번 새 인스턴스를 만든다) 항상 기본값(서울·전체 카테고리·고요 지수
/// 높은순)으로 초기화된다. 현재 선택된 필터는 검색 바 아래 한 줄 문구로
/// 보여준다(예: "서울/동대문구/축제/고요 지수 낮은순").
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const _nationwidePageLimit = 50;

  /// 진입 시 기본 지역 — 서울(11)만 실 GAP 데이터가 있어 유일하게 잠금 해제돼
  /// 있다([[region_lock]]). "전체 시/도"(전국)가 아니라 서울이 기본값.
  static const _kDefaultSidoCode = '11';

  String? _sidoCode = _kDefaultSidoCode;
  String? _sigunguCode;
  int? _category;
  bool _descending = true;

  /// "방문 인증 가능만" — 켜면 [_visibleSpots]에서 `visitVerifiable != true`인
  /// 스팟을 뺀다. 서버가 걸러주는 값이 아니라 클라이언트에서 로드된 목록을 거른다.
  bool _visitVerifiableOnly = false;

  List<GeoRegion> _sidoList = const [];
  List<GeoRegion> _sigunguOptions = const [];

  /// 필터 시트 + 상단 필터 문구용 level-1 카테고리.
  List<Category> _categories = const [];

  List<MockTouristSpot> _spots = const [];
  bool _loading = true;
  bool _error = false;
  int _requestId = 0;

  /// 지역 필터 없음(전국)일 때만 쓰는 스크롤 기반 점진 로딩 상태 — 지역
  /// 필터가 걸리면(`spotsInRegion`) 이미 단일 호출이라 해당 없음. 서버가 GAP
  /// 점수 내림차순만 지원해([[gap-score-api]]) 오름차순은 마지막 페이지부터
  /// 역순으로 페이징한다.
  bool _nationwideActive = false;
  int _nationwidePage = 0;
  bool _hasMoreNationwide = false;
  bool _loadingMoreNationwide = false;
  final _scrollController = ScrollController();

  void _onScroll() {
    if (!_nationwideActive ||
        _loading ||
        _loadingMoreNationwide ||
        !_hasMoreNationwide ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 400) {
      _loadMoreNationwide();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFilterOptions();
    GapSpots.instance
        .level1Categories()
        .then((cats) {
          if (mounted) setState(() => _categories = cats);
        })
        .catchError((_) {
          /* 필터엔 "전체"만 노출 */
        });
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final geo = await KoreaGeo.load();
    if (!mounted) return;
    setState(() => _sidoList = geo.sido);
    if (_sidoCode != null) {
      await geo.ensureSigungu();
      if (!mounted || _sidoCode == null) return;
      setState(() => _sigunguOptions = geo.sigunguOf(_sidoCode!));
    }
  }

  Future<void> _onSidoChanged(String? code) async {
    if (code != null && isSidoLocked(code)) {
      showRegionComingSoonToast(context);
      return;
    }
    setState(() {
      _sidoCode = code;
      _sigunguCode = null;
      _sigunguOptions = const [];
    });
    if (code != null) {
      final geo = await KoreaGeo.load();
      await geo.ensureSigungu();
      if (!mounted || _sidoCode != code) return;
      setState(() => _sigunguOptions = geo.sigunguOf(code));
    }
    _load();
  }

  void _onSigunguChanged(String? code) {
    setState(() => _sigunguCode = code);
    _load();
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() => _category = categoryId);
    _load();
  }

  /// 방문인증 필터는 순수 클라이언트 처리(재필터)라 실제 지연은 없지만,
  /// 지역·카테고리 필터(서버 재조회, [_load])와 같은 로딩 피드백을 줘서 필터가
  /// 일관되게 느껴지도록 짧게 [LoadingOverlay]를 보여준 뒤 적용한다. 적용 후
  /// 필터로 목록이 짧아져 화면이 안 채워졌으면 [_onScroll]을 한 번 더 불러
  /// 다음 페이지를 이어 채운다(전국 모드에서만 실제로 동작).
  Future<void> _flashLoading(VoidCallback apply) async {
    setState(() => _loading = true);
    await Future.delayed(AppMotion.standard);
    if (!mounted) return;
    setState(() {
      apply();
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  /// 오름차순은 서버가 지원하지 않는 정렬이라([[gap-score-api]]) 전국 모드에서는
  /// 이미 불러온 일부만 재정렬할 수 없고, 처음부터 다시 불러와야 한다(마지막
  /// 페이지부터 역순 페이징). 지역 필터가 걸린 경우는 원래대로 로드된 전체를
  /// 클라이언트에서 재정렬한다.
  Future<void> _onSortChanged(bool descending) {
    if (_nationwideActive) {
      setState(() => _descending = descending);
      return _load();
    }
    return _flashLoading(() {
      _descending = descending;
      _spots = [..._spots]
        ..sort(
          (a, b) => descending
              ? b.gapIndex.compareTo(a.gapIndex)
              : a.gapIndex.compareTo(b.gapIndex),
        );
    });
  }

  Future<void> _onVisitVerifiableOnlyChanged(bool value) {
    return _flashLoading(() => _visitVerifiableOnly = value);
  }

  List<MockTouristSpot> get _visibleSpots => _visitVerifiableOnly
      ? _spots.where((s) => s.visitVerifiable == true).toList()
      : _spots;

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
      _spots = const [];
      _nationwidePage = 0;
      _hasMoreNationwide = false;
    });

    final regionCode = _sigunguCode ?? _sidoCode;
    if (regionCode != null) {
      _nationwideActive = false;
      List<MockTouristSpot> spots;
      var failed = false;
      try {
        spots = await GapSpots.instance.spotsInRegion(
          regionCode,
          categoryId: _category,
        );
      } catch (_) {
        spots = const [];
        failed = true;
      }
      if (!mounted || requestId != _requestId) return;
      spots = [...spots]
        ..sort(
          (a, b) => _descending
              ? b.gapIndex.compareTo(a.gapIndex)
              : a.gapIndex.compareTo(b.gapIndex),
        );
      setState(() {
        _spots = spots;
        _loading = false;
        _error = failed;
      });
      return;
    }

    _nationwideActive = true;
    await _loadFirstNationwidePage(requestId);
  }

  /// 지역 필터 없음(전국) — `GET /places/gap/rankings` 첫 페이지만 불러오고
  /// 나머지는 스크롤에 따라 [_loadMoreNationwide]가 이어붙인다. 내림차순은
  /// 서버 기본 정렬 그대로 1페이지부터, 오름차순은 서버가 못 주는 정렬이라
  /// 총 페이지 수만 가벼운 호출(limit 1)로 먼저 확인한 뒤 마지막 페이지부터
  /// 역순으로 시작한다.
  Future<void> _loadFirstNationwidePage(int requestId) async {
    final gap = GapService();
    try {
      if (_descending) {
        final result = await gap.rankings(
          categoryId: _category,
          page: 1,
          limit: _nationwidePageLimit,
        );
        final spots = await GapSpots.instance.toSpots(result.items);
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _spots = spots;
          _nationwidePage = 1;
          _hasMoreNationwide = result.hasMore;
          _loading = false;
        });
      } else {
        final probe = await gap.rankings(
          categoryId: _category,
          page: 1,
          limit: 1,
        );
        final totalPages = probe.totalPages;
        if (totalPages <= 0) {
          if (!mounted || requestId != _requestId) return;
          setState(() {
            _spots = const [];
            _loading = false;
          });
          return;
        }
        final result = await gap.rankings(
          categoryId: _category,
          page: totalPages,
          limit: _nationwidePageLimit,
        );
        final spots = await GapSpots.instance.toSpots(
          result.items.reversed.toList(),
        );
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _spots = spots;
          _nationwidePage = totalPages;
          _hasMoreNationwide = totalPages > 1;
          _loading = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// 스크롤이 바닥에 가까워지면 다음(내림차순) 또는 이전(오름차순, 역순
  /// 페이징) 페이지를 이어붙인다.
  Future<void> _loadMoreNationwide() async {
    final requestId = _requestId;
    setState(() => _loadingMoreNationwide = true);
    try {
      final gap = GapService();
      final nextPage = _descending ? _nationwidePage + 1 : _nationwidePage - 1;
      final result = await gap.rankings(
        categoryId: _category,
        page: nextPage,
        limit: _nationwidePageLimit,
      );
      final items = _descending
          ? result.items
          : result.items.reversed.toList();
      final spots = await GapSpots.instance.toSpots(items);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _spots = [..._spots, ...spots];
        _nationwidePage = nextPage;
        _hasMoreNationwide = _descending ? result.hasMore : nextPage > 1;
        _loadingMoreNationwide = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _loadingMoreNationwide = false);
    }
  }

  /// 카드 탭 — `<장소 정보>`로 바로 가는 대신 `<지역별 랭킹>`을 단일 스팟
  /// 모드로 열어 실제 위치 핀을 지도에서 보여준다(이 화면엔 지도가 없다).
  /// `regionKey`는 지도 폴리곤 표시에만 쓰이고 핀 위치엔 영향이 없어, 현재
  /// 시도/시군구 필터를 그대로 최선노력으로 넘긴다.
  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegionRankingScreen(
          regionKey: _sigunguCode ?? _sidoCode ?? '',
          regionName: spot.name,
          initialSpot: spot,
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RankingFilterSheet(
        sidoList: _sidoList,
        initialSigunguOptions: _sigunguOptions,
        initialSidoCode: _sidoCode,
        initialSigunguCode: _sigunguCode,
        categories: _categories,
        initialCategory: _category,
        initialDescending: _descending,
        initialVisitVerifiableOnly: _visitVerifiableOnly,
        onSidoChanged: _onSidoChanged,
        onSigunguChanged: _onSigunguChanged,
        onCategoryChanged: _onCategoryChanged,
        onSortChanged: _onSortChanged,
        onVisitVerifiableOnlyChanged: _onVisitVerifiableOnlyChanged,
        currentSigunguOptions: () => _sigunguOptions,
      ),
    );
  }

  /// "서울/동대문구/축제/고요 지수 낮은순" 형태의 현재 필터 한 줄 요약.
  String get _filterSummary {
    final sidoLabel = _sidoCode != null
        ? (kSidoShortName[_sidoCode] ??
              _sidoList
                  .firstWhere(
                    (r) => r.id == _sidoCode,
                    orElse: () =>
                        GeoRegion(id: '', title: '전체', rings: const []),
                  )
                  .title)
        : '전체';
    final sigunguLabel = _sigunguCode != null
        ? _sigunguOptions
              .firstWhere(
                (r) => r.id == _sigunguCode,
                orElse: () => GeoRegion(id: '', title: '전체', rings: const []),
              )
              .title
        : '전체';
    String categoryLabel = '전체';
    for (final c in _categories) {
      if (c.id == _category) {
        categoryLabel = c.name;
        break;
      }
    }
    final sortLabel = _descending ? '고요 지수 높은순' : '고요 지수 낮은순';
    final summary = '$sidoLabel/$sigunguLabel/$categoryLabel/$sortLabel';
    return _visitVerifiableOnly ? '$summary · 방문 인증 가능만' : summary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text('전체 랭킹'),
        actions: [
          IconButton(
            onPressed: _openFilterSheet,
            icon: const Icon(Symbols.tune_rounded),
            tooltip: '필터',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xs,
            ),
            child: PlaceSearchBar(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(_filterSummary, style: AppTextStyles.caption),
          ),
          Expanded(
            child: LoadingOverlay(loading: _loading, child: _buildBody()),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      // The Expanded-level LoadingOverlay already shows the loading pill.
      return const SizedBox.shrink();
    }
    final spots = _visibleSpots;
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            _error
                ? '랭킹을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'
                : _visitVerifiableOnly
                ? '방문 인증 가능한 장소가 아직 없어요.'
                : '해당하는 관광 스팟이 아직 없어요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final showLoadingMore = _nationwideActive && _loadingMoreNationwide;
    return ListView.separated(
      controller: _scrollController,
      padding: AppBottomNavBar.scrollPadding(
        context,
        const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
      ),
      itemCount: spots.length + (showLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) {
        if (i >= spots.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        return RankingCard(
          rank: i + 1,
          spot: spots[i],
          onTap: () => _openSpot(spots[i]),
          onDetail: () => _openSpot(spots[i]),
        );
      },
    );
  }
}

/// 시도 → 시군구 두 단계 드롭다운. 시도를 고르면 그 안의 시군구만 채워지고,
/// 시도를 "전체"로 되돌리면 시군구도 같이 "전체"로 리셋된다. `<전체 랭킹>`의 필터
/// 바텀시트(`_RankingFilterSheet`) 안에서만 쓰인다.
class _RegionFilterRow extends StatelessWidget {
  const _RegionFilterRow({
    required this.sidoList,
    required this.sigunguOptions,
    required this.sidoCode,
    required this.sigunguCode,
    required this.onSidoChanged,
    required this.onSigunguChanged,
  });

  final List<GeoRegion> sidoList;
  final List<GeoRegion> sigunguOptions;
  final String? sidoCode;
  final String? sigunguCode;
  final ValueChanged<String?> onSidoChanged;
  final ValueChanged<String?> onSigunguChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Symbols.location_on_rounded,
          size: 18,
          color: AppColors.iconInactive,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: PillDropdown<String?>(
            value: sidoCode,
            onChanged: onSidoChanged,
            items: [const DropdownMenuItem(value: '11', child: Text('서울'))],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PillDropdown<String?>(
            value: sigunguCode,
            onChanged: sidoCode == null ? null : onSigunguChanged,
            items: [
              const DropdownMenuItem(value: null, child: Text('전체 시/군/구')),
              for (final s in sigunguOptions)
                DropdownMenuItem(value: s.id, child: Text(s.title)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The `<전체 랭킹>` filter bottom sheet — region, category, sort, and 방문
/// 인증 필터, all in one place behind the app bar's filter icon. Owns a local
/// copy of the filter state so its controls update instantly while calling
/// straight through to [_RankingScreenState]'s own handlers, which do the
/// actual loading/persisting.
class _RankingFilterSheet extends StatefulWidget {
  const _RankingFilterSheet({
    required this.sidoList,
    required this.initialSigunguOptions,
    required this.initialSidoCode,
    required this.initialSigunguCode,
    required this.categories,
    required this.initialCategory,
    required this.initialDescending,
    required this.initialVisitVerifiableOnly,
    required this.onSidoChanged,
    required this.onSigunguChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onVisitVerifiableOnlyChanged,
    required this.currentSigunguOptions,
  });

  final List<GeoRegion> sidoList;
  final List<GeoRegion> initialSigunguOptions;
  final String? initialSidoCode;
  final String? initialSigunguCode;
  final List<Category> categories;
  final int? initialCategory;
  final bool initialDescending;
  final bool initialVisitVerifiableOnly;

  /// `_RankingScreenState._onSidoChanged` — updates the parent's region state
  /// and reloads. Awaited so the sheet knows when [currentSigunguOptions] is
  /// safe to re-read.
  final Future<void> Function(String? code) onSidoChanged;
  final ValueChanged<String?> onSigunguChanged;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<bool> onSortChanged;
  final ValueChanged<bool> onVisitVerifiableOnlyChanged;

  /// Reads `_RankingScreenState._sigunguOptions` after [onSidoChanged]
  /// finishes loading the new 시도's 시군구 list.
  final List<GeoRegion> Function() currentSigunguOptions;

  @override
  State<_RankingFilterSheet> createState() => _RankingFilterSheetState();
}

class _RankingFilterSheetState extends State<_RankingFilterSheet> {
  late String? _sidoCode = widget.initialSidoCode;
  late String? _sigunguCode = widget.initialSigunguCode;
  late List<GeoRegion> _sigunguOptions = widget.initialSigunguOptions;
  late int? _category = widget.initialCategory;
  late bool _descending = widget.initialDescending;
  late bool _visitVerifiableOnly = widget.initialVisitVerifiableOnly;

  Future<void> _onSido(String? code) async {
    if (code != null && isSidoLocked(code)) {
      showRegionComingSoonToast(context);
      return;
    }
    setState(() {
      _sidoCode = code;
      _sigunguCode = null;
      _sigunguOptions = const [];
    });
    await widget.onSidoChanged(code);
    if (!mounted || _sidoCode != code) return;
    setState(() => _sigunguOptions = widget.currentSigunguOptions());
  }

  void _onSigungu(String? code) {
    setState(() => _sigunguCode = code);
    widget.onSigunguChanged(code);
  }

  void _onCategory(int? categoryId) {
    setState(() => _category = categoryId);
    widget.onCategoryChanged(categoryId);
  }

  void _onSort(bool descending) {
    setState(() => _descending = descending);
    widget.onSortChanged(descending);
  }

  void _onVisitVerifiableOnly(bool value) {
    setState(() => _visitVerifiableOnly = value);
    widget.onVisitVerifiableOnlyChanged(value);
  }

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
            _RegionFilterRow(
              sidoList: widget.sidoList,
              sigunguOptions: _sigunguOptions,
              sidoCode: _sidoCode,
              sigunguCode: _sigunguCode,
              onSidoChanged: _onSido,
              onSigunguChanged: _onSigungu,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: PillDropdown<int?>(
                    value: _category,
                    onChanged: _onCategory,
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
                    onChanged: (v) => _onSort(v ?? true),
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
              onTap: () => _onVisitVerifiableOnly(!_visitVerifiableOnly),
            ),
          ],
        ),
      ),
    );
  }
}

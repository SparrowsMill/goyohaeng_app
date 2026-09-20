import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart' show Category, GapPlace, GapService;
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
import '../../widgets/pagination_bar.dart';
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
/// 목록은 [_pageSize]개씩 끊어 보여주고, 리스트 맨 아래 [PaginationBar]로
/// 페이지를 넘긴다(필터가 바뀌면 1페이지로 돌아간다).
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
  /// 한 페이지에 보여줄 스팟 수.
  static const _pageSize = 15;

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

  /// 현재 페이지(1부터). 하단 [PaginationBar]로 바꾼다.
  ///
  /// 지역 필터가 걸리면(`spotsInRegion`) 전체 목록을 한 번에 받아 [_spots]에
  /// 두고 클라이언트에서 [_pageSize]개씩 잘라 보여준다. 지역 필터 없음(전국,
  /// [_nationwideActive])일 때는 [_spots]가 현재 페이지분뿐이고 페이지를 넘길
  /// 때마다 서버에서 그 페이지만 받는다. 서버가 GAP 점수 내림차순만 지원해
  /// ([[gap-score-api]]) 오름차순은 마지막 페이지부터 역순으로 대응시킨다.
  int _page = 1;
  bool _nationwideActive = false;
  int _nationwideTotal = 0;
  int _nationwideTotalPages = 1;

  /// 현재 전국 페이지 첫 항목 앞에 있는 항목 수 — 순위 번호(`offset + i + 1`)용.
  /// 오름차순은 첫 페이지가 [_pageSize]보다 짧을 수 있어 `(page - 1) * size`로
  /// 계산할 수 없다.
  int _nationwideRankOffset = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
  /// 지역 모드에선 목록 길이가 바뀌므로 첫 페이지로 돌아간다.
  Future<void> _flashLoading(VoidCallback apply) async {
    setState(() => _loading = true);
    await Future.delayed(AppMotion.standard);
    if (!mounted) return;
    setState(() {
      apply();
      if (!_nationwideActive) _page = 1;
      _loading = false;
    });
  }

  /// 오름차순은 서버가 지원하지 않는 정렬이라([[gap-score-api]]) 전국 모드에서는
  /// 이미 불러온 일부만 재정렬할 수 없고, 처음부터 다시 불러와야 한다(마지막
  /// 페이지부터 역순 대응). 지역 필터가 걸린 경우는 원래대로 로드된 전체를
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

  /// 진입 기본값(서울·전체 시군구·전체 카테고리·높은순·방문 인증 필터 꺼짐)과
  /// 다른 필터가 하나라도 걸려 있는지.
  bool get _hasActiveFilters =>
      _sidoCode != _kDefaultSidoCode ||
      _sigunguCode != null ||
      _category != null ||
      !_descending ||
      _visitVerifiableOnly;

  /// "필터 해제"(필터 시트) / "필터 초기화"(빈 결과 화면) — 전부 진입 기본값으로 되돌린다. 방문 인증 필터만 켜져 있었다면
  /// 서버 재조회 없이 [_flashLoading]으로, 지역·카테고리·정렬이 바뀌었으면
  /// [_load]로 다시 불러온다.
  void _resetFilters() {
    final needsReload =
        _sidoCode != _kDefaultSidoCode ||
        _sigunguCode != null ||
        _category != null ||
        !_descending;
    if (!needsReload) {
      _flashLoading(() => _visitVerifiableOnly = false);
      return;
    }
    final sidoChanged = _sidoCode != _kDefaultSidoCode;
    setState(() {
      _sidoCode = _kDefaultSidoCode;
      _sigunguCode = null;
      _category = null;
      _descending = true;
      _visitVerifiableOnly = false;
      if (sidoChanged) _sigunguOptions = const [];
    });
    if (sidoChanged) _loadFilterOptions();
    _load();
  }

  List<MockTouristSpot> get _visibleSpots => _visitVerifiableOnly
      ? _spots.where((s) => s.visitVerifiable == true).toList()
      : _spots;

  int get _totalPages => _nationwideActive
      ? _nationwideTotalPages
      : math.max(1, (_visibleSpots.length + _pageSize - 1) ~/ _pageSize);

  /// 현재 페이지에 그릴 (순위, 스팟) 목록. 지역 모드는 필터된 전체 목록에서
  /// [_page]번째 조각을 자르고 순위는 그 목록 안의 위치다. 전국 모드는 [_spots]
  /// 자체가 이미 현재 페이지분이라 자르지 않고, 방문 인증 필터로 빠진 항목이
  /// 있어도 순위는 서버 순서 그대로 둔다.
  List<(int, MockTouristSpot)> get _pageEntries {
    if (_nationwideActive) {
      return [
        for (var i = 0; i < _spots.length; i++)
          if (!_visitVerifiableOnly || _spots[i].visitVerifiable == true)
            (_nationwideRankOffset + i + 1, _spots[i]),
      ];
    }
    final offset = (_page - 1) * _pageSize;
    return [
      for (final (i, spot) in _visibleSpots.skip(offset).take(_pageSize).indexed)
        (offset + i + 1, spot),
    ];
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
      _spots = const [];
      _page = 1;
      _nationwideTotal = 0;
      _nationwideTotalPages = 1;
      _nationwideRankOffset = 0;
    });

    // Let the [LoadingOverlay] actually fade in before any work starts. Once
    // the metadata/place caches are warm, the fetch below resolves in
    // microtasks and its polygon filtering runs synchronously on the UI
    // thread, so without this the overlay never gets a frame and the list just
    // pops in after a freeze. Same beat [_flashLoading] gives the client-side
    // filters.
    await Future.delayed(AppMotion.standard);
    if (!mounted || requestId != _requestId) return;

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
    await _fetchNationwidePage(1, requestId);
  }

  /// 페이지 번호 탭 — 지역 모드는 이미 가진 목록에서 다른 조각을 보여주기만
  /// 하면 되고, 전국 모드는 그 페이지를 서버에서 받아온다.
  Future<void> _goToPage(int page) async {
    if (page == _page || page < 1 || page > _totalPages) return;
    if (!_nationwideActive) {
      setState(() => _page = page);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      return;
    }
    final requestId = ++_requestId;
    setState(() => _loading = true);
    await _fetchNationwidePage(page, requestId);
  }

  /// 지역 필터 없음(전국) — `GET /places/gap/rankings`에서 [page] 한 페이지만
  /// 받아 [_spots]를 교체한다. 내림차순은 서버 정렬 그대로 같은 번호의
  /// 페이지를 받는다. 오름차순은 서버가 못 주는 정렬이라 뒤에서부터 센다:
  /// 화면 1페이지 = 서버 마지막 페이지(뒤집어서), 총 개수/페이지 수는 1페이지를
  /// 열 때 가벼운 호출(limit 1)로 먼저 확인한다.
  ///
  /// 실패했을 때 보여줄 목록이 아직 없으면(첫 로드) [_error]를 세우고, 페이지를
  /// 넘기다 실패한 경우엔 보던 페이지를 그대로 두고 안내만 띄운다.
  Future<void> _fetchNationwidePage(int page, int requestId) async {
    final gap = GapService();
    try {
      final int total;
      final int totalPages;
      final int rankOffset;
      final List<GapPlace> items;
      if (_descending) {
        final result = await gap.rankings(
          categoryId: _category,
          page: page,
          limit: _pageSize,
        );
        total = result.total;
        totalPages = result.totalPages;
        rankOffset = (page - 1) * _pageSize;
        items = result.items;
      } else {
        var knownTotal = _nationwideTotal;
        if (page == 1) {
          final probe = await gap.rankings(
            categoryId: _category,
            page: 1,
            limit: 1,
          );
          knownTotal = probe.total;
        }
        total = knownTotal;
        totalPages = (total + _pageSize - 1) ~/ _pageSize;
        if (total == 0) {
          if (!mounted || requestId != _requestId) return;
          setState(() {
            _spots = const [];
            _page = 1;
            _nationwideTotal = 0;
            _nationwideTotalPages = 1;
            _nationwideRankOffset = 0;
            _loading = false;
          });
          return;
        }
        final serverPage = totalPages - page + 1;
        final result = await gap.rankings(
          categoryId: _category,
          page: serverPage,
          limit: _pageSize,
        );
        rankOffset = total - (serverPage - 1) * _pageSize - result.items.length;
        items = result.items.reversed.toList();
      }
      final spots = await GapSpots.instance.toSpots(items);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _spots = spots;
        _page = page;
        _nationwideTotal = total;
        _nationwideTotalPages = math.max(1, totalPages);
        _nationwideRankOffset = rankOffset;
        _loading = false;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      final hasList = _spots.isNotEmpty;
      setState(() {
        _loading = false;
        _error = !hasList;
      });
      if (hasList) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
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
        onReset: _resetFilters,
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterSummaryBox(text: _filterSummary),
            ),
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
      // The Expanded-level LoadingOverlay already shows the loading pill. Must
      // fill the area rather than shrink: the overlay is a Stack sized by this
      // non-positioned child, and the Column hands it loose width, so a
      // zero-size child collapses the whole overlay to 0 wide (blank screen,
      // no pill).
      return const SizedBox.expand();
    }
    final entries = _pageEntries;
    final totalPages = _totalPages;
    // 전국 모드에서 방문 인증 필터로 한 페이지가 통째로 비어도 페이지 바는
    // 남겨, 다른 페이지로 넘어갈 수 있게 한다.
    if (entries.isEmpty && totalPages <= 1) {
      // Top-aligned, not vertically centered — centered, the message sat
      // mid-screen and read as detached from the filter summary above it.
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
              // 필터 때문에 비었을 때만 — 필터 없이 비었거나 로드 실패면
              // 초기화해도 소용없다.
              if (!_error && _hasActiveFilters) ...[
                const SizedBox(height: AppSpacing.md),
                FilterResetButton(label: '필터 초기화', onTap: _resetFilters),
              ],
            ],
          ),
        ),
      );
    }
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
      // 마지막 칸은 페이지 이동 바(페이지가 하나뿐이면 스스로 아무것도 안 그림).
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) {
        if (i == entries.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: PaginationBar(
              page: _page,
              totalPages: totalPages,
              onPageChanged: _goToPage,
            ),
          );
        }
        final (rank, spot) = entries[i];
        return RankingCard(
          rank: rank,
          spot: spot,
          onTap: () => _openSpot(spot),
          onDetail: () => _openSpot(spot),
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
    required this.onReset,
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

  /// `_RankingScreenState._resetFilters` — 전부 진입 기본값으로 되돌리고 다시
  /// 불러온다.
  final VoidCallback onReset;

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

  bool get _hasActiveFilters =>
      _sidoCode != _RankingScreenState._kDefaultSidoCode ||
      _sigunguCode != null ||
      _category != null ||
      !_descending ||
      _visitVerifiableOnly;

  void _reset() {
    setState(() {
      _sidoCode = _RankingScreenState._kDefaultSidoCode;
      _sigunguCode = null;
      _category = null;
      _descending = true;
      _visitVerifiableOnly = false;
    });
    widget.onReset();
  }

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
            Row(
              children: [
                VisitVerifiableFilterChip(
                  active: _visitVerifiableOnly,
                  onTap: () => _onVisitVerifiableOnly(!_visitVerifiableOnly),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterResetButton(
                  onTap: _reset,
                  enabled: _hasActiveFilters,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api.dart' show Category, GapPlace, GapService;
import '../../data/gap_spots.dart';
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart' show kSidoShortName;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/ranking_card.dart';
import '../map/map_screen.dart';
import '../place/place_info_screen.dart';
import '../record/my_footprint_screen.dart';

/// `<전체 랭킹>` — the bottom nav "랭킹" tab's landing page. Unlike
/// `<지역별 랭킹>`(`RegionRankingScreen`, reached by tapping a 시군구 on
/// `<지도>`), this shows every GAP 스팟 nationwide by default; the 시도/시군구
/// dropdowns at the top narrow it down, same as picking a region on the map.
///
/// 카테고리·정렬 필터는 `RegionRankingScreen`과 같은 `SharedPreferences` 키를
/// 공유한다 — "지역 무관 전역 설정 하나"로 취급해 두 화면 어디서 바꾸든 다음
/// 방문 시 그대로 유지된다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const _kPrefCategory = 'ranking.filter.categoryId';
  static const _kPrefDescending = 'ranking.filter.descending';

  /// 전국 GAP 랭킹이 이 페이지 수 넘게 계속 이어지진 않을 거라 보고 안전장치로
  /// 둔 상한 — 냉동창고(cold-start) 단계 데이터 규모 기준([[gap-score-api]]).
  static const _maxNationwidePages = 10;
  static const _nationwidePageLimit = 50;

  String? _sidoCode;
  String? _sigunguCode;
  int? _category;
  bool _descending = true;

  List<GeoRegion> _sidoList = const [];
  List<GeoRegion> _sigunguOptions = const [];
  List<Category> _categories = const [];

  List<MockTouristSpot> _spots = const [];
  bool _loading = true;
  bool _error = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _restorePrefsAndLoad();
  }

  Future<void> _loadFilterOptions() async {
    final geo = await KoreaGeo.load();
    if (mounted) setState(() => _sidoList = geo.sido);
    GapSpots.instance.level1Categories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    }).catchError((_) {/* 필터 전체만 노출 */});
  }

  Future<void> _restorePrefsAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _category =
          prefs.containsKey(_kPrefCategory) ? prefs.getInt(_kPrefCategory) : null;
      _descending = prefs.getBool(_kPrefDescending) ?? true;
    });
    _load();
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

  Future<void> _onSidoChanged(String? code) async {
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
    _saveCategoryPref(categoryId);
  }

  void _onSortChanged(bool descending) {
    setState(() {
      _descending = descending;
      _spots = [..._spots]..sort((a, b) => descending
          ? b.gapIndex.compareTo(a.gapIndex)
          : a.gapIndex.compareTo(b.gapIndex));
    });
    _saveDescendingPref(descending);
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
    });

    final regionCode = _sigunguCode ?? _sidoCode;
    List<MockTouristSpot> spots;
    var failed = false;
    try {
      spots = regionCode != null
          ? await GapSpots.instance
              .spotsInRegion(regionCode, categoryId: _category)
          : await _loadNationwide(_category);
    } catch (_) {
      spots = const [];
      failed = true;
    }
    if (!mounted || requestId != _requestId) return;

    spots = [...spots]..sort((a, b) => _descending
        ? b.gapIndex.compareTo(a.gapIndex)
        : a.gapIndex.compareTo(b.gapIndex));
    setState(() {
      _spots = spots;
      _loading = false;
      _error = failed;
    });
  }

  /// 지역 필터 없음 — `GET /places/gap/rankings`를 categoryId만 넘겨 페이지네이션.
  Future<List<MockTouristSpot>> _loadNationwide(int? categoryId) async {
    final gap = GapService();
    final places = <GapPlace>[];
    var page = 1;
    while (page <= _maxNationwidePages) {
      final result = await gap.rankings(
        categoryId: categoryId,
        page: page,
        limit: _nationwidePageLimit,
      );
      places.addAll(result.items);
      if (!result.hasMore) break;
      page++;
    }
    return GapSpots.instance.toSpots(places);
  }

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceInfoScreen(spot: spot, placeId: spot.placeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionHint = _sigunguCode != null
        ? _sigunguOptions
            .firstWhere((r) => r.id == _sigunguCode,
                orElse: () => GeoRegion(id: '', title: '', rings: const []))
            .title
        : _sidoCode != null
            ? (kSidoShortName[_sidoCode] ??
                _sidoList
                    .firstWhere((r) => r.id == _sidoCode,
                        orElse: () => GeoRegion(id: '', title: '', rings: const []))
                    .title)
            : '전국';

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(title: const Text('전체 랭킹')),
      body: Column(
        children: [
          _RegionFilterRow(
            sidoList: _sidoList,
            sigunguOptions: _sigunguOptions,
            sidoCode: _sidoCode,
            sigunguCode: _sigunguCode,
            onSidoChanged: _onSidoChanged,
            onSigunguChanged: _onSigunguChanged,
          ),
          RankingFilterBar(
            category: _category,
            categories: _categories,
            onCategory: _onCategoryChanged,
            descending: _descending,
            onSort: _onSortChanged,
            hint: '$regionHint 기준 갭지수 랭킹이에요',
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
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
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            _error ? '랭킹을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.' : '해당하는 관광 스팟이 아직 없어요.',
            textAlign: TextAlign.center,
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      itemCount: _spots.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) => RankingCard(
        rank: i + 1,
        spot: _spots[i],
        onTap: () => _openSpot(_spots[i]),
        onDetail: () => _openSpot(_spots[i]),
      ),
    );
  }
}

/// 시도 → 시군구 두 단계 드롭다운. 시도를 고르면 그 안의 시군구만 채워지고,
/// 시도를 "전체"로 되돌리면 시군구도 같이 "전체"로 리셋된다.
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
    return Container(
      color: AppColors.appBackground,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
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
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 시/도')),
                for (final s in sidoList)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(kSidoShortName[s.id] ?? s.title),
                  ),
              ],
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
      ),
    );
  }
}

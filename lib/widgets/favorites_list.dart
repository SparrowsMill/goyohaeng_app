import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../api/api.dart' show Category;
import '../data/favorites.dart';
import '../data/gap_spots.dart';
import '../data/mock_map_regions.dart' show gapIndexAccent;
import '../data/mock_region_ranking.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'favorite_star_button.dart';
import 'app_bottom_nav_bar.dart';
import 'loading_overlay.dart';
import 'ranking_card.dart'
    show
        FilterResetButton,
        FilterSummaryBox,
        PillDropdown,
        VisitVerifiableFilterChip,
        businessStatusChip;

/// The favorites list body — a "즐겨찾기 N곳" header, a filter icon, then a
/// row per favorited place (each keeps its star for in-place removal). Sized by
/// its parent; used as the slide-up panel over the `<지도>` vector map.
///
/// Tapping a row opens `<지역별 랭킹>` (the real tile map) for that spot's
/// region with it pre-selected — the same `initialSpot` flow the map search
/// bar uses, so the spot lands highlighted (pin + "자세히 보기") there.
class FavoritesList extends StatefulWidget {
  const FavoritesList({super.key, required this.onOpenPlace});

  /// A row was tapped — open `<지역별 랭킹>` for [regionCode]/[regionName]
  /// with the spot pre-selected.
  final void Function(
    String regionCode,
    String regionName,
    MockTouristSpot spot,
  )
  onOpenPlace;

  @override
  State<FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<FavoritesList> {
  /// `<지역별 랭킹>`/`<전체 랭킹>`과 같은 필터 세트 — 카테고리·정렬·방문 인증
  /// 가능만. `null` == 전체 카테고리. 카테고리는 로컬 [SpotCategory](3종)가
  /// 아니라 실 백엔드 level-1 카테고리(`GapSpots.level1Categories`, 7종
  /// 안팎)를 그대로 써서 랭킹 화면들과 목록이 일치한다.
  int? _category;
  bool _descending = true;
  bool _visitVerifiableOnly = false;

  /// 필터 시트의 카테고리 드롭다운 옵션.
  List<Category> _categories = const [];

  /// 세 필터 모두 순수 클라이언트 처리(서버 재조회 없음)라 실제 지연은
  /// 없지만, [Favorites.loading](서버 동기화)과 같은 로딩 피드백을 줘서 필터를
  /// 바꿀 때도 렉처럼 느껴지지 않게 짧게 [LoadingOverlay]를 보여준 뒤 적용한다.
  bool _filterLoading = false;

  Future<void> _flashLoading(VoidCallback apply) async {
    setState(() => _filterLoading = true);
    await Future.delayed(AppMotion.standard);
    if (!mounted) return;
    setState(() {
      apply();
      _filterLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    GapSpots.instance
        .level1Categories()
        .then((cats) {
          if (mounted) setState(() => _categories = cats);
        })
        .catchError((_) {
          /* 필터엔 "전체"만 노출 */
        });
  }

  /// "{카테고리}/{정렬}" 형태의 현재 필터 한 줄 요약 — 방문 인증 가능만이
  /// 켜져 있으면 뒤에 덧붙인다.
  String _filterSummary(String? selectedCategoryName) {
    final categoryLabel = _category == null
        ? '전체'
        : (selectedCategoryName ?? '전체');
    final sortLabel = _descending ? '고요 지수 높은순' : '고요 지수 낮은순';
    final summary = '$categoryLabel/$sortLabel';
    return _visitVerifiableOnly ? '$summary · 방문 인증 가능만' : summary;
  }

  bool get _hasActiveFilters =>
      _category != null || !_descending || _visitVerifiableOnly;

  /// "필터 해제"(시트) / "필터 초기화"(빈 결과) — 카테고리·정렬·방문 인증 가능만을
  /// 전부 기본값으로.
  void _resetFilters() {
    _flashLoading(() {
      _category = null;
      _descending = true;
      _visitVerifiableOnly = false;
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FavoritesFilterSheet(
        categories: _categories,
        initialCategory: _category,
        initialDescending: _descending,
        initialVisitVerifiableOnly: _visitVerifiableOnly,
        onCategoryChanged: (value) => _flashLoading(() => _category = value),
        onSortChanged: (value) => _flashLoading(() => _descending = value),
        onVisitVerifiableOnlyChanged: (value) =>
            _flashLoading(() => _visitVerifiableOnly = value),
        onReset: _resetFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Favorites.instance,
      builder: (context, _) {
        final all = Favorites.instance.spots();
        String? selectedCategoryName;
        for (final c in _categories) {
          if (c.id == _category) {
            selectedCategoryName = c.name;
            break;
          }
        }
        final entries =
            [
              for (final f in all)
                if ((_category == null ||
                        f.spot.categoryName == selectedCategoryName) &&
                    (!_visitVerifiableOnly || f.spot.visitVerifiable == true))
                  f,
            ]..sort(
              (a, b) => _descending
                  ? b.spot.gapIndex.compareTo(a.spot.gapIndex)
                  : a.spot.gapIndex.compareTo(b.spot.gapIndex),
            );

        return LoadingOverlay(
          loading: Favorites.instance.loading || _filterLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.star_rounded,
                      size: 20,
                      fill: 1,
                      color: AppColors.secondaryAccent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '즐겨찾기 ${all.length}곳',
                        style: AppTextStyles.title,
                      ),
                    ),
                    IconButton(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Symbols.tune_rounded, size: 20),
                      color: AppColors.iconPrimary,
                      visualDensity: VisualDensity.compact,
                      tooltip: '필터',
                    ),
                  ],
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
                  child: FilterSummaryBox(
                    text: _filterSummary(selectedCategoryName),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              all.isEmpty
                                  ? '아직 즐겨찾기한 장소가 없어요.'
                                  : '조건에 맞는 즐겨찾기 장소가 없어요.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            // 필터 때문에 비었을 때만 — 즐겨찾기가 원래 없으면
                            // 초기화해도 소용없다.
                            if (all.isNotEmpty && _hasActiveFilters) ...[
                              const SizedBox(height: AppSpacing.md),
                              FilterResetButton(
                                label: '필터 초기화',
                                onTap: _resetFilters,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: AppBottomNavBar.scrollPadding(
                          context,
                          const EdgeInsets.only(bottom: AppSpacing.xl),
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: AppSpacing.xl,
                          endIndent: AppSpacing.xl,
                          color: AppColors.divider,
                        ),
                        itemBuilder: (_, i) {
                          final entry = entries[i];
                          return _FavoriteRow(
                            spot: entry.spot,
                            onTap: () {
                              // "전라남도 담양군" — first two address tokens.
                              final regionName = entry.spot.address
                                  .split(' ')
                                  .take(2)
                                  .join(' ');
                              widget.onOpenPlace(
                                entry.regionCode,
                                regionName,
                                entry.spot,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 즐겨찾기 목록의 필터 바텀시트 — `<지역별 랭킹>`(`_RegionFilterSheet`)과
/// 완전히 같은 카테고리·정렬·방문인증 필터 세트를 그대로 재사용한다(카테고리도
/// 같은 `GapSpots.level1Categories` 목록).
class _FavoritesFilterSheet extends StatefulWidget {
  const _FavoritesFilterSheet({
    required this.categories,
    required this.initialCategory,
    required this.initialDescending,
    required this.initialVisitVerifiableOnly,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onVisitVerifiableOnlyChanged,
    required this.onReset,
  });

  final List<Category> categories;
  final int? initialCategory;
  final bool initialDescending;
  final bool initialVisitVerifiableOnly;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<bool> onSortChanged;
  final ValueChanged<bool> onVisitVerifiableOnlyChanged;

  /// 부모의 `_resetFilters` — 세 필터를 전부 기본값으로.
  final VoidCallback onReset;

  @override
  State<_FavoritesFilterSheet> createState() => _FavoritesFilterSheetState();
}

class _FavoritesFilterSheetState extends State<_FavoritesFilterSheet> {
  late int? _category = widget.initialCategory;
  late bool _descending = widget.initialDescending;
  late bool _visitVerifiableOnly = widget.initialVisitVerifiableOnly;

  bool get _hasActiveFilters =>
      _category != null || !_descending || _visitVerifiableOnly;

  void _reset() {
    setState(() {
      _category = null;
      _descending = true;
      _visitVerifiableOnly = false;
    });
    widget.onReset();
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
            Row(
              children: [
                VisitVerifiableFilterChip(
                  active: _visitVerifiableOnly,
                  onTap: () {
                    setState(
                      () => _visitVerifiableOnly = !_visitVerifiableOnly,
                    );
                    widget.onVisitVerifiableOnlyChanged(_visitVerifiableOnly);
                  },
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

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.spot, required this.onTap});

  final MockTouristSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // "전라남도 담양군" — first two address tokens are the 시도 + 시군구.
    final region = spot.address.split(' ').take(2).join(' ');
    final accent = gapIndexAccent(spot.gapIndex);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Symbols.location_on_rounded,
                size: 22,
                fill: 1,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$region · ${spot.categoryName ?? spot.category.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    if (businessStatusChip(spot.businessStatus)
                        case final chip?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(alignment: Alignment.centerLeft, child: chip),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '고요 지수 ${spot.gapIndex}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FavoriteStarButton(
                spotName: spot.name,
                size: 22,
                placeId: spot.placeId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

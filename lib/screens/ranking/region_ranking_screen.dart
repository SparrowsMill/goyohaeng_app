import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_symbols_icons/symbols.dart';

import '../../data/favorites.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../map/region_spot_map.dart';
import '../place/place_info_screen.dart';

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
  /// `null` == 전체.
  SpotCategory? _category;
  bool _descending = true;

  /// The spot highlighted on the map. Tapping a selected spot (card or pin)
  /// again opens its `<장소 정보 페이지>`.
  MockTouristSpot? _selected;

  final ScrollController _listController = ScrollController();
  final GlobalKey _selectedCardKey = GlobalKey();
  bool _didAutoScroll = false;

  /// "즐겨찾기만" — the same shared toggle the map's 즐겨찾기 button drives.
  ValueNotifier<bool> get _favoritesOnly => Favorites.instance.mapOverlayActive;

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onFavoritesChanged);
    _favoritesOnly.addListener(_onFavoritesChanged);
    final name = widget.initialSpotName;
    if (name != null) {
      for (final spot in rankingForRegion(widget.regionKey)) {
        if (spot.name == name) {
          _selected = spot;
          break;
        }
      }
    }
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

  List<MockTouristSpot> get _visibleSpots {
    final favOnly = _favoritesOnly.value;
    final spots = rankingForRegion(widget.regionKey)
        .where((s) => _category == null || s.category == _category)
        .where((s) => !favOnly || Favorites.instance.contains(s.name))
        .toList()
      ..sort((a, b) => _descending
          ? b.gapIndex.compareTo(a.gapIndex)
          : a.gapIndex.compareTo(b.gapIndex));
    return spots;
  }

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
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
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: RegionSpotMap(
              key: ValueKey('spotmap_${widget.regionKey}'),
              regionCode: widget.regionKey,
              spots: spots,
              selected: _selected,
              onMarkerTap: _select,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _buildList(spots, hasPins: hasPins, favOnly: favOnly),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).maybePop();
          }
          // * TODO: 기록 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }

  Widget _buildList(
    List<MockTouristSpot> spots, {
    required bool hasPins,
    required bool favOnly,
  }) {
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
        _CategoryFilter(
          selected: _category,
          onChanged: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SortDropdown(
                descending: _descending,
                onChanged: (value) => setState(() => _descending = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const GapIndexInfoButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          favOnly
              ? '즐겨찾기한 장소만 보고 있어요 · 지도 별 핀과 연동돼요'
              : hasPins
                  ? "장소를 누르면 지도에 표시돼요 · '자세히 보기'로 상세"
                  : '선택한 필터와 정렬은 다음에도 유지돼요',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (spots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: Center(
              child: Text(
                favOnly
                    ? '이 지역엔 즐겨찾기한 장소가 없어요.'
                    : '해당하는 관광 스팟이 아직 없어요.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          for (var i = 0; i < spots.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.md),
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

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onChanged});

  final SpotCategory? selected;
  final ValueChanged<SpotCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, SpotCategory? value})>[
      (label: '전체', value: null),
      for (final category in SpotCategory.values)
        (label: category.label, value: category),
    ];

    // Always one row — the four chips split the width evenly.
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterChip(
              label: items[i].label,
              selected: selected == items[i].value,
              onTap: () => onChanged(items[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.buttonMedium.copyWith(
              color: selected
                  ? AppColors.textOnPrimaryButton
                  : AppColors.primaryPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.descending, required this.onChanged});

  final bool descending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.inputField),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: descending,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          icon: const Icon(Symbols.keyboard_arrow_down_rounded, size: 20),
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          dropdownColor: AppColors.surface,
          items: const [
            DropdownMenuItem(value: true, child: Text('갭지수 내림차순')),
            DropdownMenuItem(value: false, child: Text('갭지수 오름차순')),
          ],
          onChanged: (value) => onChanged(value ?? true),
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
    return Material(
      color: selected ? AppColors.surfaceSelected : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
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
                        style: AppTextStyles.title,
                        maxLines: 2,
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
                    padding: const EdgeInsets.only(top: 3),
                    child: _GapValue(gapIndex: spot.gapIndex),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      selected
                          ? Symbols.location_on_rounded
                          : Symbols.chevron_right_rounded,
                      size: 20,
                      color: selected
                          ? AppColors.primary
                          : AppColors.iconInactive,
                      fill: selected ? 1 : 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Category · ingredient · visit-verify · business status, all
              // on one line; scrolls sideways rather than wrapping.
              Padding(
                padding: const EdgeInsets.only(left: 36 + AppSpacing.sm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      _Tag(label: spot.category.label),
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
                const SizedBox(height: AppSpacing.md),
                _DetailButton(onTap: onDetail),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "자세히 보기" — appears on the selected ranking card, opens `<장소 정보>`.
class _DetailButton extends StatelessWidget {
  const _DetailButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: AppColors.textOnPrimaryButton,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Symbols.arrow_forward_rounded,
                    size: 18, color: AppColors.textOnPrimaryButton),
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
    1: 'assets/illustrations/ranking/gold_medal.png',
    2: 'assets/illustrations/ranking/silver_medal.png',
    3: 'assets/illustrations/ranking/bronze_medal.png',
  };

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return SizedBox(
        width: 36,
        child: Center(
          child: Text(
            '$rank',
            style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final color = _medalColors[rank]!;
    return Image.asset(
      _medalAsset[rank]!,
      width: 36,
      height: 36,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 36,
        height: 36,
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

/// The 갭지수 value with its scale-colored tick, shown at the card's top-right.
class _GapValue extends StatelessWidget {
  const _GapValue({required this.gapIndex});

  final int gapIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: gapIndexColor(gapIndex),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '갭지수 $gapIndex',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
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
    return _Tag(label: '$ingredient 획득 가능', icon: Symbols.eco_rounded);
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
      height: 24,
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

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/place_search.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/ranking_card.dart' show businessStatusChip;
import '../ranking/region_ranking_screen.dart';

/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
///
/// Full-screen search opened from the `<지도>` search bar. Matches 지역명 /
/// 장소명; picking a result opens `<지역별 랭킹>` for that region. A place
/// result also pre-selects its card there — its pin drops on the real map and
/// the "자세히 보기" button appears, so 갭지수·랭킹이 그대로 반영된다.
class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  PlaceSearchIndex? _index;
  String _query = '';

  @override
  void initState() {
    super.initState();
    PlaceSearchIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open(PlaceSearchResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegionRankingScreen(
          regionKey: result.regionCode,
          regionName: result.regionName,
          initialSpot: result.spot,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final results =
        index == null ? const <PlaceSearchResult>[] : index.query(_query);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        titleSpacing: AppSpacing.sm,
        centerTitle: true,
        // Balance the leading back button so the centred bar isn't right-heavy.
        actions: const [SizedBox(width: 48)],
        title: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.inputField),
          ),
          child: Row(
            children: [
              const Icon(Symbols.search_rounded,
                  size: 20, color: AppColors.iconInactive),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  style: AppTextStyles.bodyLarge,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    // Kill the app-wide InputDecorationTheme's outline in every
                    // state — the pill Container is the only frame here.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '지역명 · 장소명 검색',
                    hintStyle: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textDisabled),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() => _query = '');
                    _focus.requestFocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(Symbols.close_rounded,
                        size: 20, color: AppColors.iconInactive),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: LoadingOverlay(
        loading: index == null,
        child: _body(index, results),
      ),
    );
  }

  Widget _body(PlaceSearchIndex? index, List<PlaceSearchResult> results) {
    if (index == null) {
      return const SizedBox.expand();
    }
    if (_query.trim().isEmpty) {
      return _hint('가고 싶은 지역이나 장소를 검색해 보세요');
    }
    if (results.isEmpty) {
      return _hint("'$_query'에 대한 검색 결과가 없어요");
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ResultTile(
        result: results[i],
        onTap: () => _open(results[i]),
      ),
    );
  }

  Widget _hint(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final PlaceSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlace = result.isPlace;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Row(
            children: [
              Icon(
                isPlace ? Symbols.location_on_rounded : Symbols.map_rounded,
                size: 22,
                fill: isPlace ? 1 : 0,
                color: isPlace
                    ? gapIndexColor(result.gapIndex)
                    : AppColors.iconInactive,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    if (businessStatusChip(result.spot?.businessStatus)
                        case final chip?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      chip,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isPlace ? '고요 지수 ${result.gapIndex}' : '평균 ${result.gapIndex}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

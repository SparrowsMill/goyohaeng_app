import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/gap_spots.dart';
import '../../data/mock_nearby_suggestions.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'place_info_screen.dart';

/// `<방문 불가>` (user_flow §6) — reached when the 방문 인증 button is tapped
/// for a spot whose admin 방문 인증 toggle is currently off (or that is on
/// holiday). `place_info_screen.dart`의 `_VisitCtaSection`이 `GET
/// /places/{id}`의 `verification.enabled`로 실시간 판단해 이 화면으로
/// 보낸다. Explains why, then recommends similar-trend nearby spots that
/// can be visited now. Tapping a recommendation opens its `<장소 정보 페이지>`.
class VisitUnavailableScreen extends StatefulWidget {
  const VisitUnavailableScreen({super.key, required this.spot, this.placeId});

  final MockTouristSpot spot;

  /// 실 장소 ID가 있으면 '함께 찾은 관광지'를 `GET /places/{id}/recommendations`
  /// (같은 지역·카테고리의 비슷한 GAP Score 장소)로 채운다. 없으면 목업.
  final int? placeId;

  @override
  State<VisitUnavailableScreen> createState() => _VisitUnavailableScreenState();
}

class _VisitUnavailableScreenState extends State<VisitUnavailableScreen> {
  late List<NearbySpotSuggestion> _suggestions =
      nearbySuggestionsForSpot(widget.spot);

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      GapService().recommendations(id, limit: 4).then((result) async {
        // `available: false`(GAP/지역/카테고리 정보 부족)면 mock 폴백을
        // 그대로 유지 — 단순히 비슷한 장소가 0건인 것과 구분한다.
        if (!mounted || !result.available || result.items.isEmpty) return;
        // `gapPlaceToSpot(p)`를 categoryName 없이 바로 쓰면 카테고리가 항상
        // mock 기본값(액티비티)으로 보인다 — 랭킹 목록과 같은 `GapSpots`
        // categoryId→이름 매핑을 거쳐야 목록에서 보던 카테고리가 그대로 붙는다.
        final spots = await GapSpots.instance.toSpots(result.items);
        if (!mounted) return;
        setState(() {
          _suggestions = [
            for (final s in spots)
              NearbySpotSuggestion(
                spot: s,
                distanceLabel: '같은 지역 · 비슷한 고요 지수',
              ),
          ];
        });
      }).catchError((_) {/* keep the mock suggestions */});
    }
  }

  ({String label, IconData icon}) get _reason {
    if (widget.spot.businessStatus == BusinessStatus.holiday) {
      return (label: '오늘은 휴무예요', icon: Symbols.event_busy_rounded);
    }
    return (label: '지금은 방문 인증을 받지 않아요', icon: Symbols.location_off_rounded);
  }

  void _openSpot(BuildContext context, MockTouristSpot next) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceInfoScreen(spot: next, placeId: next.placeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final reason = _reason;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('방문 안내'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Image.asset(
            'assets/illustrations/scenes/visit_fail_bg.png',
            height: 176,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/illustrations/sparrow/sparrow_default.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 120,
                child: Center(
                  child: Icon(
                    Symbols.no_transfer_rounded,
                    size: 64,
                    color: AppColors.iconInactive,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '해당 장소는 현재 방문이 가능하지 않아요.\n다른 장소를 찾아볼까요?',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: _ReasonPill(label: reason.label, icon: reason.icon)),
          const SizedBox(height: AppSpacing.xl),
          _SuggestionsCard(
            suggestions: suggestions,
            onTap: (next) => _openSpot(context, next),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('이전 장소로 돌아가기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warm warning pill stating why the visit isn't possible.
class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "비슷한 분위기의 주변 장소" card — leaf header + recommendation rows.
class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions, required this.onTap});

  final List<NearbySpotSuggestion> suggestions;
  final ValueChanged<MockTouristSpot> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.largeCard),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/branding/leaf_ornament.png',
                width: 26,
                height: 26,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.eco_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('비슷한 분위기의 주변 장소', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '이곳과 비슷한 트렌드를 가진 가까운 장소를 추천해 드려요.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                '추천할 만한 주변 장소를 아직 찾지 못했어요.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            for (var i = 0; i < suggestions.length; i++) ...[
              if (i != 0) const SizedBox(height: AppSpacing.sm),
              _SuggestionRow(
                suggestion: suggestions[i],
                onTap: () => onTap(suggestions[i].spot),
              ),
            ],
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});

  final NearbySpotSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spot = suggestion.spot;
    // 실 추천 스팟(placeId 있음)은 GAP 추천 API가 트렌드 키워드를 안 줘서
    // `spot.trendKeywords`가 목업 고정 문구('숨은명소' 등)로 남아있다 — 실
    // 장소인 것처럼 보이는 가짜 키워드를 노출하지 않도록 목업 스팟에만 쓴다.
    final keywords = spot.placeId != null
        ? ''
        : spot.trendKeywords.take(2).map((k) => '#$k').join(' · ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.listRow),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSelected,
                  borderRadius: BorderRadius.circular(AppRadius.smallButton),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Image.asset(
                    'assets/illustrations/icon/spot.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Symbols.forest_rounded,
                      size: 26,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spot.name,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${spot.categoryName ?? spot.category.label} · ${suggestion.distanceLabel}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (keywords.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        keywords,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 22,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

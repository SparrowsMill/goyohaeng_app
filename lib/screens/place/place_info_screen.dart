import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../data/favorites.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../data/place_business_status_cache.dart';
import '../../data/place_verification_cache.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/category_illustration.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../../widgets/my_location_button.dart'
    show myLocationAsset, myLocationColor;
import '../../widgets/ranking_card.dart' show businessStatusChip;
import '../trend/trend_summary_screen.dart';
import 'visit_prepare_screen.dart';
import 'visit_unavailable_screen.dart';

/// `<장소 정보 페이지>` (user_flow §6) — one tourist spot's detail page,
/// reached by tapping a spot on `<지역별 랭킹 페이지>` (or the region map).
///
/// Shows the visit state (미방문 / 방문 인증 완료), name + photo, 갭지수 + a
/// short plain-language reading of it, the big 방문 인증 CTA (with the
/// obtainable ingredient + store benefit beneath it), then the category /
/// 주소(+ small 길찾기 button beside it) / 운영시간 / 장소 소개 block,
/// optional 문의처, and the 트렌드 요약 keywords.
///
/// [placeId]가 있으면 (실 장소 목록에서 진입) `GET /places/{placeId}/visit-status`로
/// 방문 인증 완료 여부를 조회해 상단 pill에 반영하고, 방문 인증 흐름에도
/// 그 ID를 넘겨 실제 세션을 만든다 (스펙 §6.3, §7). 영업 상태(`operatingStatus`,
/// 영업 중/영업 전/브레이크타임/영업 종료/휴무일 5단)와 방문 인증 가능 여부
/// (`verification.enabled`)도 `GET /places/{id}`로 실시간 조회한다. placeId가
/// 없으면(목업 스팟) 위 항목 전부 `spot`의 목업 값 사용.
///
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class PlaceInfoScreen extends StatefulWidget {
  const PlaceInfoScreen({super.key, required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  @override
  State<PlaceInfoScreen> createState() => _PlaceInfoScreenState();
}

class _PlaceInfoScreenState extends State<PlaceInfoScreen> {
  MockTouristSpot get spot => widget.spot;
  int? get placeId => widget.placeId;

  @override
  void initState() {
    super.initState();
    final id = placeId;
    if (id != null) {
      AnalyticsService()
          .logEvent(placeId: id, eventType: 'PLACE_DETAIL_VIEW')
          .catchError((_) {});
      // 즐겨찾기 별은 로컬(이름 기반) 스토어를 기준으로 그리는데, 서버가 이미
      // 아는 값(`Place.isFavorite`)과 어긋날 수 있다(다른 기기에서 즐겨찾기,
      // 최초 목록 동기화 실패 등) — 여기서 서버 값으로 맞춘다.
      PlaceService()
          .detail(id)
          .then((place) {
            final isFavorite = place.isFavorite;
            if (isFavorite != null) {
              Favorites.instance.setKnown(spot.name, isFavorite);
            }
          })
          .catchError((_) {});
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Tries each candidate URI in order (native app scheme first, web fallback
  /// after); shows a snack bar if none open.
  Future<void> _open(
    BuildContext context,
    List<Uri> candidates, {
    required String failMessage,
  }) async {
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // try the next candidate
      }
      if (!context.mounted) return;
    }
    if (context.mounted) _snack(context, failMessage);
  }

  /// [address]의 시/도 다음 토큰(들)만 뽑아 "군/구" 단위 지역명을 만든다.
  /// 예: "전라남도 담양군 담양읍 …" → "담양군", "전라북도 전주시 완산구 …" →
  /// "전주시 완산구". 형식에 안 맞으면(주소 미확보 등) `null`.
  String? _regionPrefix(String address) {
    final parts = address.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final second = parts[1];
    if (!RegExp(r'(시|군|구)$').hasMatch(second)) return null;
    if (second.endsWith('시') && parts.length > 2 && parts[2].endsWith('구')) {
      return '$second ${parts[2]}';
    }
    return second;
  }

  /// 네이버 지도 앱(`nmap://`)으로, 실패하면 네이버 지도 웹으로 장소를 연다.
  void _openDirections(BuildContext context) {
    final region = _regionPrefix(spot.address);
    final query = region == null ? spot.name : '$region ${spot.name}';
    final name = Uri.encodeComponent(query);
    final app = spot.hasLocation
        ? Uri.parse(
            'nmap://place?lat=${spot.lat}&lng=${spot.lng}'
            '&name=$name&appname=com.goyohaeng',
          )
        : Uri.parse('nmap://search?query=$name&appname=com.goyohaeng');
    _open(context, [
      app,
      Uri.parse('https://map.naver.com/p/search/$name'),
    ], failMessage: '${spot.name} 위치를 여는 데 실패했어요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('장소 정보'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: FavoriteStarButton(
                spotName: spot.name,
                size: 26,
                placeId: placeId,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
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
          _VisitStatePill(state: spot.visitState, placeId: placeId),
          const SizedBox(height: AppSpacing.md),
          Text(spot.name, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _TitleMedia(spot: spot, placeId: placeId),
          ),
          const SizedBox(height: AppSpacing.xs),
          _CategoryLine(spot: spot),
          const SizedBox(height: AppSpacing.xl),
          _GapCard(spot: spot, placeId: placeId),
          const SizedBox(height: AppSpacing.lg),
          _VisitCtaSection(spot: spot, placeId: placeId),
          const SizedBox(height: AppSpacing.lg),
          _DetailCard(
            spot: spot,
            placeId: placeId,
            onDirections: () => _openDirections(context),
          ),
          _ContactSection(spot: spot, placeId: placeId, openUri: _open),
          const SizedBox(height: AppSpacing.xl),
          _TrendSection(
            spot: spot,
            placeId: placeId,
            onOpenTrend: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TrendSummaryScreen(spot: spot, placeId: placeId),
              ),
            ),
            onKeyword: (keyword) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrendSummaryScreen(
                  spot: spot,
                  focusKeyword: keyword,
                  placeId: placeId,
                ),
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }
}

/// 타이틀 옆 카테고리 워터칼라 일러스트. [placeId]가 있으면 `GET /places/{id}`로
/// 장소 사진(`images[]`, 스펙 §6.2)을 조회해 업로드된 사진이 하나라도 있으면
/// 대표 사진(`images.first`)으로 대체한다 — 없거나 조회 전/실패 시 기존
/// 카테고리 일러스트를 그대로 보여준다.
class _TitleMedia extends StatefulWidget {
  const _TitleMedia({required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  @override
  State<_TitleMedia> createState() => _TitleMediaState();
}

class _TitleMediaState extends State<_TitleMedia> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .detail(id)
          .then((place) {
            final url = place.images.isEmpty ? null : place.images.first.url;
            if (mounted && url != null) setState(() => _photoUrl = url);
          })
          .catchError((_) {
            /* 카테고리 일러스트 유지 */
          });
    }
  }

  Widget _categoryIcon() =>
      CategoryIllustration(spot: widget.spot, size: 200);

  @override
  Widget build(BuildContext context) {
    final url = _photoUrl;
    if (url == null) return _categoryIcon();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Image.network(
        url,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _categoryIcon(),
        loadingBuilder: (context, child, progress) =>
            progress == null
                ? child
                : SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

/// "미방문" / "방문 인증 완료" outlined pill at the top of the page. [placeId]가
/// 있고 로그인 상태면 `GET /places/{placeId}/visit-status`로 실제 값을 덮어쓴다.
class _VisitStatePill extends StatefulWidget {
  const _VisitStatePill({required this.state, this.placeId});

  final VisitState state;
  final int? placeId;

  @override
  State<_VisitStatePill> createState() => _VisitStatePillState();
}

class _VisitStatePillState extends State<_VisitStatePill> {
  late VisitState _state = widget.state;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null && AuthStore.instance.isSignedIn) {
      PlaceService()
          .visitStatus(id)
          .then((status) {
            if (!mounted) return;
            setState(
              () => _state = status.visited
                  ? VisitState.verified
                  : VisitState.notVisited,
            );
          })
          .catchError((_) {
            /* keep the passed-in value */
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final verified = state == VisitState.verified;
    final color = verified ? AppColors.success : AppColors.textSecondary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Symbols.verified_rounded : Symbols.location_on_rounded,
              size: 15,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              state.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "액티비티 · 갭지수 89 ●" — the category + 갭지수 line under the name, with
/// the scale-colored dot at the end.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            '${spot.categoryName ?? spot.category.label} · 고요 지수 ${spot.gapIndex}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: gapIndexColor(spot.gapIndex),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Small outlined "길찾기" button beneath the name.
/// Small outlined "길찾기" button beside the 주소 text in [_DetailCard].
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.smallButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.navigation_rounded,
                size: 14,
                color: myLocationColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '길찾기',
                style: AppTextStyles.caption.copyWith(
                  color: myLocationColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable page card — surface fill, warm border, soft shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// The "이곳의 갭지수" card: big number + scale tick on the left, a plain-
/// language reading of the score on the right. [placeId]가 있으면
/// `GET /places/{id}/gap`으로 실제 GAP Score·설명을 덮어쓴다 (스펙 §GAP).
class _GapCard extends StatefulWidget {
  const _GapCard({required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  @override
  State<_GapCard> createState() => _GapCardState();
}

class _GapCardState extends State<_GapCard> {
  PlaceGapScore? _gap;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      GapService()
          .placeGap(id)
          .then((g) {
            if (mounted) setState(() => _gap = g);
          })
          .catchError((_) {
            /* keep the passed-in mock value */
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gapIndex = _gap?.gapIndex ?? widget.spot.gapIndex;
    final reading = (_gap?.explanation?.trim().isNotEmpty ?? false)
        ? _gap!.explanation!.trim()
        : widget.spot.gapDescription;

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 56,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: gapIndexColor(gapIndex),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '이곳의 고요 지수',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const GapIndexInfoIconButton(),
                ],
              ),
              Text(
                '$gapIndex',
                style: AppTextStyles.display.copyWith(
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                reading,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [_VisitCtaCard] + 방문 인증 가능 여부 분기. [placeId]가 있으면 `GET
/// /places/{id}`의 `verification.enabled`(관리자 방문 인증 토글, 스펙 §6.2)로
/// 실제 가능 여부를 확인해 `<방문 인증>`/`<방문 불가>` 중 어디로 보낼지
/// 정한다. 로드 전·실패·목업 스팟(placeId 없음)이면 `spot.visitVerifiable`을
/// 그대로 쓴다.
class _VisitCtaSection extends StatefulWidget {
  const _VisitCtaSection({required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  @override
  State<_VisitCtaSection> createState() => _VisitCtaSectionState();
}

class _VisitCtaSectionState extends State<_VisitCtaSection> {
  bool? _liveEnabled;

  /// 서버 `benefits[]`(스펙 §6.2 `{id, title, description}` 배열)의 제목들 —
  /// 여러 건일 수 있어 한 줄로 합치지 않고 리스트 그대로 들고 있다가
  /// [_VisitCtaCard]가 줄바꿈해서 나열한다.
  List<String>? _liveBenefits;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .detail(id)
          .then((place) {
            PlaceVerificationCache.set(
              id,
              place.verification?.enabled ?? false,
            );
            PlaceBusinessStatusCache.set(id, place.isOpenNow);
            if (mounted) {
              setState(() {
                _liveEnabled = place.verification?.enabled ?? false;
                _liveBenefits = place.benefits.isEmpty
                    ? null
                    : place.benefits.map((b) => b.title).toList();
              });
            }
          })
          .catchError((_) {
            /* 목업 값 유지 */
          });
    }
  }

  /// CTA 라우팅 전용 확정값 — 어디로든 보내야 하니 끝까지 알 수 없으면
  /// 기존처럼 `true`(가능)로 낙관적 기본값을 쓴다. 화면에 "알 수 없음"을
  /// 노출하는 건 목록 카드([RankingCard])의 몫이라 여기선 다루지 않는다.
  bool get _verifiable => _liveEnabled ?? widget.spot.visitVerifiable ?? true;

  @override
  Widget build(BuildContext context) {
    return _VisitCtaCard(
      spot: widget.spot,
      benefits: _liveBenefits ??
          (widget.spot.storeBenefit == null
              ? null
              : [widget.spot.storeBenefit!]),
      // user_flow §6: 방문 인증 가능 → 방문 인증 페이지, 불가 → 방문 불가.
      onVerify: () {
        if (_verifiable) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VisitPrepareScreen(
                spot: widget.spot,
                placeId: widget.placeId,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VisitUnavailableScreen(
                spot: widget.spot,
                placeId: widget.placeId,
              ),
            ),
          );
        }
      },
    );
  }
}

/// "이곳을 방문해 보세요" — leaf-headed card with the big 방문 인증 CTA and,
/// beneath it, the obtainable ingredient + store benefit.
class _VisitCtaCard extends StatelessWidget {
  const _VisitCtaCard({
    required this.spot,
    required this.onVerify,
    this.benefits,
  });

  final MockTouristSpot spot;
  final VoidCallback onVerify;

  /// 매장 방문 혜택 제목들(`Place.benefits[].title`, 여러 건 가능) — 하나로
  /// 합친 문자열이 아니라 [_RewardBox]가 줄바꿈해서 나열한다.
  final List<String>? benefits;

  @override
  Widget build(BuildContext context) {
    // GAP percentile → drop policy → rarity → 랜덤 재료 순으로 관리자 승인
    // 시점에 결정되므로(스펙 §8.5), 방문 전에 특정 재료 이름을 미리 보여주지
    // 않는다(`availableIngredients`는 일반 GAP 방문 보상 표현에 쓰지 않는다,
    // 스펙 15). 확률표의 모든 정책이 합 1.0이라 방문 인증 시 항상 무언가는
    // 지급된다.
    const ingredientLabel = '방문 인증 시 랜덤 재료 획득';
    final hasBenefit = benefits != null && benefits!.isNotEmpty;
    final benefitLines = hasBenefit ? benefits! : const ['제공 혜택 없음'];

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                myLocationAsset,
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.location_on_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이곳을 방문해 보세요', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '방문 인증을 완료하면 랜덤 재료를 획득할 수 있어요.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onVerify,
              icon: Image.asset(
                'assets/illustrations/icon/verified_2.png',
                width: 32,
                height: 32,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Symbols.where_to_vote_rounded, size: 32),
              ),
              label: const Text('방문 인증'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RewardBox(
            icon: Symbols.eco_rounded,
            iconAsset: 'assets/illustrations/icon/ingredient_4.png',
            lines: const [ingredientLabel],
            active: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _RewardBox(
            icon: Symbols.redeem_rounded,
            iconAsset: 'assets/illustrations/icon/benefit.png',
            lines: benefitLines,
            active: hasBenefit,
          ),
        ],
      ),
    );
  }
}

class _RewardBox extends StatelessWidget {
  const _RewardBox({
    required this.icon,
    required this.lines,
    required this.active,
    this.iconAsset,
  });

  final IconData icon;

  /// Illustration asset shown instead of [icon] (takes precedence).
  final String? iconAsset;

  /// 표시할 문구들 — 여러 건(예: 매장 혜택 여러 개)이면 한 줄로 합치지 않고
  /// 각각 줄바꿈해서 나열한다.
  final List<String> lines;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.successBackground : AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
      ),
      child: Row(
        children: [
          if (iconAsset != null)
            Image.asset(
              iconAsset!,
              width: 22,
              height: 22,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(icon, size: 18, color: tint),
            )
          else
            Icon(icon, size: 18, color: tint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: AppTextStyles.caption.copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// dayOfWeek 원시값(정수/문자열, 인코딩 불명) → ISO 요일(1=월요일..7=일요일).
/// 숫자면 0-based(JS `Date.getDay()`, 일=0)/1-based(ISO, 월=1) 어느 쪽이든
/// `% 7`로 똑같이 판별된다 — 두 인코딩이 월~토(1~6)에서는 이미 같고 일요일만
/// 0/7로 갈리는데, `% 7`을 거치면 그 경계도 하나로 합쳐진다.
int? _isoWeekdayFrom(dynamic raw) {
  int? n;
  if (raw is num) n = raw.round();
  if (raw is String) n = int.tryParse(raw);
  if (n != null) {
    final m = n % 7;
    return m == 0 ? 7 : m;
  }
  if (raw is String) {
    const byName = {
      'mon': 1, 'monday': 1, '월요일': 1, '월': 1,
      'tue': 2, 'tuesday': 2, '화요일': 2, '화': 2,
      'wed': 3, 'wednesday': 3, '수요일': 3, '수': 3,
      'thu': 4, 'thursday': 4, '목요일': 4, '목': 4,
      'fri': 5, 'friday': 5, '금요일': 5, '금': 5,
      'sat': 6, 'saturday': 6, '토요일': 6, '토': 6,
      'sun': 7, 'sunday': 7, '일요일': 7, '일': 7,
    };
    return byName[raw.toLowerCase()];
  }
  return null;
}

const _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// dayOfWeek 원시값 → "월"/"화"/... 한 글자 표기. 못 알아보면(새 인코딩 등)
/// 화면이 비지 않도록 원래 값을 그대로 문자열로 보여준다.
String _koreanWeekdayLabel(dynamic raw) {
  final iso = _isoWeekdayFrom(raw);
  return iso == null ? '$raw' : _koreanWeekdays[iso - 1];
}

/// 요일별로 실제 쓸 수 있는 영업시간이 하나도 없는지 — (1) 배열 자체가
/// 비어 있거나(`operatingHours: []`, 지금 백엔드 응답이 대체로 이 상태),
/// (2) 항목은 있어도 전부 휴무 처리거나 시간이 비어 있어(`_formatHours`가
/// 어차피 전부 "휴무"로만 찍는 경우) 둘 중 하나면 `true`. 상시 개방
/// 관광지처럼 애초에 요일별 정해진 운영시간이 없는 장소가 이렇게 등록되는
/// 경우가 있어, 영업 상태 칩만 덜렁 보여주면 "다 휴무인데 영업 중?"처럼
/// 오해를 살 수 있어 옆에 안내 문구를 붙인다.
bool _hasNoFixedHours(List<Map<String, dynamic>> operatingHours) {
  if (operatingHours.isEmpty) return true;
  for (final h in operatingHours) {
    final closed = h['isClosed'] == true || h['closed'] == true;
    final open = h['openTime'] ?? h['open'];
    final close = h['closeTime'] ?? h['close'];
    if (!closed && open != null && close != null) return false;
  }
  return true;
}

/// The 카테고리 / 주소 / 운영시간 / 장소 소개 block. [placeId]가 있으면
/// `GET /places/{id}`로 실제 소개(`overview`)·주소(`roadAddress`)·영업 상태
/// (`operatingStatus`, 영업 중/영업 전/브레이크타임/영업 종료/휴무일 5단)를
/// 덮어쓴다. `operatingHours`는 스펙 문서에 항목 구조가 아직 확정돼 있지
/// 않아(예시가 항상 빈 배열) 알려진 필드명만 방어적으로 시도하고, 알아볼 수
/// 없으면 목업 [spot.hours]로 그대로 남긴다.
class _DetailCard extends StatefulWidget {
  const _DetailCard({
    required this.spot,
    this.placeId,
    required this.onDirections,
  });

  final MockTouristSpot spot;
  final int? placeId;
  final VoidCallback onDirections;

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  Place? _place;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .detail(id)
          .then((p) {
            PlaceVerificationCache.set(id, p.verification?.enabled ?? false);
            PlaceBusinessStatusCache.set(id, p.isOpenNow);
            if (mounted) setState(() => _place = p);
          })
          .catchError((_) {
            /* keep the mock spot values */
          });
    }
  }

  List<String>? _formatHours(Place place) {
    if (place.operatingHours.isEmpty) return null;
    final lines = <String>[];
    for (final h in place.operatingHours) {
      final dayRaw = h['dayOfWeek'] ?? h['day'] ?? h['dayLabel'];
      if (dayRaw == null) continue;
      final day = _koreanWeekdayLabel(dayRaw);
      final closed = h['isClosed'] == true || h['closed'] == true;
      final open = h['openTime'] ?? h['open'];
      final close = h['closeTime'] ?? h['close'];
      final breakStart = h['breakStartTime'] ?? h['breakStart'];
      final breakEnd = h['breakEndTime'] ?? h['breakEnd'];
      final breakSuffix = breakStart != null && breakEnd != null
          ? ' (브레이크타임 $breakStart - $breakEnd)'
          : '';
      lines.add(
        closed || open == null || close == null
            ? '$day 휴무'
            : '$day $open - $close$breakSuffix',
      );
    }
    return lines.isEmpty ? null : lines;
  }

  /// 오늘 요일 항목의 브레이크타임 "HH:mm - HH:mm" — 없으면 null. 상태 칩이
  /// "브레이크타임"일 때 몇 시까지인지 바로 옆에 덧붙이는 용도.
  String? _todayBreakRange(Place place) {
    final todayIso = DateTime.now().weekday;
    for (final h in place.operatingHours) {
      final dayRaw = h['dayOfWeek'] ?? h['day'] ?? h['dayLabel'];
      if (_isoWeekdayFrom(dayRaw) != todayIso) continue;
      final start = h['breakStartTime'] ?? h['breakStart'];
      final end = h['breakEndTime'] ?? h['breakEnd'];
      if (start != null && end != null) return '$start - $end';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final place = _place;

    final address = place?.address ?? spot.address;
    final ownerIntro = (place?.overview?.trim().isNotEmpty ?? false)
        ? place!.overview!.trim()
        : spot.ownerIntro;
    final hours = (place == null ? null : _formatHours(place)) ?? spot.hours;
    // `place`가 로드되기 전엔 [gapPlaceToSpot]이 이미 채워둔 `spot.businessStatus`
    // (랭킹/지도/추천 응답의 `operatingStatus` 기반)를 먼저 보여주고, 상세
    // 조회가 끝나면 그 값(브레이크타임·휴무 포함 5단)으로 갱신한다.
    final businessStatus = (place == null
            ? null
            : businessStatusFromApi(
                operatingStatus: place.operatingStatus,
                isOpenNow: place.isOpenNow,
              )) ??
        spot.businessStatus;
    final todayBreakRange = place == null ? null : _todayBreakRange(place);
    final noFixedHours =
        place != null && _hasNoFixedHours(place.operatingHours);

    return _Card(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Symbols.eco_rounded,
            label: '카테고리',
            child: Text(
              '${spot.spotType} · ${spot.categoryName ?? spot.category.label}',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.location_on_rounded,
            label: '주소',
            stacked: true,
            trailing: _DirectionsButton(onTap: widget.onDirections),
            child: Text(address, style: AppTextStyles.bodyMedium),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.schedule_rounded,
            label: '운영시간',
            stacked: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (businessStatusChip(businessStatus) case final chip?) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      chip,
                      if (businessStatus == BusinessStatus.breakTime &&
                          todayBreakRange != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          todayBreakRange,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (noFixedHours) ...[
                  Text(
                    '장소 특성상 정해진 운영시간이 없어요',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                for (final line in hours)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(line, style: AppTextStyles.bodyMedium),
                  ),
              ],
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.person_rounded,
            label: '장소 소개',
            stacked: true,
            child: Text(
              ownerIntro,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
    this.stacked = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget child;

  /// `true`면 내용을 라벨 옆이 아니라 그 밑에 쌓는다(운영시간/장소 소개/주소
  /// 전용 — 카테고리는 기존 좌우 배치를 유지한다).
  final bool stacked;

  /// 라벨 줄 오른쪽 끝에 붙는 보조 위젯(예: 주소 옆 길찾기 버튼). [stacked]일
  /// 때만 쓰인다.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );

    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.iconInactive),
                const SizedBox(width: AppSpacing.md),
                labelText,
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.iconInactive),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: 64, child: labelText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.divider);
  }
}

/// Compact outlined button used inside detail rows and the contact section.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.smallButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primaryPressed),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryPressed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "문의 및 공식 정보" — phone number + 전화하기 / 홈페이지 보기 buttons.
///
/// [placeId] 있으면 `GET /places/{id}`의 실 `phone`/`homepage`로 덮어쓴다
/// (없으면/실패하면 목업 `spot.phone`/`spot.homepage` 유지). 둘 다 없으면
/// 섹션 자체를 그리지 않는다.
class _ContactSection extends StatefulWidget {
  const _ContactSection({
    required this.spot,
    required this.openUri,
    this.placeId,
  });

  final MockTouristSpot spot;
  final int? placeId;
  final Future<void> Function(
    BuildContext context,
    List<Uri> candidates, {
    required String failMessage,
  })
  openUri;

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  String? _livePhone;
  String? _liveHomepage;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .detail(id)
          .then((place) {
            if (mounted) {
              setState(() {
                _livePhone = place.phone;
                _liveHomepage = place.homepage;
              });
            }
          })
          .catchError((_) {
            /* 목업 값 유지 */
          });
    }
  }

  String? get _phone => _livePhone ?? widget.spot.phone;
  String? get _homepage => _liveHomepage ?? widget.spot.homepage;

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    final homepage = _homepage;
    if (phone == null && homepage == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text('문의 및 공식 정보', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phone != null) ...[
                Row(
                  children: [
                    const Icon(
                      Symbols.call_rounded,
                      size: 18,
                      color: AppColors.iconInactive,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(phone, style: AppTextStyles.bodyMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  if (phone != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.call_rounded,
                        label: '전화하기',
                        onTap: () => widget.openUri(context, [
                          Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
                        ], failMessage: '전화 앱을 여는 데 실패했어요.'),
                      ),
                    ),
                  if (phone != null && homepage != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (homepage != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.language_rounded,
                        label: '홈페이지 보기',
                        onTap: () => widget.openUri(context, [
                          Uri.parse(homepage),
                        ], failMessage: '홈페이지를 여는 데 실패했어요.'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "요즘 이곳은 이런 이야기로 들려요" — the 트렌드 요약 entry point plus the
/// most-mentioned keywords as tappable chips.
///
/// [placeId]가 있으면(실 장소) `GET /places/{id}/trends`의 실제 `keywords`만
/// 보여준다 — `spot.trendKeywords`는 목업 스팟 전용 고정 문구('숨은명소' 등)라
/// 실 장소에 그대로 노출하면 마치 진짜 방문자 언급인 것처럼 보이는 가짜
/// 데이터가 된다. 로드 전/실패/데이터 없음이면 칩 자체를 비워 둔다(목업으로
/// 대체하지 않는다) — "트렌드 요약" 버튼은 눌러 들어가면 실제 빈 상태 카드를
/// 보여주므로 여기서 거짓 미리보기를 보여줄 필요가 없다.
class _TrendSection extends StatefulWidget {
  const _TrendSection({
    required this.spot,
    this.placeId,
    required this.onOpenTrend,
    required this.onKeyword,
  });

  final MockTouristSpot spot;
  final int? placeId;
  final VoidCallback onOpenTrend;
  final ValueChanged<String> onKeyword;

  @override
  State<_TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<_TrendSection> {
  List<String>? _liveKeywords;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService()
          .trends(id)
          .then((t) {
            if (mounted) setState(() => _liveKeywords = t.keywords);
          })
          .catchError((_) {
            /* 빈 상태 유지 */
          });
    }
  }

  List<String> get _keywords => widget.placeId != null
      ? (_liveKeywords ?? const [])
      : widget.spot.trendKeywords;

  @override
  Widget build(BuildContext context) {
    final onOpenTrend = widget.onOpenTrend;
    final onKeyword = widget.onKeyword;
    final keywords = _keywords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('요즘 이곳은 이런 이야기로 들려요', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '방문자들이 가장 많이 언급한 키워드예요.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenTrend,
            icon: Image.asset(
              'assets/illustrations/icon/trend_summary.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            label: const Text('트렌드 요약'),
          ),
        ),
        if (keywords.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          // 키워드는 한 줄로 세우고, 넘치면 옆으로 스크롤.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < keywords.length; i++) ...[
                  if (i != 0) const SizedBox(width: AppSpacing.sm),
                  _KeywordChip(
                    label: keywords[i],
                    onTap: () => onKeyword(keywords[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$label',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

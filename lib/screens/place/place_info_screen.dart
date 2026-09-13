import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/favorite_star_button.dart';
import '../record/my_footprint_screen.dart';
import '../trend/trend_summary_screen.dart';
import 'visit_prepare_screen.dart';
import 'visit_unavailable_screen.dart';

/// `<장소 정보 페이지>` (user_flow §6) — one tourist spot's detail page,
/// reached by tapping a spot on `<지역별 랭킹 페이지>` (or the region map).
///
/// Shows the visit state (미방문 / 방문 인증 완료), name, 갭지수 + a short
/// plain-language reading of it, the big 방문 인증 CTA (with the obtainable
/// ingredient + store benefit beside it), a small 길찾기 button, then the
/// category / 주소 / 운영시간 / 주인의 소개 block, optional 문의처, and the
/// 트렌드 요약 keywords.
///
/// [placeId]가 있으면 (실 장소 목록에서 진입) `GET /places/{placeId}/visit-status`로
/// 방문 인증 완료 여부를 조회해 상단 pill에 반영하고, 방문 인증 흐름에도
/// 그 ID를 넘겨 실제 세션을 만든다 (스펙 §6.3, §7). 영업 여부(`isOpenNow`)와
/// 방문 인증 가능 여부(`verification.enabled`)도 `GET /places/{id}`로 실시간
/// 조회한다. placeId가 없으면(목업 스팟) 위 항목 전부 `spot`의 목업 값 사용.
///
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
/// * TODO(asset): 장소 대표 이미지 슬롯 없음 (상세 페이지 상단 사진).
class PlaceInfoScreen extends StatelessWidget {
  const PlaceInfoScreen({super.key, required this.spot, this.placeId});

  final MockTouristSpot spot;
  final int? placeId;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  /// 네이버 지도 앱(`nmap://`)으로, 실패하면 네이버 지도 웹으로 장소를 연다.
  void _openDirections(BuildContext context) {
    final name = Uri.encodeComponent(spot.name);
    final app = spot.hasLocation
        ? Uri.parse('nmap://place?lat=${spot.lat}&lng=${spot.lng}'
            '&name=$name&appname=com.goyohaeng')
        : Uri.parse('nmap://search?query=$name&appname=com.goyohaeng');
    _open(
      context,
      [app, Uri.parse('https://map.naver.com/p/search/$name')],
      failMessage: '${spot.name} 위치를 여는 데 실패했어요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = spot.phone != null || spot.homepage != null;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _VisitStatePill(state: spot.visitState, placeId: placeId),
          const SizedBox(height: AppSpacing.md),
          Text(spot.name, style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.xs),
          _CategoryLine(spot: spot),
          const SizedBox(height: AppSpacing.md),
          _DirectionsButton(onTap: () => _openDirections(context)),
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
          if (hasContact) ...[
            const SizedBox(height: AppSpacing.xl),
            _ContactSection(
              spot: spot,
              onCall: () => _open(
                context,
                [Uri(scheme: 'tel', path: spot.phone!.replaceAll(' ', ''))],
                failMessage: '전화 앱을 여는 데 실패했어요.',
              ),
              onHomepage: () => _open(
                context,
                [Uri.parse(spot.homepage!)],
                failMessage: '홈페이지를 여는 데 실패했어요.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _TrendSection(
            spot: spot,
            onOpenTrend: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrendSummaryScreen(spot: spot, placeId: placeId),
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
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1 || index == 2) {
            Navigator.of(context).maybePop();
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
        },
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
      PlaceService().visitStatus(id).then((status) {
        if (!mounted) return;
        setState(() => _state =
            status.visited ? VisitState.verified : VisitState.notVisited);
      }).catchError((_) {/* keep the passed-in value */});
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
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
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
            '${spot.categoryName ?? spot.category.label} · 갭지수 ${spot.gapIndex}',
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
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.smallButton),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.navigation_rounded,
                  size: 16,
                  color: AppColors.primaryPressed,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '길찾기',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.primaryPressed),
                ),
              ],
            ),
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
      GapService().placeGap(id).then((g) {
        if (mounted) setState(() => _gap = g);
      }).catchError((_) {/* keep the passed-in mock value */});
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
              Text(
                '이곳의 갭지수',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
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
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600, height: 1.5),
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

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id != null) {
      PlaceService().detail(id).then((place) {
        if (mounted) {
          setState(() => _liveEnabled = place.verification?.enabled);
        }
      }).catchError((_) {/* 목업 값 유지 */});
    }
  }

  bool get _verifiable => _liveEnabled ?? widget.spot.visitVerifiable;

  @override
  Widget build(BuildContext context) {
    return _VisitCtaCard(
      spot: widget.spot,
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
  const _VisitCtaCard({required this.spot, required this.onVerify});

  final MockTouristSpot spot;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    // GAP percentile → drop policy → rarity → 랜덤 재료 순으로 관리자 승인
    // 시점에 결정되므로(스펙 §8.5), 방문 전에 특정 재료 이름을 미리 보여주지
    // 않는다(`availableIngredients`는 일반 GAP 방문 보상 표현에 쓰지 않는다,
    // 스펙 15). 확률표의 모든 정책이 합 1.0이라 방문 인증 시 항상 무언가는
    // 지급된다.
    const ingredientLabel = '방문 인증 시 랜덤 재료 획득';
    final benefitLabel = spot.storeBenefit ?? '제공 혜택 없음';

    return _Card(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/branding/leaf_ornament.png',
                width: 36,
                height: 36,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.eco_rounded,
                  size: 28,
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
                      '방문 인증을 완료하면 재료와 혜택을 받을 수 있어요',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
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
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Symbols.where_to_vote_rounded,
                  size: 32,
                ),
              ),
              label: const Text('방문 인증'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: _RewardBox(
                  icon: Symbols.eco_rounded,
                  iconAsset: 'assets/illustrations/icon/ingredient_4.png',
                  label: ingredientLabel,
                  active: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RewardBox(
                  icon: Symbols.redeem_rounded,
                  iconAsset: 'assets/illustrations/icon/benefit.png',
                  label: benefitLabel,
                  active: spot.storeBenefit != null,
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

class _RewardBox extends StatelessWidget {
  const _RewardBox({
    required this.icon,
    required this.label,
    required this.active,
    this.iconAsset,
  });

  final IconData icon;

  /// Illustration asset shown instead of [icon] (takes precedence).
  final String? iconAsset;
  final String label;
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
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 카테고리 / 주소 / 운영시간 / 주인의 소개 block. [placeId]가 있으면
/// `GET /places/{id}`로 실제 소개(`overview`)·주소(`roadAddress`)·영업 여부
/// (`isOpenNow`)를 덮어쓴다. `operatingHours`는 스펙 문서에 항목 구조가 아직
/// 확정돼 있지 않아(예시가 항상 빈 배열) 알려진 필드명만 방어적으로 시도하고,
/// 알아볼 수 없으면 목업 [spot.hours]로 그대로 남긴다.
class _DetailCard extends StatefulWidget {
  const _DetailCard({
    required this.spot,
    required this.onDirections,
    this.placeId,
  });

  final MockTouristSpot spot;
  final VoidCallback onDirections;
  final int? placeId;

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
      PlaceService().detail(id).then((p) {
        if (mounted) setState(() => _place = p);
      }).catchError((_) {/* keep the mock spot values */});
    }
  }

  List<String>? _formatHours(Place place) {
    if (place.operatingHours.isEmpty) return null;
    final lines = <String>[];
    for (final h in place.operatingHours) {
      final day = h['dayOfWeek'] ?? h['day'] ?? h['dayLabel'];
      if (day == null) continue;
      final closed = h['isClosed'] == true || h['closed'] == true;
      final open = h['openTime'] ?? h['open'];
      final close = h['closeTime'] ?? h['close'];
      lines.add(
        closed || open == null || close == null
            ? '$day 휴무'
            : '$day $open - $close',
      );
    }
    return lines.isEmpty ? null : lines;
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
    final isOpenNow = place?.isOpenNow;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(address, style: AppTextStyles.bodyMedium),
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniButton(
                  icon: Symbols.navigation_rounded,
                  label: '길찾기',
                  onTap: widget.onDirections,
                ),
              ],
            ),
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Symbols.schedule_rounded,
            label: '운영시간',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOpenNow != null) ...[
                  _BusinessStatusChip(isOpenNow: isOpenNow),
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
            label: '주인의 소개',
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

/// "영업 중" / "영업 종료" — small status chip driven by the live `isOpenNow`.
class _BusinessStatusChip extends StatelessWidget {
  const _BusinessStatusChip({required this.isOpenNow});

  final bool isOpenNow;

  @override
  Widget build(BuildContext context) {
    final color = isOpenNow ? AppColors.success : AppColors.error;
    final bg = isOpenNow ? AppColors.successBackground : AppColors.errorBackground;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        isOpenNow ? '영업 중' : '영업 종료',
        style: AppTextStyles.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.iconInactive),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.spot,
    required this.onCall,
    required this.onHomepage,
  });

  final MockTouristSpot spot;
  final VoidCallback onCall;
  final VoidCallback onHomepage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문의 및 공식 정보', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (spot.phone != null) ...[
                Row(
                  children: [
                    const Icon(
                      Symbols.call_rounded,
                      size: 18,
                      color: AppColors.iconInactive,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(spot.phone!, style: AppTextStyles.bodyMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  if (spot.phone != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.call_rounded,
                        label: '전화하기',
                        onTap: onCall,
                      ),
                    ),
                  if (spot.phone != null && spot.homepage != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (spot.homepage != null)
                    Expanded(
                      child: _MiniButton(
                        icon: Symbols.language_rounded,
                        label: '홈페이지 보기',
                        onTap: onHomepage,
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
class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.spot,
    required this.onOpenTrend,
    required this.onKeyword,
  });

  final MockTouristSpot spot;
  final VoidCallback onOpenTrend;
  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('요즘 이곳은 이런 이야기로 들려요', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '방문자들이 가장 많이 언급한 키워드예요.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: AppColors.surfaceSelected,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
            onTap: onOpenTrend,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.chat_rounded,
                    size: 18,
                    color: AppColors.primaryPressed,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '트렌드 요약',
                    style: AppTextStyles.buttonMedium
                        .copyWith(color: AppColors.primaryPressed),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 키워드는 한 줄로 세우고, 넘치면 옆으로 스크롤.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < spot.trendKeywords.length; i++) ...[
                if (i != 0) const SizedBox(width: AppSpacing.sm),
                _KeywordChip(
                  label: spot.trendKeywords[i],
                  onTap: () => onKeyword(spot.trendKeywords[i]),
                ),
              ],
            ],
          ),
        ),
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

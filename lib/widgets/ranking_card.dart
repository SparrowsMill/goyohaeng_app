import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../api/api.dart' show Category;
import '../data/mock_map_regions.dart' show gapIndexAccent;
import '../data/mock_region_ranking.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'favorite_star_button.dart';
import 'gap_index_info_dialog.dart';

/// Category + sort dropdowns (side by side) + 방문 인증 필터 칩 + hint line,
/// pinned above a scrolling GAP 랭킹 list. Shared by
/// `<지역별 랭킹>`(`RegionRankingScreen`) and `<전체 랭킹>`(`RankingScreen`) so
/// both look identical.
class RankingFilterBar extends StatelessWidget {
  const RankingFilterBar({
    super.key,
    required this.category,
    required this.categories,
    required this.onCategory,
    required this.descending,
    required this.onSort,
    required this.visitVerifiableOnly,
    required this.onVisitVerifiableOnly,
    required this.hint,
  });

  /// 선택된 카테고리 id, `null` == 전체.
  final int? category;

  /// `GET /categories` level 1.
  final List<Category> categories;
  final ValueChanged<int?> onCategory;
  final bool descending;
  final ValueChanged<bool> onSort;

  /// "방문 인증 가능만" 필터 — 켜면 `visitVerifiable == true`인 스팟만 남긴다.
  final bool visitVerifiableOnly;
  final ValueChanged<bool> onVisitVerifiableOnly;

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PillDropdown<int?>(
                  value: category,
                  onChanged: onCategory,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PillDropdown<bool>(
                  value: descending,
                  onChanged: (v) => onSort(v ?? true),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('고요 지수 높은순')),
                    DropdownMenuItem(value: false, child: Text('고요 지수 낮은순')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const GapIndexInfoButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          VisitVerifiableFilterChip(
            active: visitVerifiableOnly,
            onTap: () => onVisitVerifiableOnly(!visitVerifiableOnly),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// "방문 인증 가능만" — Filter/Keyword Tag styled toggle (CLAUDE.md §7). Shared by
/// [RankingFilterBar] and `RankingScreen`'s own filter bottom sheet.
class VisitVerifiableFilterChip extends StatelessWidget {
  const VisitVerifiableFilterChip({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: active ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.verified_rounded,
                size: 16,
                fill: active ? 1 : 0,
                color: active
                    ? AppColors.textOnPrimaryButton
                    : AppColors.primaryPressed,
              ),
              const SizedBox(width: 4),
              Text(
                '방문 인증 가능만',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.textOnPrimaryButton
                      : AppColors.primaryPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact pill-styled dropdown used by [RankingFilterBar] and any other
/// region/카테고리 picker that wants the same look.
class PillDropdown<T> extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;

  /// `null` disables the dropdown (e.g. 시군구 before a 시도 is picked).
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          // `value` can transiently (or permanently, if a persisted id no
          // longer exists) fail to match any `items` entry — e.g. a
          // SharedPreferences-restored category id loading before the
          // category list itself. `DropdownButton` asserts on that, so fall
          // back to null rather than crash.
          value: items.any((item) => item.value == value) ? value : null,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.secondaryButton),
          icon: const Icon(Symbols.keyboard_arrow_down_rounded, size: 18),
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          dropdownColor: AppColors.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// One ranked GAP 스팟 row — rank badge, name, 즐겨찾기 별, 갭지수, category/
/// ingredient/방문·영업 tags, and (when [selected]) a "자세히 보기" button.
/// Shared by `<지역별 랭킹>` and `<전체 랭킹>`.
class RankingCard extends StatelessWidget {
  const RankingCard({
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
    // The spot's map-pin colour (갭지수 scale) — used for the row's pin, the
    // emphasised 갭지수 text, and (when selected) the border / 자세히 보기 button.
    final accent = gapIndexAccent(spot.gapIndex);
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? AppColors.textOnPrimaryButton
            : AppColors.textPrimary;

    return Material(
      color: selected
          ? Color.alphaBlend(accent.withValues(alpha: 0.09), AppColors.surface)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? accent : AppColors.border,
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
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: FavoriteStarButton(
                      spotName: spot.name,
                      size: 20,
                      placeId: spot.placeId,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _GapValue(gapIndex: spot.gapIndex, accent: accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Category · ingredient · visit-verify · business status, all
              // on one line; scrolls sideways rather than wrapping.
              Padding(
                padding: const EdgeInsets.only(left: 26 + AppSpacing.sm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: [
                      _Tag(label: spot.categoryName ?? spot.category.label),
                      const SizedBox(width: AppSpacing.xs),
                      StatusChip(
                        label: switch (spot.visitVerifiable) {
                          true => '방문 인증 가능',
                          false => '방문 인증 불가',
                          null => '방문 인증 알 수 없음',
                        },
                        tone: spot.visitVerifiable == true
                            ? ChipTone.positive
                            : ChipTone.muted,
                      ),
                      if (businessStatusChip(spot.businessStatus)
                          case final chip?) ...[
                        const SizedBox(width: AppSpacing.xs),
                        chip,
                      ],
                    ],
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.xs),
                _DetailButton(
                  onTap: onDetail,
                  color: accent,
                  foreground: onAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "자세히 보기" — appears on the selected ranking card, opens `<장소 정보>`.
/// Filled with the spot's map-pin colour so the card reads as "this pin".
class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.onTap,
    required this.color,
    required this.foreground,
  });

  final VoidCallback onTap;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Symbols.arrow_forward_rounded, size: 18, color: foreground),
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
    1: 'assets/illustrations/ranking/first.png',
    2: 'assets/illustrations/ranking/second.png',
    3: 'assets/illustrations/ranking/third.png',
  };

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return SizedBox(
        width: 26,
        child: Center(
          child: Text(
            '$rank',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final color = _medalColors[rank]!;
    return Image.asset(
      _medalAsset[rank]!,
      width: 26,
      height: 26,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 26,
        height: 26,
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

/// The 갭지수, emphasised with the scale colour: a filled pin + a bold coloured
/// number, shown at the card's top-right.
class _GapValue extends StatelessWidget {
  const _GapValue({required this.gapIndex, required this.accent});

  final int gapIndex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.location_on_rounded, size: 18, fill: 1, color: accent),
        const SizedBox(width: 2),
        Text(
          '고요 지수 $gapIndex',
          style: AppTextStyles.bodyMedium.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 상태 칩의 색조 — [StatusChip]/`RankingCard`뿐 아니라 즐겨찾기·검색·장소
/// 정보 목록의 같은 칩에도 공유되는 공개 타입.
enum ChipTone { positive, muted, negative, warning }

/// "영업 중"/"영업 전"/"브레이크타임"/"영업 종료"/"휴무일" — [BusinessStatus]
/// 값 하나로 목록 카드(랭킹·즐겨찾기·검색)와 `<장소 정보>` 상세 카드에 공용으로
/// 쓸 [StatusChip]을 만든다. `status`가 `null`(운영 정보 부족으로 실제 영업
/// 여부를 확보하지 못함, 서버 `operatingStatus: 'UNKNOWN'` 포함)이면 애매한
/// "알 수 없음" 칩 대신 아예 `null`을 돌려줘 호출부가 그 자리를 통째로
/// 생략하게 한다 — 실제로 확인된 곳만 카드로 보여준다.
///
/// 2026-09-16 백엔드가 목록(`GET /places/gap/rankings`·`/gap/map`·
/// `/{id}/recommendations`)과 상세(`GET /places/{id}`) 응답 모두에
/// `operatingStatus`(`OPEN`/`BEFORE_OPEN`/`BREAK_TIME`/`CLOSED`/`DAY_OFF`/
/// `UNKNOWN`)를 추가하기 전까지는 목록의 `isOpenNow`가 불(bool)|null 2단뿐이라
/// `휴무일`이 뜨지 않았다 — 지금은 [businessStatusFromApi]가 있으면
/// `operatingStatus`를 우선 쓰므로 목록에서도 5단이 모두 나온다.
Widget? businessStatusChip(BusinessStatus? status) => status == null
    ? null
    : StatusChip(
        label: status.label,
        tone: switch (status) {
          BusinessStatus.open => ChipTone.positive,
          BusinessStatus.beforeOpen => ChipTone.warning,
          BusinessStatus.breakTime => ChipTone.warning,
          BusinessStatus.closed => ChipTone.negative,
          BusinessStatus.holiday => ChipTone.negative,
        },
      );

/// "방문 인증 가능" / "영업 중" 같은 상태 칩. 칩 스타일을 한 곳에서만
/// 관리하려고 `ranking_card.dart` 밖에서도 쓴다([FavoritesList]의
/// `_FavoriteRow`, `PlaceSearchScreen`의 `_ResultTile`, `<장소 정보>`의
/// 영업 상태 칩).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.positive => (AppColors.successBackground, AppColors.success),
      ChipTone.muted => (AppColors.surfaceDisabled, AppColors.textSecondary),
      ChipTone.negative => (AppColors.errorBackground, AppColors.error),
      ChipTone.warning => (AppColors.warningBackground, AppColors.warning),
    };
    return Container(
      height: 20,
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

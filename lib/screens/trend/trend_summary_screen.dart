import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../api/api.dart';
import '../../data/mock_region_ranking.dart';
import '../../data/mock_trend_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../record/my_footprint_screen.dart';

/// `<트렌드요약 페이지>` (user_flow §6) — reached from the "트렌드 요약" button
/// (or a keyword chip) on `<장소 정보 페이지>`. Shows the rising keywords, the
/// AI-summarised interest points, and the outside posts / search-trend
/// keywords / SNS search links the summary was built from. A place's first
/// open grants one basic ingredient (쌀알).
///
/// [placeId]가 있으면 `GET /places/{id}/trends`로 실제 키워드/AI 요약을 덮어쓰고,
/// 로그인 상태면 `POST /places/{id}/trends/first-view`로 최초 확인 보상을 청구해
/// 실제로 지급됐을 때만(스펙 §6.5) 스낵바로 알린다. `placeId`가 없으면(목업 스팟)
/// 항상 "처음 확인" 상태로 보여주는 기존 목업 동작을 그대로 유지한다.
///
/// * TODO: 원문 보기 / SNS 검색 / 더 찾아보기 — 외부 브라우저·앱 연동
/// * `contents`(외부 게시글)·`searchTerm`은 실 데이터가 있으면 사용하고, 없으면
///   (파이프라인 미가동 등) 스팟 목업으로 대체한다(백엔드 실측 2026-09-13,
///   `docs/backend_requirements_pending.md` §5-1).
/// * TODO(backend): `searchInterest`(검색어 트렌드 구간 값)는 항목 필드 구조가
///   아직 문서화되지 않아 화면에 반영하지 않는다 — "함께 검색하는 키워드"/SNS
///   섹션은 당분간 스팟 목업 데이터를 계속 사용한다.
/// * TODO(asset): 이 화면 배경 scenes/{name}.png 미납품 — 지금은 평면 #FAE7C0.
class TrendSummaryScreen extends StatefulWidget {
  const TrendSummaryScreen({
    super.key,
    required this.spot,
    this.focusKeyword,
    this.placeId,
  });

  final MockTouristSpot spot;

  /// 키워드 칩으로 진입한 경우 강조할 키워드.
  final String? focusKeyword;

  /// 실 장소 ID가 있으면 실제 트렌드/최초 확인 보상 API를 사용한다.
  final int? placeId;

  @override
  State<TrendSummaryScreen> createState() => _TrendSummaryScreenState();
}

class _TrendSummaryScreenState extends State<TrendSummaryScreen> {
  late final MockTrendSummary _mockSummary = trendSummaryForSpot(widget.spot);

  /// 실 API 응답. `null`이면 목업 경로이거나, 아직 응답 전이거나, 조회에
  /// 실패한 것 — 어느 쪽이든 위 목업 값으로 조용히 대체한다.
  PlaceTrends? _trends;

  @override
  void initState() {
    super.initState();
    final id = widget.placeId;
    if (id == null) return;

    PlaceService().trends(id).then((t) {
      if (mounted) setState(() => _trends = t);
    }).catchError((_) {/* keep the mock fallback */});

    if (AuthStore.instance.isSignedIn) {
      // 최초 1회만 실지급되므로(스펙 §6.5) 여기서 한 번만 호출한다.
      PlaceService().claimTrendFirstView(id).then((result) {
        if (!mounted || !result.rewarded) return;
        final name = result.ingredientName ?? '재료';
        final qty = result.ingredientQuantity ?? 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('트렌드 요약을 처음 확인했어요! 기본 재료 · $name $qty개 획득')),
        );
      }).catchError((_) {/* best-effort — 지급 실패해도 화면은 그대로 */});
    }
  }

  void _todo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<TrendInsight> _insightsFor(PlaceTrends t) {
    final text = t.summaryText?.trim();
    if (text != null && text.isNotEmpty) {
      return [TrendInsight(icon: Symbols.auto_awesome_rounded, text: text)];
    }
    return [
      TrendInsight(
        icon: Symbols.pin_drop_rounded,
        text: t.keywords.isNotEmpty
            ? '#${t.keywords.first} 키워드가 최근 자주 언급되고 있어요.'
            : '트렌드 데이터를 모으고 있어요.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final trends = _trends;
    final hasRealData = trends != null && trends.hasData;
    final showEmptyState = trends != null && !trends.hasData;

    final keywords = hasRealData ? trends.keywords : _mockSummary.risingKeywords;
    final highlight = widget.focusKeyword ??
        (keywords.isNotEmpty ? keywords.first : null);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('트렌드 요약'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _TitleBlock(spot: spot),
          const SizedBox(height: AppSpacing.lg),
          // 실 장소는 최초 확인 보상 여부를 서버 응답이 오기 전까지 알 수 없으니
          // 항상-첫확인으로 가정하는 카드를 보여주지 않는다 — 대신 initState의
          // 스낵바로만(rewarded == true일 때) 알린다. 목업 스팟은 기존 그대로.
          if (widget.placeId == null) ...[
            _RewardCard(ingredient: _mockSummary.rewardIngredient),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (showEmptyState)
            const _TrendEmptyCard()
          else ...[
            _RisingKeywordsCard(
              keywords: keywords,
              highlight: highlight,
              onKeyword: (keyword) =>
                  _todo(context, '#$keyword 관련 글은 준비 중이에요.'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _InsightCard(
              insights: hasRealData ? _insightsFor(trends) : _mockSummary.insights,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _PostsSection(
            summary: _mockSummary,
            realContents: hasRealData ? trends.contents : const [],
            realSearchQuery: hasRealData ? trends.searchTerm : null,
            onOpenPost: (title) =>
                _todo(context, '"$title" 원문은 브라우저 연동 후 열 수 있어요.'),
            onSearchMore: () =>
                _todo(context, '네이버 블로그 검색은 브라우저 연동 후 이용할 수 있어요.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _RelatedQueriesSection(
            queries: _mockSummary.relatedQueries,
            onQuery: (query) => _todo(context, '#$query 검색은 준비 중이에요.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SnsSection(
            onSearch: (platform) =>
                _todo(context, '$platform 검색은 앱 연동 후 이용할 수 있어요.'),
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

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.spot});

  final MockTouristSpot spot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.name, style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '사람들은 이곳을 이렇게 이야기하고 있어요',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Image.asset(
          'assets/branding/leaf_ornament_3.png',
          width: 76,
          height: 76,
          errorBuilder: (context, error, stackTrace) => const SizedBox(width: 76),
        ),
      ],
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

/// "아직 트렌드 데이터가 없어요" — shown instead of the keyword/insight cards
/// when a real place's `PlaceTrends.hasData` comes back false (스펙 §6.4).
class _TrendEmptyCard extends StatelessWidget {
  const _TrendEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.auto_awesome_rounded,
            size: 20,
            color: AppColors.iconInactive,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('아직 트렌드 데이터가 없어요', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '이곳을 이야기하는 글이 더 모이면 트렌드 요약이 채워질 거예요.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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

/// "트렌드 요약을 처음 확인했어요!" — the first-open basic-ingredient reward.
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.ingredient});

  final String ingredient;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // * TODO(asset): ingredient_rice.png 미납품 — 지금은 아이콘 폴백.
          Image.asset(
            'assets/illustrations/rewards/ingredient_rice_one.png',
            width: 52,
            height: 52,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Symbols.grass_rounded,
              size: 36,
              color: AppColors.secondaryAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '트렌드 요약을 처음 확인했어요!',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '기본 재료 · $ingredient 1개 획득',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('장소별 최초 1회만 지급돼요', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.check_rounded,
              size: 22,
              color: AppColors.textOnPrimaryButton,
            ),
          ),
        ],
      ),
    );
  }
}

/// "지금 뜨는 키워드" — first (or focused) keyword shown filled.
class _RisingKeywordsCard extends StatelessWidget {
  const _RisingKeywordsCard({
    required this.keywords,
    required this.highlight,
    required this.onKeyword,
  });

  final List<String> keywords;
  final String? highlight;
  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('지금 뜨는 키워드', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          // 한 줄로 세우고, 넘치면 옆으로 스크롤.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < keywords.length; i++) ...[
                  if (i != 0) const SizedBox(width: AppSpacing.sm),
                  _KeywordChip(
                    label: keywords[i],
                    selected: keywords[i] == highlight,
                    onTap: () => onKeyword(keywords[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

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
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '#$label',
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

/// "AI가 정리한 관심 포인트" — bulleted insight lines with an "AI 요약" badge.
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insights});

  final List<TrendInsight> insights;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('AI가 정리한 관심 포인트', style: AppTextStyles.title),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSelected,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'AI 요약',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPressed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < insights.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(insights[i].icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    insights[i].text,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `contentType` → 플랫폼 표시 라벨.
String _contentTypeLabel(String? contentType) => switch (contentType) {
      'BLOG' => '네이버 블로그',
      'NEWS' => '뉴스',
      'CAFE' => '네이버 카페',
      null => '외부 게시글',
      _ => contentType,
    };

/// "이런 글에서 이야기하고 있어요" — the outside posts + a "더 찾아보기" row.
/// [realContents]가 있으면 실 API(`PlaceTrends.contents`) 데이터를, 없으면
/// (파이프라인 미가동 등) [summary]의 목업 게시글을 보여준다.
class _PostsSection extends StatelessWidget {
  const _PostsSection({
    required this.summary,
    required this.realContents,
    required this.realSearchQuery,
    required this.onOpenPost,
    required this.onSearchMore,
  });

  final MockTrendSummary summary;
  final List<PlaceExternalContent> realContents;
  final String? realSearchQuery;
  final ValueChanged<String> onOpenPost;
  final VoidCallback onSearchMore;

  @override
  Widget build(BuildContext context) {
    final useReal = realContents.isNotEmpty;
    final query = realSearchQuery?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이런 글에서 이야기하고 있어요', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '트렌드 요약에 활용된 외부 게시글이에요.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (useReal)
          for (final content in realContents) ...[
            _RealPostCard(
              content: content,
              onOpen: () => onOpenPost(content.title ?? '게시글'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ]
        else
          for (final post in summary.posts) ...[
            _PostCard(post: post, onOpen: () => onOpenPost(post.title)),
            const SizedBox(height: AppSpacing.sm),
          ],
        _SearchMoreCard(
          query: query != null && query.isNotEmpty
              ? query
              : summary.naverSearchQuery,
          onTap: onSearchMore,
        ),
      ],
    );
  }
}

/// [_PostCard]와 같은 모습으로, 실 API `PlaceExternalContent`를 보여준다.
class _RealPostCard extends StatelessWidget {
  const _RealPostCard({required this.content, required this.onOpen});

  final PlaceExternalContent content;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceSelected,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Symbols.eco_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _contentTypeLabel(content.contentType),
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (content.author != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text('· ${content.author}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      content.title ?? '제목 없는 게시글',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniButton(
                    icon: Symbols.open_in_new_rounded,
                    label: '원문 보기',
                    onTap: onOpen,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('외부 사이트로 이동', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onOpen});

  final TrendPost post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceSelected,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Symbols.eco_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          post.platform,
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      post.title,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.snippet,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniButton(
                    icon: Symbols.open_in_new_rounded,
                    label: '원문 보기',
                    onTap: onOpen,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('외부 사이트로 이동', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TagChip(label: post.keyword),
        ],
      ),
    );
  }
}

class _SearchMoreCard extends StatelessWidget {
  const _SearchMoreCard({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              const Icon(
                Symbols.search_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '네이버 블로그에서 더 찾아보기',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(query, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Symbols.open_in_new_rounded,
                size: 18,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "함께 검색하는 키워드" — search-trend based related queries.
class _RelatedQueriesSection extends StatelessWidget {
  const _RelatedQueriesSection({required this.queries, required this.onQuery});

  final List<String> queries;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('함께 검색하는 키워드', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        // 한 줄로 세우고, 넘치면 옆으로 스크롤.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < queries.length; i++) ...[
                if (i != 0) const SizedBox(width: AppSpacing.sm),
                _OutlineChip(
                  label: '#${queries[i]}',
                  onTap: () => onQuery(queries[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "다른 곳에서도 찾아보기" — Instagram / YouTube / TikTok search links.
class _SnsSection extends StatelessWidget {
  const _SnsSection({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    const platforms = <({String name, IconData icon})>[
      (name: 'Instagram', icon: Symbols.photo_camera_rounded),
      (name: 'YouTube', icon: Symbols.smart_display_rounded),
      (name: 'TikTok', icon: Symbols.music_note_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('다른 곳에서도 찾아보기', style: AppTextStyles.title),
            const SizedBox(width: AppSpacing.sm),
            Text('외부 플랫폼으로 이동해요', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (var i = 0; i < platforms.length; i++) ...[
              if (i != 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SnsButton(
                  icon: platforms[i].icon,
                  label: '${platforms[i].name}에서 검색',
                  onTap: () => onSearch(platforms[i].name),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SnsButton extends StatelessWidget {
  const _SnsButton({
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
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primaryPressed),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPressed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Symbols.open_in_new_rounded,
                size: 12,
                color: AppColors.iconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact outlined button (원문 보기).
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
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryPressed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(icon, size: 13, color: AppColors.primaryPressed),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled-cream keyword tag shown on a post card.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$label',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primaryPressed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Outlined tappable chip (함께 검색하는 키워드).
class _OutlineChip extends StatelessWidget {
  const _OutlineChip({required this.label, required this.onTap});

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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
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

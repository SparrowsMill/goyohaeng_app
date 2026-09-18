/// Placeholder data for `<트렌드요약 페이지>` (user_flow §6) — the outside
/// posts, search-trend keywords, and SNS search links that the place page's
/// "트렌드 요약" is built from. Reward: a place's first-ever open grants one
/// basic ingredient (쌀알).
///
/// * TODO(backend): 트렌드 요약 근거 데이터 API 연동 (네이버 블로그/검색어
///   트렌드/SNS 검색 링크), 최초 확인 재료 지급 처리
library;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'mock_region_ranking.dart';

/// One AI-summarised interest point ("AI가 정리한 관심 포인트").
class TrendInsight {
  const TrendInsight({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// One outside post the summary drew on ("이런 글에서 이야기하고 있어요").
class TrendPost {
  const TrendPost({
    required this.platform,
    required this.title,
    required this.snippet,
    required this.keyword,
    this.url,
  });

  final String platform;
  final String title;
  final String snippet;
  final String keyword;

  /// 원문 URL — `null`이면 링크만 자리표시.
  final String? url;
}

class MockTrendSummary {
  const MockTrendSummary({
    required this.risingKeywords,
    required this.insights,
    required this.posts,
    required this.relatedQueries,
    required this.naverSearchQuery,
  });

  /// "지금 뜨는 키워드" — 첫 항목이 대표 키워드로 강조된다.
  final List<String> risingKeywords;

  final List<TrendInsight> insights;

  final List<TrendPost> posts;

  /// "함께 검색하는 키워드" — 검색어 트렌드 기반.
  final List<String> relatedQueries;

  /// 네이버 블로그 / SNS "더 찾아보기"에 쓰이는 검색어.
  final String naverSearchQuery;

  /// 최초 1회 확인 시 지급되는 기본 재료 (user_flow §6).
  String get rewardIngredient => '쌀알';
}

const _bespoke = <String, MockTrendSummary>{
  '담양 죽녹원': MockTrendSummary(
    risingKeywords: ['대나무숲', '산책', '사진명소', '힐링여행', '고요한분위기'],
    insights: [
      TrendInsight(
        icon: Symbols.forest_rounded,
        text: '울창한 대나무길에서 조용히 산책하기 좋아요.',
      ),
      TrendInsight(
        icon: Symbols.photo_camera_rounded,
        text: '초록빛 풍경과 사진 명소가 자주 언급돼요.',
      ),
      TrendInsight(
        icon: Symbols.self_improvement_rounded,
        text: '한적한 평일 방문을 추천하는 이야기가 많아요.',
      ),
    ],
    posts: [
      TrendPost(
        platform: '네이버 블로그',
        title: '담양 죽녹원, 초록빛 산책 기록',
        snippet: '대나무길을 천천히 걷는 시간이 인상적이었다는 이야기예요.',
        keyword: '대나무숲',
      ),
      TrendPost(
        platform: '네이버 블로그',
        title: '한적하게 즐긴 담양 여행',
        snippet: '평일에는 비교적 여유롭게 들러보기 좋았다는 후기예요.',
        keyword: '산책',
      ),
      TrendPost(
        platform: '네이버 블로그',
        title: '사진으로 남긴 죽녹원의 풍경',
        snippet: '푸른 대나무와 빛이 어우러진 풍경이 많이 언급돼요.',
        keyword: '사진명소',
      ),
    ],
    relatedQueries: ['담양여행', '전남가볼만한곳', '대나무길', '담양카페', '당일치기여행'],
    naverSearchQuery: '담양 죽녹원 대나무숲',
  ),
};

/// Falls back to a summary synthesised from the spot's own trend keywords so
/// every place opens with something.
MockTrendSummary trendSummaryForSpot(MockTouristSpot spot) {
  final bespoke = _bespoke[spot.name];
  if (bespoke != null) return bespoke;

  final keywords = spot.trendKeywords;
  final primary = keywords.isNotEmpty ? keywords.first : '숨은명소';

  return MockTrendSummary(
    risingKeywords: keywords,
    insights: [
      TrendInsight(
        icon: Symbols.pin_drop_rounded,
        text: '$primary 관련 이야기가 가장 많이 언급돼요.',
      ),
      TrendInsight(
        icon: Symbols.photo_camera_rounded,
        text: '방문 후기와 사진이 꾸준히 올라오는 곳이에요.',
      ),
      TrendInsight(
        icon: Symbols.self_improvement_rounded,
        text: spot.gapIndex >= 60
            ? '아직 붐비지 않아 여유롭게 다녀왔다는 이야기가 많아요.'
            : '주말에는 다소 붐빈다는 후기가 있어요.',
      ),
    ],
    posts: [
      for (final keyword in keywords.take(3))
        TrendPost(
          platform: '네이버 블로그',
          title: '${spot.name}, $keyword 후기',
          snippet: '$keyword 키워드로 이곳을 이야기하는 글이 자주 보여요.',
          keyword: keyword,
        ),
    ],
    relatedQueries: [
      '${spot.name.split(' ').first}여행',
      ...keywords.take(3),
      '가볼만한곳',
    ],
    naverSearchQuery: '${spot.name} $primary',
  );
}

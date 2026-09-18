/// 참새(프로필) 화면 데이터 로드 실패/전 fallback — user_flow §3. 참새 캐릭터
/// 이름·레벨, 함께한 날수, 활동 요약(방문 장소/방문 인증/완성 음식/모은 재료),
/// 최근 일기.
///
/// * TODO(backend): 참새 프로필 조회 API 연동 (닉네임·레벨·경험치·함께한 날수).
/// * TODO(backend): 활동 요약(누적) 조회 — 방문 장소 수 / 방문 인증 횟수 /
///   완성한 음식 수 / 모은 재료 수. `mock_user` 의 이번 달 수치와는 별개(누적).
/// * TODO(backend): 최근 기록(일기) 1건 조회 — `<기록 플랫폼>` (§8) 연동 시.
class SparrowProfile {
  const SparrowProfile({
    required this.name,
    required this.level,
    required this.xp,
    required this.xpForNextLevel,
    required this.daysTogether,
    required this.visitedPlaceCount,
    required this.verifiedStampCount,
    required this.completedFoodCount,
    required this.collectedIngredientCount,
    required this.latestDiary,
  });

  final String name;
  final int level;
  final int xp;
  final int xpForNextLevel;
  final int daysTogether;

  final int visitedPlaceCount;
  final int verifiedStampCount;
  final int completedFoodCount;
  final int collectedIngredientCount;

  /// "발자국 남기기" 카드에 미리보기로 보여줄 최근 일기 본문.
  final String latestDiary;

  double get xpProgress =>
      xpForNextLevel == 0 ? 0 : (xp / xpForNextLevel).clamp(0, 1);
}

/// Fallback shown only while the real `/users/me/sparrow` (and dashboard
/// count) data hasn't loaded yet or failed to load — every stat defaults to
/// its neutral zero value rather than a demo number, so a not-yet-loaded
/// state can never be mistaken for real progress. Only [name] keeps a
/// non-empty placeholder, since it's a display label (shown before the
/// user's real account name loads), not a stat.
const mockSparrowProfile = SparrowProfile(
  name: '고요참새',
  level: 0,
  xp: 0,
  xpForNextLevel: 0,
  daysTogether: 0,
  visitedPlaceCount: 0,
  verifiedStampCount: 0,
  completedFoodCount: 0,
  collectedIngredientCount: 0,
  latestDiary: '',
);

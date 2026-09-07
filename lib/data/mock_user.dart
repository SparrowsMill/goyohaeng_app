/// Placeholder signed-in user until a real backend/auth layer exists.
/// Screens read from this instead of hardcoding values so the same mock
/// identity shows up consistently across the app.
///
/// * TODO(backend): 로그인 세션 기반 내 프로필 조회 API 연동
///   (이름·아이디·생년월일·성별·SNS 정보).
/// * TODO(backend): 활동 요약 API 연동 — 이번 달 방문 수 / 모은 재료 수 /
///   방문 인증 완료 횟수 (방앗간 홈 스탯바 · 참새 프로필).
class MockUserProfile {
  const MockUserProfile({
    required this.name,
    required this.id,
    required this.birthDate,
    required this.gender,
    required this.monthlyVisitCount,
    required this.collectedIngredientCount,
    required this.verifiedStampCount,
  });

  final String name;
  final String id;
  final DateTime birthDate;
  final String gender;
  final int monthlyVisitCount;
  final int collectedIngredientCount;
  final int verifiedStampCount;
}

final mockUserProfile = MockUserProfile(
  name: '예린님',
  id: 'yerin.travel',
  birthDate: DateTime(1995, 5, 20),
  gender: 'female',
  monthlyVisitCount: 4,
  collectedIngredientCount: 7,
  verifiedStampCount: 12,
);

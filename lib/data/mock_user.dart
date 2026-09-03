/// Placeholder signed-in user until a real backend/auth layer exists.
/// Screens read from this instead of hardcoding values so the same mock
/// identity shows up consistently across the app.
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

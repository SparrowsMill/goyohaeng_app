import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/screens/place/place_info_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_prepare_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_unavailable_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_verification_screen.dart';
import 'package:goyohaeng_app/screens/trend/trend_summary_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';

void main() {
  final spot = rankingForRegion('jeolla').first;
  final unavailable =
      rankingForRegion('jeolla').firstWhere((s) => !s.visitVerifiable);

  testWidgets('PlaceInfoScreen builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: PlaceInfoScreen(spot: spot)),
    );
    await tester.pumpAndSettle();
    expect(find.text(spot.name), findsWidgets);
  });

  testWidgets('TrendSummaryScreen builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: TrendSummaryScreen(spot: spot)),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('VisitUnavailableScreen builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: VisitUnavailableScreen(spot: unavailable),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('VisitPrepareScreen builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: VisitPrepareScreen(spot: spot)),
    );
    await tester.pumpAndSettle();
    expect(find.text('방문을 준비하면 아래 혜택을 받을 수 있어요'), findsOneWidget);
  });

  testWidgets('VisitVerificationScreen builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: VisitVerificationScreen(spot: spot),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  });
}

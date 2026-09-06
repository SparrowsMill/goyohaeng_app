import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_visits.dart';
import 'package:goyohaeng_app/screens/map/map_screen.dart';
import 'package:goyohaeng_app/screens/mill/mill_home_screen.dart';
import 'package:goyohaeng_app/screens/place/place_info_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:goyohaeng_app/widgets/mini_korea_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => KoreaGeo.load());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MillHomeScreen()),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  testWidgets('mill home shows the mini map card (map + 지도 열기 + 다녀온 목록)',
      (tester) async {
    await pumpHome(tester);

    expect(find.byType(MiniKoreaMap), findsOneWidget);
    expect(find.text('지도 열기'), findsOneWidget);
    expect(
      find.text('다녀온 관광 스팟 ${mockVisitedSpots.length}곳'),
      findsOneWidget,
    );
    // A visited row is listed.
    expect(find.text(mockVisitedSpots.first.name), findsOneWidget);
  });

  testWidgets('tapping the mini map opens <지도>', (tester) async {
    await pumpHome(tester);

    // The InkWell sits over the map fill in the card's Stack.
    await tester.tap(find.byType(MiniKoreaMap), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('tapping a 다녀온 곳 row opens <장소 정보>', (tester) async {
    await pumpHome(tester);

    await tester.ensureVisible(find.text(mockVisitedSpots.first.name));
    await tester.tap(find.text(mockVisitedSpots.first.name));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceInfoScreen), findsOneWidget);
  });
}

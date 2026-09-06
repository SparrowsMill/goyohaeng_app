import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_visits.dart';
import 'package:goyohaeng_app/screens/map/map_screen.dart';
import 'package:goyohaeng_app/screens/mill/mill_home_screen.dart';
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

  test('topVisitedRegions is the 3 도 with the most visited spots', () {
    final top = topVisitedRegions;
    expect(top, hasLength(3));
    expect(top[0].visited, greaterThanOrEqualTo(top[1].visited));
    expect(top[1].visited, greaterThanOrEqualTo(top[2].visited));
  });

  testWidgets('mill home: mini map + 방문 TOP 3 panel + 지도 열기', (tester) async {
    await pumpHome(tester);

    expect(find.byType(MiniKoreaMap), findsOneWidget);
    expect(find.text('방문 많은 지역 TOP 3'), findsOneWidget);
    expect(find.text('지도 열기'), findsOneWidget);

    final top = topVisitedRegions;
    expect(find.text(top.first.name), findsOneWidget);
    expect(
      find.text('${top.first.visited}/${top.first.total}'),
      findsOneWidget,
    );
  });

  testWidgets('tapping 지도 열기 opens <지도>', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('지도 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  });
}

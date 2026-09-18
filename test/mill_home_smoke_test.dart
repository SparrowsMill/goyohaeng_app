import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
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

  testWidgets('mill home: mini map + 방문 TOP 3 panel + 지도 열기', (tester) async {
    await pumpHome(tester);

    expect(find.byType(MiniKoreaMap), findsOneWidget);
    expect(find.text('방문 TOP 3'), findsOneWidget);
    expect(find.text('지도 열기'), findsOneWidget);
    // 테스트 환경엔 백엔드가 없어 `/users/me/dashboard`가 비므로 빈 상태 문구.
    expect(find.text('아직 방문 인증이 없어요'), findsOneWidget);
  });

  testWidgets('tapping 지도 열기 opens <지도>', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('지도 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  });
}

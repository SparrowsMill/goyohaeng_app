import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/screens/mill/mill_home_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_reward_screen.dart';
import 'package:goyohaeng_app/screens/record/footprint_write_screen.dart';
import 'package:goyohaeng_app/screens/record/my_footprint_screen.dart';
import 'package:goyohaeng_app/screens/sparrow/sparrow_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('나의 발자국: 헤더 + 달력 + 날짜별 기록 카드', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('나의 발자국'), findsOneWidget);
    expect(find.text('여행의 순간을 차곡차곡 남겨보세요.'), findsOneWidget);
    expect(find.textContaining('년 '), findsOneWidget);
    expect(find.text('9월 9일 수요일'), findsOneWidget);
  });

  testWidgets('달력 이전/다음 달 이동', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('2026년 9월'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('2026년 8월'), findsOneWidget);
  });

  testWidgets('하단 네비 기록 탭 → 나의 발자국', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => KoreaGeo.load());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MillHomeScreen()),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(MyFootprintScreen), findsNothing);
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.byType(MyFootprintScreen), findsOneWidget);
  });

  testWidgets('나의 발자국 연필 버튼 → 발자국 남기기', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(FootprintWriteScreen), findsOneWidget);
    expect(find.text('발자국 남기기'), findsOneWidget);
  });

  testWidgets('마이 페이지 일기 쓰기 → 발자국 남기기', (tester) async {
    await pumpScreen(tester, const SparrowScreen());

    await tester.scrollUntilVisible(
      find.text('일기 쓰기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.byType(FootprintWriteScreen), findsOneWidget);
  });

  testWidgets('방문 인증 보상: 기록 플랫폼 버튼 → 발자국 남기기 (장소 자동입력)', (tester) async {
    final spot = rankingForRegion('36').first;
    await pumpScreen(tester, VisitRewardScreen(spot: spot));

    await tester.ensureVisible(find.text('기록 플랫폼'));
    await tester.tap(find.text('기록 플랫폼'));
    await tester.pumpAndSettle();

    expect(find.byType(FootprintWriteScreen), findsOneWidget);
    expect(find.text(spot.name), findsOneWidget);
  });

  testWidgets('발자국 남기기: 사진 삭제 배지 + 글자수 카운터', (tester) async {
    await pumpScreen(
      tester,
      const FootprintWriteScreen(
        initialPlace: '전주 한옥마을',
        initialPhotoAssets: [
          'assets/illustrations/rewards/ingredient_bamboo.png',
          'assets/illustrations/rewards/ingredient_greentea.png',
        ],
      ),
    );

    expect(find.text('전주 한옥마을'), findsOneWidget);
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('짧은 글 (200자 이내)'), findsOneWidget);
    expect(find.byIcon(Symbols.close_rounded), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).last, '한옥 골목을 천천히 걸었다.');
    await tester.pump();
    expect(find.textContaining('/200'), findsOneWidget);
  });

  testWidgets('나의 발자국: FAB로 새 기록 작성 → 목록에 추가', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '가을 산책');
    await tester.enterText(find.byType(TextField).last, '노란 은행잎이 바닥을 덮었다.');
    await tester.pump();

    await tester.ensureVisible(find.text('기록 남기기'));
    await tester.tap(find.text('기록 남기기'));
    await tester.pumpAndSettle();

    // 목록(MyFootprintScreen)으로 돌아오고 새 기록이 보인다.
    expect(find.byType(FootprintWriteScreen), findsNothing);
    expect(find.text('가을 산책'), findsOneWidget);
    expect(find.text('노란 은행잎이 바닥을 덮었다.'), findsOneWidget);
  });

  testWidgets('나의 발자국: 기록을 눌러 수정 → 목록 반영', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.text('글을 눌러 수정').first);
    await tester.pumpAndSettle();

    expect(find.text('발자국 다듬기'), findsOneWidget);
    expect(find.text('전주 한옥마을'), findsOneWidget); // 기존 장소가 채워짐

    await tester.enterText(find.byType(TextField).last, '해질녘 다시 찾은 골목.');
    await tester.pump();
    await tester.ensureVisible(find.text('기록 수정 완료'));
    await tester.tap(find.text('기록 수정 완료'));
    await tester.pumpAndSettle();

    expect(find.byType(FootprintWriteScreen), findsNothing);
    expect(find.text('해질녘 다시 찾은 골목.'), findsOneWidget);
    expect(find.text('기록을 수정했어요.'), findsOneWidget);
  });

  testWidgets('나의 발자국: ⋯ 메뉴로 기록 삭제', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('9월 9일 수요일'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('9월 9일 수요일'), findsNothing);
    expect(find.text('기록을 삭제했어요.'), findsOneWidget);
  });
}

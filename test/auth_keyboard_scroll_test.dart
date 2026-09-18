import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/screens/auth/login_screen.dart';
import 'package:goyohaeng_app/screens/auth/signup_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';

/// 로그인/회원가입 화면: 상단 배너(+ 로그인 화면의 로고)는 고정, 그 아래
/// 입력 카드만 스크롤돼야 한다 — 특히 소프트 키보드가 떠서 보이는 영역이
/// 줄어들었을 때도 제출 버튼까지 스크롤해서 도달할 수 있어야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> checkKeyboardScroll(
    WidgetTester tester, {
    required Widget screen,
    required Finder submitButton,
  }) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final bannerTopBefore = tester.getTopLeft(find.byType(Image).first).dy;

    // 소프트 키보드가 뜬 상태를 흉내낸다 — 가시 영역이 크게 줄어든다.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: '키보드가 떠서 남은 공간이 줄어도 오버플로우가 나면 안 된다',
    );

    // 배너는 키보드가 떠도 밀리지 않고 그 자리에 고정돼 있어야 한다.
    expect(tester.getTopLeft(find.byType(Image).first).dy, bannerTopBefore);

    // 제출 버튼까지 스크롤해서 도달할 수 있어야 한다.
    await tester.dragUntilVisible(
      submitButton,
      find.byType(Scrollable).first,
      const Offset(0, -80),
    );
    expect(submitButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('로그인: 키보드가 떠도 배너는 고정, 로그인 버튼까지 스크롤 가능', (
    tester,
  ) async {
    await checkKeyboardScroll(
      tester,
      screen: const LoginScreen(),
      submitButton: find.widgetWithText(ElevatedButton, '로그인'),
    );
  });

  testWidgets('회원가입: 키보드가 떠도 배너는 고정, 회원가입 버튼까지 스크롤 가능', (
    tester,
  ) async {
    await checkKeyboardScroll(
      tester,
      screen: const SignupScreen(),
      submitButton: find.widgetWithText(ElevatedButton, '회원가입'),
    );
  });
}

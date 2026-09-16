import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/widgets/app_bottom_nav_bar.dart';

void main() {
  for (final safeBottom in [0.0, 34.0]) {
    testWidgets('last item clears floating navigation with inset $safeBottom', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 700),
              padding: EdgeInsets.only(bottom: safeBottom),
              viewPadding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                extendBody: true,
                body: ListView(
                  controller: controller,
                  padding: AppBottomNavBar.scrollPadding(
                    context,
                    const EdgeInsets.all(16),
                  ),
                  children: const [
                    SizedBox(height: 1000),
                    SizedBox(key: ValueKey('last'), height: 60),
                  ],
                ),
                bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('last'))).dy,
        lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

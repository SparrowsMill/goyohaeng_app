import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/widgets/app_bottom_nav_bar.dart';

/// Mirrors the shape of `map_screen.dart`'s `_buildVectorBody`: the outer
/// `screenContext` (from the enclosing widget's own `build`, above the
/// `extendBody: true` Scaffold) is passed in, but the body itself is built by
/// a `LayoutBuilder` whose builder callback introduces its own `context` of
/// the same name — a descendant of the Scaffold's body. A regression here
/// would mean some future edit passes that inner, shadowed `context` to
/// `AppBottomNavBar.scrollPadding` again instead of [screenContext].
Widget _mapLikeBody(BuildContext screenContext) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        children: [
          Positioned(
            left: 8,
            bottom:
                8 +
                AppBottomNavBar.scrollPadding(screenContext, EdgeInsets.zero)
                    .bottom,
            child: const SizedBox(
              key: ValueKey('overlayButton'),
              width: 50,
              height: 50,
            ),
          ),
        ],
      );
    },
  );
}

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

  for (final safeBottom in [0.0, 20.0, 34.0, 48.0]) {
    testWidgets(
      'map-style floating overlay button clears floating navigation '
      'with inset $safeBottom',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: EdgeInsets.only(bottom: safeBottom),
                viewPadding: EdgeInsets.only(bottom: safeBottom),
              ),
              child: Builder(
                builder: (screenContext) => Scaffold(
                  extendBody: true,
                  body: _mapLikeBody(screenContext),
                  bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('overlayButton'))).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

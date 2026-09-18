import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/screens/food/chef_kitchen_screen.dart';
import 'package:goyohaeng_app/screens/food/food_info_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final owned in [1, 3]) {
    testWidgets('food detail displays inventory $owned and gates cooking',
        (tester) async {
      final requests = <http.Request>[];
      var currentOwned = owned;
      AuthStore.instance.debugSignIn();
      ApiClient.instance.debugHttpClient = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({
          'id': 1,
          'name': '계란볶음밥',
          'canMake': currentOwned >= 2,
          'ingredients': [
            {
              'id': 10,
              'name': '계란',
              'requiredQuantity': 2,
              'ownedQuantity': currentOwned,
              'enough': currentOwned >= 2,
            },
          ],
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      addTearDown(() {
        AuthStore.instance.debugSignOut();
        ApiClient.instance.debugHttpClient =
            MockClient((_) async => http.Response('{}', 400));
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const FoodInfoScreen(foodId: 1),
      ));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v1/foods/1');
      expect(requests.single.headers['Authorization'], 'Bearer debug-token');
      await tester.drag(find.byType(SingleChildScrollView).first,
          const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('$owned / 2'), findsOneWidget);
      expect(find.text(owned >= 2 ? '보유완료' : '부족'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '만들기'),
      );
      expect(button.onPressed != null, owned >= 2);
      if (owned >= 2) {
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, '만들기'));
        await tester.tap(find.widgetWithText(ElevatedButton, '만들기'));
        await tester.pumpAndSettle();
        expect(find.byType(ChefKitchenScreen), findsOneWidget);
        currentOwned = 1;
        Navigator.of(tester.element(find.byType(ChefKitchenScreen))).pop();
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('부족'), findsOneWidget);
        expect(
          tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '만들기'),
          ).onPressed,
          isNull,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

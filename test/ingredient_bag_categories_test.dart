import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/screens/food/ingredient_bag_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'rarity tabs include owned and unowned ingredients only in their grade',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AuthStore.instance.debugSignIn();
      addTearDown(() {
        AuthStore.instance.debugSignOut();
        ApiClient.instance.debugHttpClient = MockClient(
          (_) async => http.Response('{}', 400),
        );
      });
      const grades = ['COMMON', 'UNCOMMON', 'RARE', 'LEGENDARY'];
      const labels = ['일반', '고급', '희귀', '전설'];
      final items = [
        for (var grade = 0; grade < grades.length; grade++)
          for (var owned = 0; owned < 2; owned++)
            {
              'id': grade * 2 + owned + 1,
              'name': 'item-$grade-$owned',
              'rarity': grades[grade],
              // Rarity must take priority over regional/basic classification.
              'ingredientType': owned == 0 ? 'REGIONAL' : 'BASIC',
              'regionId': owned == 0 ? 1 : null,
              'quantity': owned,
              'owned': owned == 1,
            },
      ];
      ApiClient.instance.debugHttpClient = MockClient((request) async {
        final Object body = request.url.path.endsWith('/users/me/ingredients')
            ? {'items': items, 'totalTypes': 4, 'totalQuantity': 4}
            : {'items': []};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const IngredientBagScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (var selected = 0; selected < grades.length; selected++) {
        await tester.tap(find.text(labels[selected]));
        await tester.pump(const Duration(milliseconds: 300));
        for (var grade = 0; grade < grades.length; grade++) {
          for (var owned = 0; owned < 2; owned++) {
            expect(
              find.text('item-$grade-$owned'),
              grade == selected ? findsOneWidget : findsNothing,
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('makeable section excludes foods with canMake false', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AuthStore.instance.debugSignIn();
    addTearDown(() {
      AuthStore.instance.debugSignOut();
      ApiClient.instance.debugHttpClient = MockClient(
        (_) async => http.Response('{}', 400),
      );
    });
    ApiClient.instance.debugHttpClient = MockClient((request) async {
      final Object body = request.url.path.endsWith('/users/me/ingredients')
          ? {'items': [], 'totalTypes': 0, 'totalQuantity': 0}
          : {
              'items': [
                {
                  'id': 1,
                  'name': '지금 만들 수 있는 음식',
                  'canMake': true,
                  'isCompleted': false,
                  'ingredients': [],
                },
                {
                  'id': 2,
                  'name': '재료가 부족한 음식',
                  'canMake': false,
                  'isCompleted': false,
                  'ingredients': [
                    {
                      'id': 10,
                      'name': '계란',
                      'requiredQuantity': 2,
                      'ownedQuantity': 1,
                      'enough': false,
                    },
                  ],
                },
              ],
            };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const IngredientBagScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('지금 만들 수 있는 음식'), findsOneWidget);
    expect(find.text('재료가 부족한 음식'), findsNothing);
  });
}

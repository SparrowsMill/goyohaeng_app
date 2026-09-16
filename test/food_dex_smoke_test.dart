import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/screens/food/food_dex_screen.dart';
import 'package:goyohaeng_app/screens/food/ingredient_bag_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'dex and bag consume the same registered catalog before difficulty filtering',
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
      const names = [
        '계란볶음밥',
        '수도권 한우장국밥',
        '횡성식 한우국밥',
        '강화 순무밥상',
        '제주 옥돔구이',
        '영덕 대게찜',
        '등록되지 않은 음식',
        '알 수 없는 음식',
        '돼지고기김치찌개',
        '나주 장어구이',
        '산청 더덕한우비빔밥',
        '제주 한우구이',
      ];
      const recipes = [
        (region: null, ids: [1]),
        (region: null, ids: [1, 2]),
        (region: '강원', ids: [2]),
        (region: '수도권', ids: [1, 3]),
        (region: '수도권', ids: [1, 4]),
        (region: null, ids: [4]),
        (region: null, ids: <int>[]),
        (region: null, ids: [999]),
        (region: null, ids: [1, 5]),
        (region: '전라', ids: [1, 2]),
        (region: '경상', ids: [2]),
        (region: '제주', ids: [1, 2]),
      ];
      ApiClient.instance.debugHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/regions')) {
          return http.Response(
            jsonEncode([
              {'id': 10, 'name': '수도권'},
              {'id': 20, 'name': '제주'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('/users/me/ingredients')) {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 1, 'ingredientType': 'BASIC', 'rarity': 'COMMON'},
                {'id': 2, 'ingredientType': 'BASIC', 'rarity': 'RARE'},
                {'id': 5, 'ingredientType': 'BASIC', 'rarity': 'UNCOMMON'},
                {
                  'id': 3,
                  'ingredientType': 'REGIONAL',
                  'regionId': 10,
                  'rarity': 'LEGENDARY',
                },
                {
                  'id': 4,
                  'ingredientType': 'REGIONAL',
                  'regionId': 20,
                  'rarity': 'RARE',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final body = request.url.path.endsWith('/users/me/foods')
            ? {'items': [], 'total': 0, 'page': 1, 'limit': 100}
            : {
                'items': [
                  for (final i in [9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8])
                    {
                      'id': i + 1,
                      'name': names[i],
                      'regionName': recipes[i].region,
                      'canMake': true,
                      'ingredients': [
                        for (final id in recipes[i].ids)
                          {'id': id, 'name': 'ingredient'},
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
        MaterialApp(theme: AppTheme.light, home: const FoodDexScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('기본 · 수도권 재료 음식'), findsOneWidget);
      expect(find.text('표시할 음식이 없어요.'), findsNothing);
      for (var i = 0; i < recipes.length; i++) {
        expect(
          find.text(names[i]),
          [0, 1, 3, 8].contains(i) ? findsOneWidget : findsNothing,
        );
      }
      for (final filter in [
        (label: '일반', ids: [0]),
        (label: '고급', ids: [8]),
        (label: '희귀·전설', ids: [1, 3]),
        (label: '전체', ids: [0, 1, 3, 8]),
      ]) {
        await tester.tap(find.widgetWithText(ChoiceChip, filter.label));
        await tester.pumpAndSettle();
        for (var i = 0; i < recipes.length; i++) {
          expect(
            find.text(names[i]),
            filter.ids.contains(i) ? findsOneWidget : findsNothing,
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const IngredientBagScreen()),
      );
      await tester.pumpAndSettle();
      // Excluded regional foods precede the common food in the API response.
      expect(find.text('추천: ${names[0]}'), findsOneWidget);
      final carousel = tester.widget<ListView>(find.byType(ListView));
      expect(
        carousel.childrenDelegate.estimatedChildCount,
        7,
      ); // 4 foods + 3 gaps.
      for (final i in [2, 4, 5, 6, 7, 9, 10, 11]) {
        expect(find.text(names[i]), findsNothing);
        expect(find.text('추천: ${names[i]}'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

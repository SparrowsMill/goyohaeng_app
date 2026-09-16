import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/data/food_catalog.dart';
import 'package:goyohaeng_app/widgets/reward_image.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('catalog and bundled dish assets match exactly', () {
    expect(FoodCatalog.assets, hasLength(19));
    final bundled = File('pubspec.yaml')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where(
          (line) => line.startsWith('- assets/illustrations/rewards/dish/'),
        )
        .map((line) => line.substring(2))
        .toSet();
    final expected = FoodCatalog.assets.keys.map(FoodCatalog.assetPath).toSet();
    expect(bundled, expected);
    for (final path in expected) {
      expect(File(path!).existsSync(), isTrue, reason: path);
    }
  });

  test('services keep foods without bundled assets', () async {
      final requests = <http.Request>[];
      final client = ApiClient.instance;
      client.debugHttpClient = MockClient((request) async {
        requests.add(request);
        Object body;
        final included = {'id': 1, 'foodId': 1, 'name': '계란볶음밥'};
        final excluded = {'id': 2, 'foodId': 2, 'name': '나주 장어구이'};
        switch (request.url.path.split('/').last) {
          case 'foods':
            if (request.url.path.contains('/users/me/')) {
              body = {
                'items': [excluded, included],
                'page': 1,
                'limit': 20,
                'total': 2,
                'totalPages': 1,
              };
            } else {
              body = {
                'items': [excluded, included],
              };
            }
          default:
            if (request.url.path.contains('/ingredients/')) {
              body = {
                'id': 1,
                'usedFoods': [excluded, included],
              };
            } else if (request.url.path.contains('/food-histories/')) {
              body = {'food': excluded};
            } else {
              body = excluded;
            }
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(
        () => client.debugHttpClient = MockClient(
          (_) async => http.Response('{}', 400),
        ),
      );
      expect((await FoodService().list()).map((food) => food.name), [
        '나주 장어구이',
        '계란볶음밥',
      ]);
      expect(
        (await IngredientService().detail(
          1,
        )).usedFoods.map((food) => food.name),
        ['나주 장어구이', '계란볶음밥'],
      );
      final page = await UserService().getFoods();
      expect(page.items.map((food) => food.name), ['나주 장어구이', '계란볶음밥']);
      expect(page.total, 2);
      expect(page.totalPages, 1);
      expect((await FoodService().detail(2)).name, '나주 장어구이');
      await FoodService().make(2);
      expect(requests.where((request) => request.method == 'POST'), hasLength(1));
      expect((await FoodHistoryService().detail(2)).food.name, '나주 장어구이');
    },
  );

  testWidgets('dishes without bundled assets use their server image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RewardImage(
          name: '나주 장어구이',
          folder: RewardAssetFolder.dish,
          networkUrl: 'https://example.com/excluded.png',
          icon: Icons.restaurant,
          color: Colors.black,
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/screens/ranking/ranking_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('open filter updates delayed categories and retries failure',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final response = Completer<http.Response>();
    var retry = false;
    ApiClient.instance.debugHttpClient = MockClient((request) async {
      if (request.url.path.endsWith('/categories')) {
        if (!retry) return response.future;
        return http.Response(jsonEncode([
          {'id': 1, 'name': '음식', 'parentId': null, 'isActive': true},
          {'id': 2, 'name': '숙박', 'parentId': null, 'isActive': true},
          {'id': 8, 'name': '한식', 'parentId': 1, 'isActive': true},
        ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 400);
    });
    addTearDown(() {
      ApiClient.instance.debugHttpClient =
          MockClient((_) async => http.Response('{}', 400));
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const RankingScreen(),
    ));
    await tester.tap(find.byTooltip('필터'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    response.complete(http.Response('{}', 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('카테고리를 불러오지 못했어요.'), findsOneWidget);
    retry = true;
    await tester.tap(find.byTooltip('카테고리 다시 불러오기'));
    await tester.pump(const Duration(milliseconds: 400));
    final dropdown = tester.widget<DropdownButton<int?>>(
      find.byType(DropdownButton<int?>),
    );
    expect(dropdown.items!.map((item) => item.value), [null, 1, 2]);
    expect(dropdown.onChanged, isNotNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/data/gap_spots.dart';
import 'package:goyohaeng_app/data/place_verification_cache.dart';
import 'package:goyohaeng_app/screens/place/place_info_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_prepare_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_unavailable_screen.dart';
import 'package:goyohaeng_app/widgets/ranking_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final available in <bool?>[true, false, null]) {
    testWidgets('API availability $available reaches the ranking card', (
      tester,
    ) async {
      final spot = gapPlaceToSpot(
        GapPlace.fromJson({
          'placeId': 91001,
          'placeName': '테스트 장소',
          'verificationAvailable': ?available,
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankingCard(
              rank: 1,
              spot: spot,
              onTap: () {},
              onDetail: () {},
            ),
          ),
        ),
      );
      expect(
        find.text(switch (available) {
          true => '방문 인증 가능',
          false => '방문 인증 불가',
          null => '방문 인증 알 수 없음',
        }),
        findsOneWidget,
      );
    });
  }

  for (final enabled in <bool?>[true, false, null]) {
    testWidgets(
      'Detail verification $enabled overrides list and logs navigation',
      (tester) async {
        final events = <String>[];
        ApiClient.instance.debugHttpClient = MockClient((request) async {
          if (request.url.path.endsWith('/analytics/events')) {
            events.add(jsonDecode(request.body)['eventType'] as String);
            return http.Response('{}', 201);
          }
          if (request.url.path.endsWith('/places/91002')) {
            return http.Response(
              jsonEncode({
                'id': 91002,
                'name': '테스트 장소',
                'verification': enabled == null ? null : {'enabled': enabled},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 200);
        });
        final spot = gapPlaceToSpot(
          GapPlace.fromJson({
            'placeId': 91002,
            'placeName': '테스트 장소',
            'verificationAvailable': enabled != true,
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PlaceInfoScreen(spot: spot, placeId: spot.placeId),
          ),
        );
        await tester.pumpAndSettle();
        expect(PlaceVerificationCache.get(91002), enabled ?? false);
        final button = find.widgetWithText(ElevatedButton, '방문 인증');
        // `ListView`가 뷰포트+캐시 범위 밖 항목은 지연 빌드하므로, 그 위에
        // 놓인 카드가 늘어나 버튼이 그 범위 밖으로 밀려나면 `ensureVisible`
        // (요소가 이미 트리에 있어야 동작) 만으로는 찾지 못한다 —
        // `scrollUntilVisible`로 실제 스크롤해 가며 빌드되게 한다.
        await tester.scrollUntilVisible(button, 200);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byType(
            enabled == true ? VisitPrepareScreen : VisitUnavailableScreen,
          ),
          findsOneWidget,
        );
        expect(
          events,
          enabled == true
              ? ['PLACE_DETAIL_VIEW', 'VISIT_AUTH_PAGE_ENTER']
              : ['PLACE_DETAIL_VIEW'],
        );
      },
    );
  }
}

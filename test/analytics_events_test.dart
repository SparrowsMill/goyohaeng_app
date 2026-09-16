import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/screens/place/place_info_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_prepare_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final spot = rankingForRegion('36').first;

  for (final event in ['PLACE_DETAIL_VIEW', 'VISIT_AUTH_PAGE_ENTER']) {
    testWidgets('$event sends once per entry without blocking the screen',
        (tester) async {
      final requests = <http.Request>[];
      final response = Completer<http.Response>();
      AuthStore.instance.debugSignIn();
      ApiClient.instance.debugHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/analytics/events')) {
          requests.add(request);
          return response.future;
        }
        return http.Response('{}', 400);
      });
      addTearDown(() {
        AuthStore.instance.debugSignOut();
        ApiClient.instance.debugHttpClient = MockClient(
          (_) async => http.Response('{}', 400),
        );
      });

      Widget screen() => MaterialApp(
            theme: AppTheme.light,
            home: event == 'PLACE_DETAIL_VIEW'
                ? PlaceInfoScreen(spot: spot, placeId: 4155)
                : VisitPrepareScreen(spot: spot, placeId: 4155),
          );

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/v1/analytics/events');
      expect(requests.single.headers['Authorization'], 'Bearer debug-token');
      expect(jsonDecode(requests.single.body), {
        'placeId': 4155,
        'eventType': event,
      });
      expect(find.text(spot.name), findsWidgets);

      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));

      response.complete(http.Response('{}', 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }
}

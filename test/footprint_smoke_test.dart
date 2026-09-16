import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/screens/mill/mill_home_screen.dart';
import 'package:goyohaeng_app/screens/place/visit_reward_screen.dart';
import 'package:goyohaeng_app/screens/record/footprint_write_screen.dart';
import 'package:goyohaeng_app/screens/record/my_footprint_screen.dart';
import 'package:goyohaeng_app/screens/sparrow/sparrow_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_symbols_icons/symbols.dart';

/// `RecordService`(`GET/POST/PATCH/DELETE /records*`)가 실제로 호출하는
/// 요청을 흉내 내는 인메모리 가짜 백엔드. `test/flutter_test_config.dart`가
/// 파일 전체에 깔아둔 "전부 400" `MockClient`를, 이 파일에서만 이걸로
/// 덮어써서 로그인 상태의 실제 CRUD 흐름을 검증한다.
class _FakeRecordsBackend {
  _FakeRecordsBackend(this.records)
    : _nextId =
          1 +
          (records.isEmpty
              ? 0
              : records
                    .map((r) => r['id'] as int)
                    .reduce((a, b) => a > b ? a : b));

  final List<Map<String, dynamic>> records;
  int _nextId;

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final method = request.method;

    if (path.endsWith('/records/calendar') && method == 'GET') {
      final year = int.parse(request.url.queryParameters['year']!);
      final month = int.parse(request.url.queryParameters['month']!);
      final counts = <String, int>{};
      for (final r in records) {
        final d = DateTime.parse(r['date'] as String);
        if (d.year == year && d.month == month) {
          counts[r['date'] as String] = (counts[r['date'] as String] ?? 0) + 1;
        }
      }
      return _json(200, {
        'year': year,
        'month': month,
        'recordDays': [
          for (final e in counts.entries)
            {'date': e.key, 'recordCount': e.value},
        ],
      });
    }

    if (path.endsWith('/records') && method == 'GET') {
      final sorted = [...records]
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return _json(200, {
        'records': sorted,
        'page': 1,
        'limit': 50,
        'total': sorted.length,
        'totalPages': 1,
      });
    }

    if (path.endsWith('/records') && method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = _nextId++;
      final record = {
        'id': id,
        'date': body['date'],
        'place': null,
        'food': null,
        'title': body['title'],
        'body': body['body'],
        'images': const [],
        'createdAt': DateTime.now().toIso8601String(),
      };
      records.add(record);
      return _json(201, {
        'recordId': id,
        'message': '발자국이 기록되었습니다.',
        'record': record,
      });
    }

    final idMatch = RegExp(r'/records/(\d+)$').firstMatch(path);
    if (idMatch != null) {
      final id = int.parse(idMatch.group(1)!);
      if (method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final record = records.firstWhere((r) => r['id'] == id);
        if (body['date'] != null) record['date'] = body['date'];
        if (body['title'] != null) record['title'] = body['title'];
        if (body['body'] != null) record['body'] = body['body'];
        return _json(200, record);
      }
      if (method == 'DELETE') {
        records.removeWhere((r) => r['id'] == id);
        return _json(200, {'message': '삭제됨'});
      }
      if (method == 'GET') {
        final record = records.firstWhere((r) => r['id'] == id);
        return _json(200, record);
      }
    }

    return http.Response('{"message":"test 환경 — 처리되지 않은 요청"}', 400);
  }

  http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 발자국 CRUD 테스트는 로그인 상태 + 실제 백엔드 흐름을 재현해야 하므로,
  // 이 파일에서만 `flutter_test_config.dart`의 기본(전부 400) MockClient를
  // 매 테스트마다 새로 시딩한 가짜 백엔드로 덮어쓴다. `AuthStore`도 실제
  // 로그인 API 없이 [AuthStore.debugSignIn]으로 바로 로그인 상태로 만든다
  // (프로덕션 코드 경로는 그대로 — 테스트 전용 훅).
  late List<Map<String, dynamic>> fakeRecords;

  setUp(() {
    AuthStore.instance.debugSignIn();
    fakeRecords = [
      {
        'id': 1,
        'date': '2026-09-09',
        'place': {'id': 101, 'name': '전주 한옥마을'},
        'food': null,
        'title': null,
        'body': '기와지붕 사이로 저녁 빛이 스며들 무렵.',
        'images': const [],
        'createdAt': '2026-09-09T00:00:00.000Z',
      },
    ];
    ApiClient.instance.debugHttpClient = _FakeRecordsBackend(
      fakeRecords,
    ).client;
  });

  tearDown(() {
    AuthStore.instance.debugSignOut();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('나의 발자국: 헤더 + 달력 + 날짜별 기록 카드', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('나의 발자국'), findsOneWidget);
    expect(find.text('여행의 순간을 차곡차곡 남겨보세요.'), findsOneWidget);
    expect(find.textContaining('년 '), findsOneWidget);
    expect(find.text('9월 9일 수요일'), findsOneWidget);
  });

  testWidgets('달력 이전/다음 달 이동', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('2026년 9월'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('2026년 8월'), findsOneWidget);
  });

  testWidgets('하단 네비 기록 탭 → 나의 발자국', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => KoreaGeo.load());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MillHomeScreen()),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(MyFootprintScreen), findsNothing);
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.byType(MyFootprintScreen), findsOneWidget);
  });

  testWidgets('나의 발자국 연필 버튼 → 발자국 남기기', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(FootprintWriteScreen), findsOneWidget);
    expect(find.text('발자국 남기기'), findsOneWidget);
  });

  testWidgets('마이 페이지 일기 쓰기 → 발자국 남기기', (tester) async {
    await pumpScreen(tester, const SparrowScreen());

    await tester.scrollUntilVisible(
      find.text('일기 쓰기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    expect(find.byType(FootprintWriteScreen), findsOneWidget);
  });

  testWidgets('방문 인증 보상: 기록 플랫폼 버튼 → 발자국 남기기 (장소 자동입력)', (tester) async {
    final spot = rankingForRegion('36').first;
    await pumpScreen(tester, VisitRewardScreen(spot: spot));

    await tester.ensureVisible(find.text('기록 플랫폼'));
    await tester.tap(find.text('기록 플랫폼'));
    await tester.pumpAndSettle();

    expect(find.byType(FootprintWriteScreen), findsOneWidget);
    expect(find.text(spot.name), findsOneWidget);
  });

  testWidgets('발자국 남기기: 사진 삭제 배지 + 글자수 카운터', (tester) async {
    await pumpScreen(
      tester,
      const FootprintWriteScreen(
        initialPlace: '전주 한옥마을',
        initialPhotoAssets: [
          'assets/illustrations/rewards/ingredient_bamboo.png',
          'assets/illustrations/rewards/ingredient_greentea.png',
        ],
      ),
    );

    expect(find.text('전주 한옥마을'), findsOneWidget);
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('짧은 글 (200자 이내)'), findsOneWidget);
    expect(find.byIcon(Symbols.close_rounded), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).last, '한옥 골목을 천천히 걸었다.');
    await tester.pump();
    expect(find.textContaining('/200'), findsOneWidget);
  });

  testWidgets('나의 발자국: FAB로 새 기록 작성 → 목록에 추가', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '가을 산책');
    await tester.enterText(find.byType(TextField).last, '노란 은행잎이 바닥을 덮었다.');
    await tester.pump();

    await tester.ensureVisible(find.text('기록 남기기'));
    await tester.tap(find.text('기록 남기기'));
    await tester.pumpAndSettle();

    // 목록(MyFootprintScreen)으로 돌아오고 새 기록이 보인다.
    expect(find.byType(FootprintWriteScreen), findsNothing);
    expect(find.text('가을 산책'), findsOneWidget);
    expect(find.text('노란 은행잎이 바닥을 덮었다.'), findsOneWidget);
  });

  testWidgets('나의 발자국: 기록을 눌러 수정 → 목록 반영', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    await tester.tap(find.text('글을 눌러 수정').first);
    await tester.pumpAndSettle();

    expect(find.text('발자국 수정하기'), findsOneWidget);
    expect(find.text('전주 한옥마을'), findsOneWidget); // 기존 장소가 채워짐

    await tester.enterText(find.byType(TextField).last, '해질녘 다시 찾은 골목.');
    await tester.pump();
    await tester.ensureVisible(find.text('기록 수정 완료'));
    await tester.tap(find.text('기록 수정 완료'));
    await tester.pumpAndSettle();

    expect(find.byType(FootprintWriteScreen), findsNothing);
    expect(find.text('해질녘 다시 찾은 골목.'), findsOneWidget);
    expect(find.text('기록을 수정했어요.'), findsOneWidget);
  });

  testWidgets('나의 발자국: ⋯ 메뉴로 기록 삭제', (tester) async {
    await pumpScreen(tester, const MyFootprintScreen());

    expect(find.text('9월 9일 수요일'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('9월 9일 수요일'), findsNothing);
    expect(find.text('기록을 삭제했어요.'), findsOneWidget);
  });
}

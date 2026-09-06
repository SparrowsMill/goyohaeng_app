import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_map_regions.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/screens/map/map_screen.dart';
import 'package:goyohaeng_app/screens/map/region_spot_map.dart';
import 'package:goyohaeng_app/screens/ranking/region_ranking_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('시도 layer parses and every 시도 has stats', () async {
    final geo = await KoreaGeo.load();
    expect(geo.sido, hasLength(17));
    expect(geo.sidoLabels, hasLength(17));
    for (final region in geo.sido) {
      expect(region.rings, isNotEmpty);
      expect(region.id.length, 2);
      expect(mockSidoStats.containsKey(region.id), isTrue,
          reason: '시도 ${region.id} ${region.title}');
    }
  });

  test('시군구 layer parses and nests under a real 시도', () async {
    final geo = await KoreaGeo.load();
    await geo.ensureSigungu();
    expect(geo.sigunguReady, isTrue);
    expect(geo.sigungu, hasLength(250));

    final sidoIds = geo.sido.map((r) => r.id).toSet();
    for (final r in geo.sigungu) {
      expect(r.rings, isNotEmpty);
      expect(sidoIds, contains(r.sidoId), reason: '시군구 ${r.id} ${r.title}');
    }
  });

  test('rankingForRegion resolves 시도, 시군구, and unknown codes', () {
    expect(rankingForRegion('36310'), isNotEmpty); // 담양군 (exact)
    expect(rankingForRegion('36'), isNotEmpty); // 전라남도 (gathers 시군구)
    expect(
      rankingForRegion('36').length,
      greaterThan(rankingForRegion('36310').length),
    );
    expect(rankingForRegion('99999'), isNotEmpty); // fallback, never empty
  });

  test('statsForRegion is deterministic and in the 20–80 band', () {
    final a = statsForRegion('32010');
    final b = statsForRegion('32010');
    expect(a.avgGapIndex, b.avgGapIndex);
    expect(a.avgGapIndex, inInclusiveRange(20, 80));
    expect(a.spotCount, greaterThan(0));
  });

  // The map loads GeoJSON assets asynchronously. Warm the (static) cache with
  // real I/O, pump the screen, then give the event loop one real turn so the
  // widget's load callback fires under the test's fake-async clock.
  Future<void> pumpMapScreen(WidgetTester tester) async {
    await tester.runAsync(() => KoreaGeo.load());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MapScreen()),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  testWidgets('MapScreen renders the vector map with 시도 labels', (tester) async {
    await pumpMapScreen(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // Labels are painted on the canvas (TextPainter), not widgets — so assert
    // the map surface exists and the screen chrome rendered.
    expect(find.text('어디로 떠나볼까요?'), findsOneWidget);
    expect(find.text('전국 보기'), findsOneWidget); // present but faded/ignoring
  });

  testWidgets('tapping a 시도 focuses it; "전국 보기" clears the focus',
      (tester) async {
    await pumpMapScreen(tester);

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = iv.transformationController!;
    expect(controller.value, equals(Matrix4.identity()));

    // Tap roughly over 경기도 (a large mainland 시도): ~44% across, ~22% down
    // the map box, derived from its label coordinate vs the country bounds.
    final box = tester.getRect(find.byType(InteractiveViewer));
    await tester.tapAt(Offset(
      box.left + box.width * 0.44,
      box.top + box.height * 0.22,
    ));
    await tester.pumpAndSettle();

    expect(controller.value, isNot(equals(Matrix4.identity())));

    // "전국 보기" restores the identity transform.
    await tester.ensureVisible(find.text('전국 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전국 보기'));
    await tester.pumpAndSettle();
    expect(
      controller.value.getMaxScaleOnAxis(),
      moreOrLessEquals(1, epsilon: 0.01),
    );
  });

  testWidgets('drilling 시도 → 군 opens <지역별 랭킹> (list + map)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final geo = await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
      return g;
    });
    await pumpMapScreen(tester);

    final box = tester.getRect(find.byType(InteractiveViewer));
    final proj = MapProjector(bounds: geo!.bounds, size: box.size);
    TransformationController tc() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    Offset screenFor(Offset raw) =>
        MatrixUtils.transformPoint(tc().value, proj(raw)) + box.topLeft;

    // 담양군 (36310)의 라벨 지점은 그 안에 있다.
    final damyang = geo.sigunguLabels.firstWhere((l) => l.id == '36310').point;

    await tester.tapAt(screenFor(damyang)); // focus 전남
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(find.byType(RegionRankingScreen), findsNothing);

    await tester.tapAt(screenFor(damyang)); // open 담양군
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(RegionRankingScreen), findsOneWidget);
    expect(find.byType(RegionSpotMap), findsOneWidget);
    expect(find.text('담양 죽녹원'), findsWidgets); // a ranking card
  });

  testWidgets('RegionSpotMap: selecting a spot flies the camera to it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
    });

    final controller = MapController();
    final spots = rankingForRegion('36310').where((s) => s.hasLocation).toList();
    MockTouristSpot? selected;
    late StateSetter setOuter;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return RegionSpotMap(
                regionCode: '36310',
                spots: spots,
                selected: selected,
                onMarkerTap: (s) {},
                mapController: controller,
              );
            },
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    final before = controller.camera.center;
    setOuter(() => selected = spots.last);
    await tester.pump();
    await tester.pump();

    expect(controller.camera.center, isNot(before));
    expect(controller.camera.center.latitude,
        moreOrLessEquals(spots.last.lat!, epsilon: 0.02));
  });

  testWidgets('RegionSpotMap responds to a pinch (camera zoom changes)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
    });

    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RegionSpotMap(
            regionCode: '36310',
            spots: rankingForRegion('36310'),
            selected: null,
            onMarkerTap: (_) {},
            mapController: controller,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    final z0 = controller.camera.zoom;
    final c = tester.getCenter(find.byType(FlutterMap));

    // Two-finger spread ≈ pinch-zoom-in.
    final g1 = await tester.createGesture();
    final g2 = await tester.createGesture();
    await g1.down(c + const Offset(-20, 0));
    await g2.down(c + const Offset(20, 0));
    await tester.pump();
    for (var i = 1; i <= 8; i++) {
      await g1.moveBy(const Offset(-12, 0));
      await g2.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, greaterThan(z0 + 0.3),
        reason: 'pinch-out should zoom the camera in');
  });

  testWidgets('tapping a multi-구 시 opens its 구 (one more level)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final geo = await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
      return g;
    });
    await pumpMapScreen(tester);

    final box = tester.getRect(find.byType(InteractiveViewer));
    final proj = MapProjector(bounds: geo!.bounds, size: box.size);
    TransformationController tc() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    Offset screenFor(Offset raw) =>
        MatrixUtils.transformPoint(tc().value, proj(raw)) + box.topLeft;

    // 수원시 (4 구, code prefix 3101) ≈ mean of its 구 label anchors.
    final suwonGu = geo.sigunguLabels.where((l) => l.id.startsWith('3101'));
    final suwon = suwonGu.fold(Offset.zero, (a, l) => a + l.point) /
        suwonGu.length.toDouble();

    await tester.tapAt(screenFor(suwon)); // focus 경기도
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    await tester.tapAt(screenFor(suwon)); // tap 수원 → drill to its 구
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(RegionRankingScreen), findsNothing); // still the vector map
    expect(find.text('뒤로'), findsOneWidget); // the step-out pill switched
  });
}

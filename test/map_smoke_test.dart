import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';
import 'package:goyohaeng_app/data/mock_map_regions.dart';
import 'package:goyohaeng_app/data/favorites.dart';
import 'package:goyohaeng_app/data/mock_region_ranking.dart';
import 'package:goyohaeng_app/data/place_search.dart';
import 'package:goyohaeng_app/data/user_location.dart';
import 'package:goyohaeng_app/screens/map/map_screen.dart';
import 'package:goyohaeng_app/screens/map/region_spot_map.dart';
import 'package:goyohaeng_app/screens/place/place_info_screen.dart';
import 'package:goyohaeng_app/screens/ranking/region_ranking_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';
import 'package:goyohaeng_app/widgets/favorite_star_button.dart';
import 'package:goyohaeng_app/widgets/my_location_button.dart';
import 'package:goyohaeng_app/widgets/spot_pin.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    // the map surface exists and the fixed chrome rendered.
    expect(find.text('지역명 · 장소명 검색'), findsOneWidget); // pinned search bar
    expect(find.text('전국 보기'), findsOneWidget); // present but faded/ignoring
    // Map section sits on the sea colour, not the cream Scaffold.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((b) => b.color == kMapSeaColor),
      isTrue,
    );
  });

  testWidgets('tapping a 시도 focuses it; "전국 보기" clears the focus',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final geo = await tester.runAsync(KoreaGeo.load);
    await pumpMapScreen(tester);

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    // Home transform: scale 1 (the oversized map just centred, not identity).
    expect(controller.value.getMaxScaleOnAxis(), moreOrLessEquals(1, epsilon: 0.01));

    final box = tester.getRect(find.byType(InteractiveViewer));
    final proj = MapProjector.cover(bounds: geo!.bounds, viewport: box.size, overscan: kMapZoom, insetTop: kMapChromeInset + kMapMarginV, insetBottom: kMapMarginV);
    Offset screenFor(Offset raw) =>
        MatrixUtils.transformPoint(controller.value, proj(raw)) + box.topLeft;

    final gyeonggi = geo.sidoLabels.firstWhere((l) => l.id == '31').point;
    await tester.tapAt(screenFor(gyeonggi));
    await tester.pumpAndSettle();

    // Focused → the camera zoomed in.
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.1));

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
    final proj = MapProjector.cover(bounds: geo!.bounds, viewport: box.size, overscan: kMapZoom, insetTop: kMapChromeInset + kMapMarginV, insetBottom: kMapMarginV);
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

  testWidgets('<지역별 랭킹>: 전주 완산구 lists 5 spots; select → "자세히 보기" → 상세',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
    });

    // 5 mock spots under 전주시 완산구 (35011).
    expect(rankingForRegion('35011'), hasLength(5));

    await tester.pumpWidget(
      const MaterialApp(
        home: RegionRankingScreen(regionKey: '35011', regionName: '전주시 완산구'),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(RegionSpotMap), findsOneWidget);
    expect(find.text('자세히 보기'), findsNothing);

    // Select '전주 경기전' — its card exists in the non-lazy ListView even if
    // scrolled off; bring it on-screen, then tap.
    final card = find.text('전주 경기전', skipOffstage: false);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('자세히 보기'), findsOneWidget); // button appeared

    // 강조 색은 그 스팟 갭지수(핀) 색 계열 — "자세히 보기" 버튼도 그 색.
    final spot =
        rankingForRegion('35011').firstWhere((s) => s.name == '전주 경기전');
    final hsl = HSLColor.fromColor(gapIndexColor(spot.gapIndex));
    final accent =
        hsl.withLightness(hsl.lightness.clamp(0.34, 0.56)).toColor();
    final btn = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('자세히 보기'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(btn.color, accent);

    await tester.tap(find.text('자세히 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceInfoScreen), findsOneWidget);
  });

  testWidgets('<지역별 랭킹>: 카테고리·정렬은 스크롤 목록 밖에 고정', (tester) async {
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: RegionRankingScreen(regionKey: '35011', regionName: '전주시 완산구'),
      ),
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    // 컨트롤은 화면에 있지만 스크롤 ListView의 자식이 아니다 → 고정 헤더.
    expect(find.text('전체'), findsWidgets); // 카테고리 드롭다운
    expect(find.text('갭지수 높은순'), findsWidgets); // 정렬 드롭다운
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('전체')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('갭지수 높은순'),
      ),
      findsNothing,
    );

    // 목록을 스크롤해도 필터 위치는 그대로.
    final catRect = tester.getRect(find.text('전체').first);
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('전체').first), catRect);

    // 카드가 낮아져 리스트 영역에 2개 이상 들어온다.
    final cards =
        find.descendant(of: find.byType(ListView), matching: find.byType(InkWell));
    expect(tester.getSize(cards.first).height, lessThan(96));
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
    final proj = MapProjector.cover(bounds: geo!.bounds, viewport: box.size, overscan: kMapZoom, insetTop: kMapChromeInset + kMapMarginV, insetBottom: kMapMarginV);
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

  testWidgets('system back steps out one drill level, not off the screen',
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
    final proj = MapProjector.cover(bounds: geo!.bounds, viewport: box.size, overscan: kMapZoom, insetTop: kMapChromeInset + kMapMarginV, insetBottom: kMapMarginV);
    TransformationController tc() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    Offset screenFor(Offset raw) =>
        MatrixUtils.transformPoint(tc().value, proj(raw)) + box.topLeft;
    final damyang = geo.sigunguLabels.firstWhere((l) => l.id == '36310').point;

    await tester.tapAt(screenFor(damyang)); // focus 전남
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    // System back: should un-focus, not leave MapScreen.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue); // handled (by PopScope), route not popped
    expect(find.byType(MapScreen), findsOneWidget);

    // Now we're back at the nationwide view: one tap only focuses 전남 again,
    // it does not jump straight into the ranking screen.
    await tester.tapAt(screenFor(damyang));
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(find.byType(RegionRankingScreen), findsNothing);
  });

  test('PlaceSearchIndex matches 장소명 and 지역명', () async {
    final index = await PlaceSearchIndex.load();

    final byPlace = index.query('죽녹원');
    expect(byPlace.first.isPlace, isTrue);
    expect(byPlace.first.spot?.name, '담양 죽녹원');
    expect(byPlace.first.regionCode, '36310');

    final byRegion = index.query('담양');
    expect(byRegion.any((r) => !r.isPlace && r.regionCode == '36310'), isTrue);

    expect(index.query('없는장소xyz'), isEmpty);
  });

  Future<void> openSearch(WidgetTester tester, String term) async {
    await tester.runAsync(() async {
      final g = await KoreaGeo.load();
      await g.ensureSigungu();
      await PlaceSearchIndex.load();
    });
    await pumpMapScreen(tester);

    await tester.tap(find.text('지역명 · 장소명 검색'));
    await tester.pump(); // start the push
    await tester.pump(const Duration(milliseconds: 400)); // finish the push
    await tester.runAsync(() async {}); // resolve PlaceSearchIndex.load()
    await tester.pump();

    await tester.enterText(find.byType(EditableText), term);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('map search: 지역명 검색 → 그 지역의 <지역별 랭킹>', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSearch(tester, '담양군');
    // The first result row (region "담양군") — scope to the results list so the
    // AppBar's search field (now also holding "담양군") isn't what we tap.
    await tester.tap(
      find
          .descendant(of: find.byType(ListView), matching: find.text('담양군'))
          .first,
    );
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(RegionRankingScreen), findsOneWidget);
    expect(find.text('담양 죽녹원'), findsWidgets);
  });

  testWidgets('map search: 장소명 검색 → 핀 선택 + "자세히 보기" → 상세', (tester) async {
    const h = 900.0;
    tester.view.physicalSize = const Size(390, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 전주 한옥마을 = 갭지수 40 → 완산구 5곳 중 랭킹 꼴찌(목록 맨 아래). 그래도
    // 검색 진입 시 자동으로 스크롤돼 화면에 보여야 한다.
    await openSearch(tester, '한옥마을');
    await tester.tap(find.text('전주 한옥마을').last);
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    expect(find.byType(RegionRankingScreen), findsOneWidget);
    // Pre-selected → its "자세히 보기" button is already shown, and on-screen.
    expect(find.text('자세히 보기'), findsOneWidget);
    expect(find.text('자세히 보기').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('자세히 보기')).bottom, lessThanOrEqualTo(h),
        reason: '맨 아래 랭킹이어도 선택 카드가 화면 안에 보여야 함');

    await tester.ensureVisible(find.text('자세히 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자세히 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceInfoScreen), findsOneWidget);
  });

  group('내 위치', () {
    final original = UserLocation.resolver;
    tearDown(() {
      UserLocation.resolver = original;
      UserLocation.resetForTest();
    });

    testWidgets('벡터 지도: 진입하면 내 위치가 자동으로 잡힌다', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      UserLocation.resetForTest();
      const me = LatLng(37.5665, 126.9780);
      UserLocation.resolver = () async => me;

      await tester.runAsync(() => KoreaGeo.load());
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const MapScreen()),
      );
      await tester.runAsync(() async {}); // KoreaGeo + UserLocation.ensure resolve
      await tester.pumpAndSettle();

      // No button press needed — the dot (painted on the canvas) follows this
      // value. The "내 위치" button is only for returning here after panning.
      expect(UserLocation.position.value, me);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('내 위치'), findsOneWidget);
    });

    testWidgets('벡터 지도: "내 위치" 버튼이 그 위치로 카메라를 되돌린다', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      UserLocation.resetForTest();
      UserLocation.resolver = () async => const LatLng(37.5665, 126.9780);

      await tester.runAsync(() => KoreaGeo.load());
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const MapScreen()),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      final tc = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final zoomBefore = tc.value.getMaxScaleOnAxis();

      await tester.tap(find.text('내 위치'));
      await tester.pumpAndSettle();

      expect(tc.value.getMaxScaleOnAxis(), greaterThan(zoomBefore + 0.5));
    });

    testWidgets('실제 맵: "내 위치" 버튼이 카메라를 그 위치로 옮긴다', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      UserLocation.resetForTest();
      const me = LatLng(35.324, 126.988);
      UserLocation.resolver = () async => me;

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

      controller.move(const LatLng(37.5, 127.0), 10); // 다른 곳으로 이동
      await tester.pump();
      await tester.tap(find.text('내 위치'));
      await tester.pumpAndSettle();

      expect(controller.camera.center.latitude,
          moreOrLessEquals(me.latitude, epsilon: 0.05));
      expect(controller.camera.center.longitude,
          moreOrLessEquals(me.longitude, epsilon: 0.05));
    });

    testWidgets('실제 맵(RegionSpotMap): 내 위치가 그대로 유지된다', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      UserLocation.resetForTest();
      UserLocation.resolver = () async => const LatLng(35.324, 126.988);

      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RegionSpotMap(
              regionCode: '36310',
              spots: rankingForRegion('36310'),
              selected: null,
              onMarkerTap: (_) {},
              mapController: MapController(),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      expect(UserLocation.position.value, isNotNull);
      expect(find.byType(MyLocationDot), findsOneWidget);
    });

    testWidgets('위치를 못 가져오면 조용히 넘어간다 (점 없음)', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      UserLocation.resetForTest();
      UserLocation.resolver = () async => null;

      await pumpMapScreen(tester);
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      expect(UserLocation.position.value, isNull);
      expect(find.byType(MyLocationDot), findsNothing);
    });
  });

  group('즐겨찾기', () {
    tearDown(Favorites.instance.resetToSeed);

    test('Favorites: toggle / count / countForRegion', () {
      final f = Favorites.instance;
      expect(f.contains('담양 죽녹원'), isTrue); // seeded
      expect(f.contains('담양 소쇄원'), isFalse);

      f.toggle('담양 소쇄원');
      expect(f.contains('담양 소쇄원'), isTrue);
      // 담양군(36310) 하위 즐겨찾기: 죽녹원 + 소쇄원.
      expect(f.countForRegion('36310'), 2);
      expect(f.countForRegion('36'), greaterThanOrEqualTo(2)); // 전남 전체

      f.toggle('담양 죽녹원');
      expect(f.contains('담양 죽녹원'), isFalse);
      expect(f.countForRegion('36310'), 1);
    });

    testWidgets('별을 누르면 랭킹 카드에서 즐겨찾기 토글', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: RegionRankingScreen(regionKey: '36310', regionName: '담양군'),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      final star = find.byWidgetPredicate(
        (w) => w is FavoriteStarButton && w.spotName == '담양 소쇄원',
      );
      expect(Favorites.instance.contains('담양 소쇄원'), isFalse);

      await tester.ensureVisible(star);
      await tester.tap(star);
      await tester.pump();
      expect(Favorites.instance.contains('담양 소쇄원'), isTrue);
    });

    testWidgets('<지역별 랭킹>: 즐겨찾기만 필터 → 목록·지도 별 핀', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: RegionRankingScreen(regionKey: '36310', regionName: '담양군'),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      final starInMap = find.descendant(
        of: find.byType(FlutterMap),
        matching: find.byIcon(Symbols.star_rounded),
      );
      // 필터 꺼짐(기본) → 죽녹원이 seed 즐겨찾기여도 지도에 별 없음, 목록엔
      // 즐겨찾기가 아닌 스팟(소쇄원)도 보인다.
      expect(starInMap, findsNothing);
      expect(find.text('담양 소쇄원'), findsWidgets);

      // 지도 좌하단 "즐겨찾기" 오버레이 버튼 ON.
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();

      expect(Favorites.instance.mapOverlayActive.value, isTrue);
      expect(starInMap, findsWidgets); // 지도 별 핀
      expect(find.text('담양 죽녹원'), findsOneWidget); // 즐겨찾기 스팟은 남고
      expect(find.text('담양 소쇄원'), findsNothing); // 나머지는 걸러짐
    });

    testWidgets('RegionSpotMap: 즐겨찾기 모드면 다른 지역 즐겨찾기도 별 핀으로', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });

      final controller = MapController();
      // 담양군을 열지만 seed 즐겨찾기엔 전주·보성 것도 있다. 필터 켜짐 상태로 진입.
      Favorites.instance.mapOverlayActive.value = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RegionSpotMap(
              regionCode: '36310',
              spots: rankingForRegion('36310')
                  .where((s) => Favorites.instance.contains(s.name))
                  .toList(),
              selected: null,
              onMarkerTap: (_) {},
              mapController: controller,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      // 전국이 다 들어오게 축소.
      controller.move(const LatLng(36.0, 127.6), 6.2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      SpotPin? favPin(String name) {
        final f = find.byWidgetPredicate(
          (w) => w is SpotPin && w.label == name && w.favorite,
        );
        return f.evaluate().isEmpty ? null : tester.widget<SpotPin>(f.first);
      }

      // 이 지역(죽녹원) + 다른 지역(경기전·녹차밭) 즐겨찾기가 모두 별 핀.
      expect(favPin('담양 죽녹원'), isNotNull);
      expect(favPin('전주 경기전'), isNotNull);
      expect(favPin('보성 녹차밭'), isNotNull);
    });

    testWidgets('RegionSpotMap: 즐겨찾기 모드 진입은 스팟이 아니라 지역 경계에 맞춘다',
        (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });

      final favs = rankingForRegion('36310')
          .where((s) => Favorites.instance.contains(s.name) && s.hasLocation)
          .toList();
      expect(favs, isNotEmpty);

      final controller = MapController();
      Favorites.instance.mapOverlayActive.value = true; // 필터 켜진 채 진입
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RegionSpotMap(
              regionCode: '36310',
              spots: favs, // 목록이 즐겨찾기만 남은 상태
              selected: null,
              onMarkerTap: (_) {},
              mapController: controller,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      // 단일 즐겨찾기 스팟에 맞췄다면 zoom이 16+로 튄다. 지역 경계에 맞추면 완만.
      expect(controller.camera.zoom, lessThan(13));
    });

    testWidgets('벡터 지도: 즐겨찾기 목록이 맵 위에 얹힘 — 맵은 그대로', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpMapScreen(tester);

      MapToggleButton btn() =>
          tester.widget(find.widgetWithText(MapToggleButton, '즐겨찾기'));
      final mapBefore = tester.getRect(find.byType(InteractiveViewer));
      final header = find.text('즐겨찾기 3곳');

      expect(btn().active, isFalse);
      expect(header.hitTestable(), findsNothing); // panel is slid away

      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();

      // The map box is byte-for-byte unchanged — no resize, no move.
      expect(tester.getRect(find.byType(InteractiveViewer)), mapBefore);
      expect(btn().active, isTrue);
      expect(header.hitTestable(), findsOneWidget); // panel up, on screen
      expect(find.text('담양 죽녹원'), findsOneWidget);

      // The row keeps a star → unfavorite in place.
      await tester.tap(find.byWidgetPredicate(
        (w) => w is FavoriteStarButton && w.spotName == '담양 죽녹원',
      ));
      await tester.pumpAndSettle();
      expect(Favorites.instance.contains('담양 죽녹원'), isFalse);
      expect(find.text('즐겨찾기 2곳'), findsOneWidget);

      // Toggle off → panel slides away again, map still unchanged.
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(btn().active, isFalse);
      expect(find.text('즐겨찾기 2곳').hitTestable(), findsNothing);
      expect(tester.getRect(find.byType(InteractiveViewer)), mapBefore);
    });

    testWidgets('벡터 지도: 즐겨찾기 목록이 뜨면 아래로 팬 여유가 늘어난다 (맵은 그대로)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpMapScreen(tester);

      EdgeInsets margin() => (tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .boundaryMargin)
          .resolve(TextDirection.ltr);
      final rectBefore = tester.getRect(find.byType(InteractiveViewer));
      final closed = margin();

      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();

      final open = margin();
      // 맵 박스는 그대로 — 늘어난 건 팬 허용 범위(boundaryMargin)뿐.
      expect(tester.getRect(find.byType(InteractiveViewer)), rectBefore);
      expect(open.top, closed.top); // 위쪽 여유 동일
      expect(open.bottom, greaterThan(closed.bottom + 100)); // 아래로 더 드래그
    });

    testWidgets('즐겨찾기 목록: 항목 탭 → 지도 집중, "자세히 보기" → <장소 정보>',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpMapScreen(tester);
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();

      final tc = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final zoomBefore = tc.value.getMaxScaleOnAxis();

      // 항목만 탭 → 정보 페이지로 가지 않고 지도만 그 위치로 확대·이동.
      await tester.tap(find.text('전주 경기전'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaceInfoScreen), findsNothing);
      expect(tc.value.getMaxScaleOnAxis(), greaterThan(zoomBefore + 0.5));
      expect(find.text('자세히 보기'), findsOneWidget); // 선택 행에 버튼 등장

      await tester.tap(find.text('자세히 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaceInfoScreen), findsOneWidget);
    });

    testWidgets('즐겨찾기 토글이 벡터 지도 ↔ 실제 지도 전환에도 유지된다', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final g = await KoreaGeo.load();
        await g.ensureSigungu();
      });

      // 벡터 지도에서 즐겨찾기 ON — 상태는 공유 노티파이어에 있다.
      await pumpMapScreen(tester);
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(Favorites.instance.mapOverlayActive.value, isTrue);
      expect(find.text('즐겨찾기 3곳').hitTestable(), findsOneWidget); // 목록 올라옴

      // 실제 타일 지도로 전환 (드릴다운 결과와 동일하게 <지역별 랭킹>을 push).
      await tester.pumpWidget(
        const MaterialApp(
          home: RegionRankingScreen(regionKey: '36310', regionName: '담양군'),
        ),
      );
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      // 전환됐어도 토글은 켜진 채 — 랭킹 목록은 즐겨찾기만, 지도엔 별 핀이 뜬다.
      expect(find.text('담양 죽녹원'), findsOneWidget);
      expect(find.text('담양 소쇄원'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FlutterMap),
          matching: find.byIcon(Symbols.star_rounded),
        ),
        findsWidgets,
      );

      // 실제 지도(랭킹)의 즐겨찾기 오버레이 버튼 OFF.
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(Favorites.instance.mapOverlayActive.value, isFalse);

      // 다시 벡터 지도로 돌아오면 OFF 상태를 이어받는다.
      await pumpMapScreen(tester);
      final toggleInVector = tester.widget<MapToggleButton>(
          find.widgetWithText(MapToggleButton, '즐겨찾기'));
      expect(toggleInVector.active, isFalse);
      expect(find.text('즐겨찾기 3곳').hitTestable(), findsNothing);
    });

    testWidgets('즐겨찾기 목록: 시/군/구로 필터링', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpMapScreen(tester);
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();

      // seed 3곳: 담양군 · 보성군 · 전주시.
      expect(find.text('담양 죽녹원'), findsOneWidget);
      expect(find.text('보성 녹차밭'), findsOneWidget);

      await tester.tap(find.text('담양군')); // filter chip
      await tester.pumpAndSettle();
      expect(find.text('담양 죽녹원'), findsOneWidget);
      expect(find.text('보성 녹차밭'), findsNothing);
      expect(find.text('전주 경기전'), findsNothing);
    });
  });
}

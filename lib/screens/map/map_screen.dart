import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/korea_crs.dart';
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../place/place_info_screen.dart';

/// `<지도>` (user_flow §6) — the whole country as a continuously zoomable
/// vector map drawn from `assets/maps/` GeoJSON. Reached via the "지도 열기"
/// button under the mill-home TOP 3 list and the 지도 bottom-nav tab.
///
/// Drill-down (tap, not zoom):
///   - 처음 : 시도 17개만, 평균 갭지수 색으로 채움
///   - 시도 탭 : 그 시도의 시·군·자치구로 펼침 (수원·성남·청주·창원 등
///     여러 구를 가진 시는 하나로 묶어서 표시) + 카메라 이동
///   - 묶인 시 탭 : 그 시의 구로 다시 펼침
///   - 군·자치구·구 탭 : 실제 지도(네이버맵)로 크로스페이드 ([RegionNaverMap])
///
///   - 장소 탭 : `<장소 정보 페이지>`
///
/// "갭지수란?" opens the explainer; the bottom-right pill steps out one level.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _openSpot(BuildContext context, MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: const Text('지도'),
        actions: const [_NotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('어디로 떠나볼까요?', style: AppTextStyles.h2),
                const SizedBox(width: AppSpacing.xs),
                Image.asset(
                  'assets/illustrations/sparrow/sparrow_default.png',
                  width: 30,
                  height: 30,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(width: 30),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '지역별 갭지수와 숨은 관광 스팟을 둘러보세요',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Align(
              alignment: Alignment.centerRight,
              child: _GapLegend(),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Align(
              alignment: Alignment.centerRight,
              child: GapIndexInfoButton(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _KoreaMap(onSpotTap: (spot) => _openSpot(context, spot)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '지역을 누르면 시·군·구, 그리고 숨은 장소까지 살펴볼 수 있어요',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).maybePop();
          }
          // * TODO: 랭킹/기록 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }
}

/// Notification bell with the unread dot, mirroring the mill-home top bar.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        // * TODO(backend): 알림 목록 화면 연동 필요
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Symbols.notifications_rounded),
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      color: AppColors.textPrimary,
    );
  }
}

/// Compact "낮음 —— 높음" scale shown above the map.
class _GapLegend extends StatelessWidget {
  const _GapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('낮음', style: AppTextStyles.caption),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 96,
          height: 10,
          decoration: BoxDecoration(
            gradient: gapIndexGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('높음', style: AppTextStyles.caption),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vector map
// ─────────────────────────────────────────────────────────────────────────────

/// Short 시도 names for on-map labels, keyed by the GeoJSON's 행정구역 코드
/// (legacy 2-digit scheme). Falls back to the GeoJSON title if a code is new.
const _sidoShortName = <String, String>{
  '11': '서울', '21': '부산', '22': '대구', '23': '인천', '24': '광주',
  '25': '대전', '26': '울산', '29': '세종', '31': '경기', '32': '강원',
  '33': '충북', '34': '충남', '35': '전북', '36': '전남', '37': '경북',
  '38': '경남', '39': '제주',
};

class _KoreaMap extends StatefulWidget {
  const _KoreaMap({required this.onSpotTap});

  /// Called when the user taps a spot pin at the deepest drill level.
  final void Function(MockTouristSpot spot) onSpotTap;

  @override
  State<_KoreaMap> createState() => _KoreaMapState();
}

/// A tourist spot placed on the vector map (its lat/lng forward-projected to
/// the map's source CRS, then to scene space).
typedef _Pin = ({MockTouristSpot spot, Offset scene});

class _KoreaMapState extends State<_KoreaMap>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnim;

  final ValueNotifier<double> _scale = ValueNotifier<double>(1);
  final ValueNotifier<Rect> _viewport = ValueNotifier<Rect>(Rect.zero);

  /// Drill state, outermost → innermost:
  /// - `_focusedSido` (2-digit) expands one 시도 into its units ([_units]);
  /// - `_focusedGroup` (4-digit prefix) expands one multi-구 시 into its 구;
  /// - `_focusedLeaf` (5-digit) opens a single 군/자치구/구, showing its spot
  ///   pins ([_pins]); tapping a pin calls `onSpotTap`.
  final ValueNotifier<String?> _focusedSido = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _focusedGroup = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _focusedLeaf = ValueNotifier<String?>(null);

  KoreaGeo? _geo;
  bool _sigunguRequested = false;

  /// Widget-space size of the map box, from the latest layout.
  Size _boxSize = Size.zero;

  /// Cached projected paths, rebuilt when [_boxSize] changes.
  Size? _pathsForSize;
  final Map<String, Path> _sidoPaths = {};
  final Map<String, Path> _sigunguPaths = {};
  Path _countryOutline = Path();
  MapProjector? _projector;

  /// Union of the focused 시도's 시군구 paths — its outer edge, used instead of
  /// the coarse `sido_boundary` polygon (the two files are simplified
  /// differently, so the 시도 outline otherwise floats off the 시군구 fills).
  /// Keyed by `"<sidoId>@<size>"` so it rebuilds on focus or layout change.
  Path? _focusOutline;
  String? _focusOutlineKey;

  /// The focused 시도's tappable units: each 군/자치구 on its own, each multi-구
  /// 시 merged into one shape until drilled into. Rebuilt with [_unitsKey].
  List<_MapUnit> _units = const [];
  String? _unitsKey;

  /// Spot pins for [_focusedLeaf], in scene space. Rebuilt with [_pinsKey].
  List<_Pin> _pins = const [];
  String? _pinsKey;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.pageTransition,
    )..addListener(() {
        final anim = _matrixAnim;
        if (anim != null) _tc.value = anim.value;
      });
    _tc.addListener(_onTransform);
    KoreaGeo.load().then((geo) {
      if (mounted) setState(() => _geo = geo);
    });
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransform);
    _tc.dispose();
    _animController.dispose();
    _scale.dispose();
    _viewport.dispose();
    _focusedSido.dispose();
    _focusedGroup.dispose();
    _focusedLeaf.dispose();
    super.dispose();
  }

  void _onTransform() {
    _scale.value = _tc.value.getMaxScaleOnAxis();
    if (_boxSize != Size.zero) {
      final topLeft = _tc.toScene(Offset.zero);
      final bottomRight = _tc.toScene(_boxSize.bottomRight(Offset.zero));
      _viewport.value = Rect.fromPoints(topLeft, bottomRight);
    }
  }

  /// Kicks off the one-time lazy load of the 시군구 layer (first 시도 focus).
  void _ensureSigungu() {
    if (_sigunguRequested || _geo == null) return;
    _sigunguRequested = true;
    _geo!.ensureSigungu().then((_) {
      if (mounted) {
        setState(() => _pathsForSize = null); // force path rebuild w/ 시군구
      }
    });
  }

  void _rebuildPaths(KoreaGeo geo, Size size) {
    if (_pathsForSize == size) return;
    _pathsForSize = size;
    final project = _projector = MapProjector(bounds: geo.bounds, size: size);

    Path pathFor(GeoRegion r) {
      final p = Path()..fillType = PathFillType.evenOdd;
      for (final ring in r.rings) {
        if (ring.length < 2) continue;
        p.addPolygon([for (final pt in ring) project(pt)], true);
      }
      return p;
    }

    _sidoPaths
      ..clear()
      ..addEntries(geo.sido.map((r) => MapEntry(r.id, pathFor(r))));

    _countryOutline = Path();
    for (final p in _sidoPaths.values) {
      _countryOutline.addPath(p, Offset.zero);
    }

    _sigunguPaths
      ..clear()
      ..addEntries(geo.sigungu.map((r) => MapEntry(r.id, pathFor(r))));

    // paths changed — force the derived caches to rebuild
    _focusOutlineKey = null;
    _unitsKey = null;
    _pinsKey = null;
  }

  // ── interaction ───────────────────────────────────────────────────────────

  void _animateTo(Matrix4 target) {
    _matrixAnim = Matrix4Tween(begin: _tc.value, end: target).animate(
      CurvedAnimation(parent: _animController, curve: AppMotion.curve),
    );
    _animController.forward(from: 0);
  }

  Matrix4 _matrixForSceneRect(Rect rect) {
    final w = _boxSize.width, h = _boxSize.height;
    // 12% breathing room around the region.
    final padded = rect.inflate(math.max(rect.width, rect.height) * 0.12);
    final scale = math.min(w / padded.width, h / padded.height).clamp(1.0, 12.0);
    final tx = (w - padded.width * scale) / 2 - padded.left * scale;
    final ty = (h - padded.height * scale) / 2 - padded.top * scale;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomToSceneRect(Rect sceneRect) =>
      _animateTo(_matrixForSceneRect(sceneRect));

  void _zoomToRegion(GeoRegion region) {
    final project = MapProjector(bounds: _geo!.bounds, size: _boxSize);
    final b = region.bounds;
    _zoomToSceneRect(Rect.fromPoints(
      project(Offset(b.left, b.top)),
      project(Offset(b.right, b.bottom)),
    ));
  }

  /// Focus one 시도: expand it to units and zoom the camera to it.
  void _focusSido(GeoRegion sido) {
    setState(() {
      _focusedSido.value = sido.id;
      _focusedGroup.value = null;
    });
    _ensureSigungu();
    _zoomToRegion(sido);
  }

  /// Drill into a multi-구 시: expand it to its 구 and zoom to it.
  void _focusGroup(_MapUnit unit) {
    setState(() => _focusedGroup.value = unit.key);
    _zoomToSceneRect(unit.path.getBounds());
  }

  /// Open a single 군/자치구/구: show its spot pins and zoom in tight.
  void _focusLeaf(String code, {Rect? sceneBounds}) {
    setState(() => _focusedLeaf.value = code);
    _pinsKey = null;
    final r = _sceneBoundsOf(code);
    if (sceneBounds != null) {
      _zoomToSceneRect(sceneBounds);
    } else if (r != null) {
      _zoomToSceneRect(r);
    }
  }

  Rect? _sceneBoundsOf(String sigunguId) {
    final p = _sigunguPaths[sigunguId];
    return p == null || p.getBounds().isEmpty ? null : p.getBounds();
  }

  /// Step out one level: 장소 → 시/구, 구 → 시도, 시도 → 전국.
  void _popFocus() {
    if (_focusedLeaf.value != null) {
      setState(() => _focusedLeaf.value = null);
      final group = _focusedGroup.value;
      if (group != null) {
        for (final u in _units) {
          if (u.key == group) {
            _zoomToSceneRect(u.path.getBounds());
            break;
          }
        }
      } else {
        _zoomToFocusedSido();
      }
      return;
    }
    if (_focusedGroup.value != null) {
      setState(() => _focusedGroup.value = null);
      _zoomToFocusedSido();
      return;
    }
    setState(() => _focusedSido.value = null);
    _animateTo(Matrix4.identity());
  }

  void _zoomToFocusedSido() {
    for (final r in _geo?.sido ?? const <GeoRegion>[]) {
      if (r.id == _focusedSido.value) {
        _zoomToRegion(r);
        break;
      }
    }
  }

  /// (Re)builds [_pins] for [_focusedLeaf] if stale.
  void _ensurePins() {
    final proj = _projector;
    final leaf = _focusedLeaf.value;
    final key = leaf == null ? null : '$leaf@$_boxSize';
    if (key == _pinsKey) return;
    _pinsKey = key;

    if (leaf == null || proj == null) {
      _pins = const [];
      return;
    }
    _pins = [
      for (final spot in rankingForRegion(leaf))
        if (spot.hasLocation)
          (
            spot: spot,
            scene: proj(Epsg5179.fromLatLng(LatLng(spot.lat!, spot.lng!))),
          ),
    ];
  }

  /// (Re)builds [_units] for the focused 시도 + layout if stale. Each 군/자치구
  /// is its own unit; the 11 multi-구 시 (수원·성남·청주·창원 …) are merged
  /// into one shape (keyed by their 4-digit code prefix) until drilled into.
  void _ensureUnits() {
    final geo = _geo;
    final proj = _projector;
    final sido = _focusedSido.value;
    final key = sido == null ? null : '$sido@$_boxSize';
    if (key == _unitsKey) return;
    _unitsKey = key;

    if (sido == null || geo == null || proj == null || !geo.sigunguReady) {
      _units = const [];
      return;
    }

    final labelPoint = {for (final l in geo.sigunguLabels) l.id: l.point};
    final byPrefix = <String, List<GeoRegion>>{};
    for (final r in geo.sigungu) {
      if (r.sidoId != sido) continue;
      byPrefix.putIfAbsent(r.id.substring(0, 4), () => []).add(r);
    }

    final units = <_MapUnit>[];
    byPrefix.forEach((prefix, members) {
      if (members.length == 1) {
        final r = members.single;
        final path = _sigunguPaths[r.id];
        if (path == null) return;
        units.add(_MapUnit(
          key: r.id,
          leafId: r.id,
          title: r.title,
          path: path,
          labelPoint: proj(labelPoint[r.id] ?? r.bounds.center),
          gapIndex: statsForRegion(r.id).avgGapIndex,
          memberCount: 1,
        ));
        return;
      }
      Path? union;
      var gapSum = 0, count = 0;
      var lx = 0.0, ly = 0.0;
      for (final r in members) {
        final path = _sigunguPaths[r.id];
        if (path == null) continue;
        union =
            union == null ? path : Path.combine(PathOperation.union, union, path);
        gapSum += statsForRegion(r.id).avgGapIndex;
        final lp = labelPoint[r.id] ?? r.bounds.center;
        lx += lp.dx;
        ly += lp.dy;
        count++;
      }
      if (union == null || count == 0) return;
      units.add(_MapUnit(
        key: prefix,
        leafId: '',
        // member titles are "수원시 장안구" → the 시 name is the first token.
        title: members.first.title.split(' ').first,
        path: union,
        labelPoint: proj(Offset(lx / count, ly / count)),
        gapIndex: (gapSum / count).round(),
        memberCount: members.length,
      ));
    });
    _units = units;
  }

  /// (Re)builds [_focusOutline] for the current focus + layout if stale.
  void _ensureFocusOutline() {
    final geo = _geo;
    final focused = _focusedSido.value;
    final key = focused == null ? null : '$focused@$_boxSize';
    if (key == _focusOutlineKey) return;
    _focusOutlineKey = key;

    if (focused == null || geo == null || !geo.sigunguReady) {
      _focusOutline = null;
      return;
    }
    Path? union;
    for (final r in geo.sigungu) {
      if (r.sidoId != focused) continue;
      final p = _sigunguPaths[r.id];
      if (p == null) continue;
      union = union == null ? p : Path.combine(PathOperation.union, union, p);
    }
    _focusOutline = union;
  }

  void _handleTap(Offset scenePos) {
    final geo = _geo;
    if (geo == null) return;
    final sido = _focusedSido.value;
    final group = _focusedGroup.value;
    final leaf = _focusedLeaf.value;

    // ── Level 3: a single 군/자치구/구 open with its spot pins ───────────────
    if (leaf != null) {
      final hit = 16 / _scale.value; // ~16 px catch radius, in scene units
      _Pin? nearest;
      var best = double.infinity;
      for (final pin in _pins) {
        final d = (pin.scene - scenePos).distance;
        if (d < hit && d < best) {
          best = d;
          nearest = pin;
        }
      }
      if (nearest != null) {
        widget.onSpotTap(nearest.spot);
      } else {
        _popFocus(); // tapped away from any pin → back out
      }
      return;
    }

    // ── Level 2: drilled into a multi-구 시 ──────────────────────────────────
    if (group != null) {
      for (final r in geo.sigungu) {
        if (!r.id.startsWith(group)) continue;
        if (_sigunguPaths[r.id]?.contains(scenePos) ?? false) {
          _focusLeaf(r.id); // a 구 → its spot pins
          return;
        }
      }
      _popFocus(); // tapped outside the 시 → back to the 시도
      return;
    }

    // ── Level 1: a 시도 is focused, showing its units ───────────────────────
    if (sido != null) {
      for (final u in _units) {
        if (!(u.path.contains(scenePos))) continue;
        if (u.isDrillable) {
          _focusGroup(u); // 수원시 등 → show its 구
        } else {
          _focusLeaf(u.leafId, sceneBounds: u.path.getBounds()); // 군/자치구
        }
        return;
      }
      // Inside the 시도 but between units (edges still loading) — ignore.
      if ((_focusOutline ?? _sidoPaths[sido])?.contains(scenePos) ?? false) {
        return;
      }
    }

    // ── Level 0: pick a 시도 (or re-pick / step out) ───────────────────────
    for (final r in geo.sido) {
      if (_sidoPaths[r.id]?.contains(scenePos) ?? false) {
        if (r.id == sido) {
          _popFocus();
        } else {
          _focusSido(r);
        }
        return;
      }
    }

    if (sido != null) _popFocus(); // tapped the sea
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    final aspectRatio =
        geo == null ? 0.92 : geo.bounds.width / geo.bounds.height;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: geo == null
          ? const SizedBox.expand()
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _boxSize = size;
                _rebuildPaths(geo, size);
                _ensureFocusOutline();
                _ensureUnits();
                _ensurePins();
                if (_viewport.value == Rect.zero) {
                  _viewport.value = Offset.zero & size;
                }

                return ClipRect(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _tc,
                        minScale: 1,
                        maxScale: 12,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _handleTap(d.localPosition),
                          child: CustomPaint(
                            size: size,
                            painter: _KoreaMapPainter(
                              geo: geo,
                              sidoPaths: _sidoPaths,
                              sigunguPaths: _sigunguPaths,
                              countryOutline: _countryOutline,
                              scale: _scale,
                              viewport: _viewport,
                              focusedSido: _focusedSido,
                              focusedGroup: _focusedGroup,
                              focusedLeaf: _focusedLeaf,
                              focusOutline: _focusOutline,
                              units: _units,
                              pins: _pins,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: _ResetViewButton(
                          scale: _scale,
                          focusedSido: _focusedSido,
                          focusedGroup: _focusedGroup,
                          focusedLeaf: _focusedLeaf,
                          onTap: _popFocus,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Step-out pill, bottom-right of the map. Hidden at the nationwide view;
/// "뒤로" while drilled into a 시, "전국 보기" while a 시도 is focused.
class _ResetViewButton extends StatelessWidget {
  const _ResetViewButton({
    required this.scale,
    required this.focusedSido,
    required this.focusedGroup,
    required this.focusedLeaf,
    required this.onTap,
  });

  final ValueListenable<double> scale;
  final ValueListenable<String?> focusedSido;
  final ValueListenable<String?> focusedGroup;
  final ValueListenable<String?> focusedLeaf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([scale, focusedSido, focusedGroup, focusedLeaf]),
      builder: (context, child) {
        final drilled =
            focusedGroup.value != null || focusedLeaf.value != null;
        final visible =
            scale.value > 1.02 || focusedSido.value != null || drilled;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.standard,
          child: IgnorePointer(
            ignoring: !visible,
            child: Material(
              color: AppColors.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        drilled
                            ? Symbols.arrow_back_rounded
                            : Symbols.zoom_out_map_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        drilled ? '뒤로' : '전국 보기',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One tappable shape on the 시군구 layer: a whole 군/자치구, or a multi-구 시
/// shown merged ([isDrillable]) until the user taps into it.
class _MapUnit {
  _MapUnit({
    required this.key,
    required this.leafId,
    required this.title,
    required this.path,
    required this.labelPoint,
    required this.gapIndex,
    required this.memberCount,
  });

  /// 4-digit 시 code prefix when [isDrillable], else the 5-digit 시군구 code.
  final String key;

  /// 5-digit code to open on the real map — only meaningful when not drillable.
  final String leafId;
  final String title;

  /// Scene-space (projected) polygon and label anchor.
  final Path path;
  final Offset labelPoint;

  final int gapIndex;
  final int memberCount;

  bool get isDrillable => memberCount > 1;
}

/// Paints the 17 시도, then per drill level: the focused 시도's [units]
/// (L1), one opened 시's 구 (L2), or one 군/자치구/구 with its spot [pins]
/// (L3). Strokes / text sizes are divided by the live zoom so they keep a
/// constant on-screen weight.
class _KoreaMapPainter extends CustomPainter {
  _KoreaMapPainter({
    required this.geo,
    required this.sidoPaths,
    required this.sigunguPaths,
    required this.countryOutline,
    required this.scale,
    required this.viewport,
    required this.focusedSido,
    required this.focusedGroup,
    required this.focusedLeaf,
    required this.focusOutline,
    required this.units,
    required this.pins,
  }) : super(
          repaint: Listenable.merge(
              [scale, viewport, focusedSido, focusedGroup, focusedLeaf]),
        );

  final KoreaGeo geo;
  final Map<String, Path> sidoPaths;
  final Map<String, Path> sigunguPaths;
  final Path countryOutline;
  final ValueListenable<double> scale;
  final ValueListenable<Rect> viewport;
  final ValueListenable<String?> focusedSido;
  final ValueListenable<String?> focusedGroup;
  final ValueListenable<String?> focusedLeaf;

  /// Union of the focused 시도's 시군구 — drawn as that province's outline so
  /// it hugs the 시군구 fills. `null` when nothing is focused / not ready yet.
  final Path? focusOutline;

  /// The focused 시도's tappable units (see [_MapUnit]).
  final List<_MapUnit> units;

  /// Spot pins for the open 군/자치구/구 ([focusedLeaf]).
  final List<_Pin> pins;

  @override
  void paint(Canvas canvas, Size size) {
    final z = scale.value.clamp(1.0, 12.0);
    final view = viewport.value;
    final focused = focusedSido.value;
    final group = focusedGroup.value;
    final leaf = focusedLeaf.value;

    canvas.drawShadow(
      focused != null && focusOutline != null ? focusOutline! : countryOutline,
      AppColors.textPrimary.withValues(alpha: 0.5),
      6,
      false,
    );

    final project = MapProjector(bounds: geo.bounds, size: size);

    final sidoStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6 / z
      ..color = AppColors.surface;
    final unitStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.9 / z
      ..color = AppColors.surface.withValues(alpha: 0.85);

    // 시도 fills (base layer — always).
    for (final region in geo.sido) {
      final path = sidoPaths[region.id];
      if (path == null) continue;
      final stats = statsForRegion(region.id);
      canvas.drawPath(path, Paint()..color = gapIndexColor(stats.avgGapIndex));
    }

    final leafPath = leaf == null ? null : sigunguPaths[leaf];

    if (leaf != null && leafPath != null) {
      // Level 3 — a single 군/자치구/구 opened, the rest dimmed.
      canvas.drawPath(
        leafPath,
        Paint()..color = gapIndexColor(statsForRegion(leaf).avgGapIndex),
      );
    } else if (focused != null && geo.sigunguReady) {
      if (group == null) {
        // Level 1 — the 시도's units (군/자치구 solo, multi-구 시 merged).
        for (final u in units) {
          canvas.drawPath(u.path, Paint()..color = gapIndexColor(u.gapIndex));
          canvas.drawPath(u.path, unitStroke);
        }
      } else {
        // Level 2 — one multi-구 시 opened to its 구; siblings recede.
        for (final u in units) {
          if (u.key == group) continue;
          canvas.drawPath(
            u.path,
            Paint()..color = gapIndexColor(u.gapIndex).withValues(alpha: 0.3),
          );
        }
        for (final r in geo.sigungu) {
          if (!r.id.startsWith(group)) continue;
          final path = sigunguPaths[r.id];
          if (path == null) continue;
          final stats = statsForRegion(r.id);
          canvas.drawPath(
            path,
            Paint()..color = gapIndexColor(stats.avgGapIndex),
          );
          canvas.drawPath(path, unitStroke);
        }
      }
    }

    // Outlines last. `sido_boundary` and `sigungu_boundary` are generalised
    // differently, so while a 시도 is focused only its own outline is drawn
    // (from [focusOutline]); other provinces' coarse edges are dropped rather
    // than left as stray white lines that miss the fills.
    if (leaf != null && leafPath != null) {
      canvas.drawPath(leafPath, sidoStroke);
    } else if (focused == null) {
      for (final path in sidoPaths.values) {
        canvas.drawPath(path, sidoStroke);
      }
    } else {
      canvas.drawPath(focusOutline ?? sidoPaths[focused] ?? Path(), sidoStroke);
      if (group != null) {
        for (final u in units) {
          if (u.key == group) {
            canvas.drawPath(u.path, sidoStroke);
            break;
          }
        }
      }
    }

    if (leaf != null) _paintPins(canvas, z, view);

    _paintLabels(canvas, project, z, view, focused, group, leaf);
  }

  void _paintPins(Canvas canvas, double z, Rect view) {
    final r = 5 / z; // constant ~5 px on screen
    final fill = Paint()..color = AppColors.secondaryAccent;
    final glow = Paint()
      ..color = AppColors.secondaryAccent.withValues(alpha: 0.18);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / z
      ..color = AppColors.surface;

    for (final pin in pins) {
      if (!view.contains(pin.scene)) continue;
      canvas.drawCircle(pin.scene, r * 1.9, glow);
      canvas.drawCircle(pin.scene, r, fill);
      canvas.drawCircle(pin.scene, r, ring);
    }
    // Labels in a second pass, skipping any that would collide with one
    // already placed (spots can sit very close together).
    final placed = <Rect>[];
    for (final pin in pins) {
      if (!view.contains(pin.scene)) continue;
      final box = _measureLabel(pin.spot.name, 11 / z)
          .shift(pin.scene.translate(0, -r * 3.4));
      if (placed.any(box.overlaps)) continue;
      placed.add(box);
      _drawLabel(
        canvas,
        text: pin.spot.name,
        center: pin.scene.translate(0, -r * 3.4),
        gap: pin.spot.gapIndex,
        fontPx: 11 / z,
        region: Path()..addRect(view),
        enforceFit: false,
      );
    }
  }

  /// Bounding box (centred on the origin) of [text] laid out at [fontPx].
  Rect _measureLabel(String text, double fontPx) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontPx, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    return Rect.fromCenter(
        center: Offset.zero, width: tp.width, height: tp.height);
  }

  void _paintLabels(
    Canvas canvas,
    MapProjector project,
    double z,
    Rect view,
    String? focused,
    String? group,
    String? leaf,
  ) {
    // At the deepest level only the pin labels show (drawn in _paintPins).
    if (leaf != null) return;

    // 시도 labels — every 시도 but the focused one.
    for (final label in geo.sidoLabels) {
      if (label.id == focused) continue;
      final region = sidoPaths[label.id];
      if (region == null) continue;
      final p = project(label.point);
      if (!view.contains(p)) continue;
      final stats = statsForRegion(label.id);
      final name = _sidoShortName[label.id] ?? label.title;

      if (focused == null) {
        // Province names anchor the country view — always shown (short form);
        // the 갭지수 subtitle is added only when it actually fits.
        final sub = '갭지수 ${stats.avgGapIndex} · 스팟 ${stats.spotCount}';
        final drewFull = _drawLabel(canvas,
            text: name,
            center: p,
            gap: stats.avgGapIndex,
            fontPx: 13 / z,
            region: region,
            subtitle: sub);
        if (!drewFull) {
          _drawLabel(canvas,
              text: name,
              center: p,
              gap: stats.avgGapIndex,
              fontPx: 13 / z,
              region: region,
              enforceFit: false);
        }
      } else {
        // Another 시도 is focused; these are just context — fit or hide.
        _drawLabel(canvas,
            text: name,
            center: p,
            gap: stats.avgGapIndex,
            fontPx: 13 / z,
            region: region);
      }
    }

    if (focused == null) return;

    if (group == null) {
      // Level 1 — one label per unit (the merged 시 name, or 군/자치구 name).
      for (final u in units) {
        if (!view.contains(u.labelPoint)) continue;
        _drawLabel(
          canvas,
          text: u.title,
          center: u.labelPoint,
          gap: u.gapIndex,
          fontPx: 12 / z,
          region: u.path,
        );
      }
    } else if (geo.sigunguReady) {
      // Level 2 — 구 names within the opened 시 ("장안구", not "수원시 장안구").
      for (final label in geo.sigunguLabels) {
        if (!label.id.startsWith(group)) continue;
        final region = sigunguPaths[label.id];
        if (region == null) continue;
        final p = project(label.point);
        if (!view.contains(p)) continue;
        final stats = statsForRegion(label.id);
        _drawLabel(
          canvas,
          text: label.title.split(' ').last,
          center: p,
          gap: stats.avgGapIndex,
          fontPx: 12 / z,
          region: region,
        );
      }
    }
  }

  /// Draws [text] centred at [center] — but only if the text box fits inside
  /// [region] at the current scale, so labels appear as you zoom in rather
  /// than overlapping when a region is too small. Returns whether it drew.
  bool _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required int gap,
    required double fontPx,
    required Path region,
    String? subtitle,
    bool enforceFit = true,
  }) {
    final onDark = ThemeData.estimateBrightnessForColor(gapIndexColor(gap)) ==
        Brightness.dark;
    final fg = onDark ? AppColors.surface : AppColors.textPrimary;
    final halo =
        (onDark ? Colors.black : AppColors.surface).withValues(alpha: 0.55);

    final builder = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    builder.text = TextSpan(
      children: [
        TextSpan(
          text: text,
          style: TextStyle(
            color: fg,
            fontSize: fontPx,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: halo, blurRadius: fontPx * 0.4)],
          ),
        ),
        if (subtitle != null)
          TextSpan(
            text: '\n$subtitle',
            style: TextStyle(
              color: fg,
              fontSize: fontPx * 0.72,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: halo, blurRadius: fontPx * 0.4)],
            ),
          ),
      ],
    );
    builder.layout();

    // Does a slightly padded text box, centred on the anchor, sit inside the
    // region polygon? Check the four corners.
    final box = Rect.fromCenter(
      center: center,
      width: builder.width * 1.15,
      height: builder.height * 1.3,
    );
    if (enforceFit) {
      final fits = region.contains(box.topLeft) &&
          region.contains(box.topRight) &&
          region.contains(box.bottomLeft) &&
          region.contains(box.bottomRight);
      if (!fits) return false;
    }

    builder.paint(
      canvas,
      center - Offset(builder.width / 2, builder.height / 2),
    );
    return true;
  }

  @override
  bool shouldRepaint(_KoreaMapPainter old) =>
      old.geo != geo ||
      old.sidoPaths != sidoPaths ||
      old.sigunguPaths != sigunguPaths ||
      old.countryOutline != countryOutline ||
      old.focusedSido != focusedSido ||
      old.focusedGroup != focusedGroup ||
      old.focusedLeaf != focusedLeaf ||
      old.focusOutline != focusOutline ||
      !identical(old.units, units) ||
      !identical(old.pins, pins);
}

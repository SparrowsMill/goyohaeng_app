import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/korea_crs.dart' show Epsg5179, LatLng;
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart';
import '../../data/user_location.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../../widgets/my_location_button.dart';
import '../ranking/region_ranking_screen.dart';
import 'place_search_screen.dart';

/// `<지도>` (user_flow §6) — the whole country as a continuously zoomable
/// vector map drawn from `assets/maps/` GeoJSON. Reached via the "지도 열기"
/// button under the mill-home TOP 3 list and the 지도 bottom-nav tab.
///
/// Drill-down (tap, not zoom):
///   - 처음 : 시도 17개만, 평균 갭지수 색으로 채움
///   - 시도 탭 : 그 시도의 시·군·자치구로 펼침 (수원·성남·청주·창원 등
///     여러 구를 가진 시는 하나로 묶어서 표시) + 카메라 이동
///   - 묶인 시 탭 : 그 시의 구로 다시 펼침
///   - 군·자치구·구 탭 : `<지역별 랭킹>` (목록 + 실제 타일 지도 반반)
///
/// "갭지수란?" opens the explainer; the bottom-right pill steps out one level.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

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
      body: _buildVectorBody(context),
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

  /// Nationwide → 시도 → 시군구 → 구 vector drill-down. The chrome (검색 바 +
  /// 갭지수 범례/설명) is a fixed header — like the bottom nav — and the map
  /// fills the rest of the screen, with its overlay buttons pinned to the
  /// map's corners.
  Widget _buildVectorBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlaceSearchScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Row(
                children: [
                  _GapLegend(),
                  Spacer(),
                  GapIndexInfoButton(),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _KoreaMap(
            onEnterRegion: (code, name) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RegionRankingScreen(
                  regionKey: code,
                  regionName: name,
                ),
              ),
            ),
          ),
        ),
      ],
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

/// Tappable "input" that opens `<지도>` search (지역명·장소명 → `<지역별 랭킹>`).
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.inputField),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.inputField),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.inputField),
          ),
          child: Row(
            children: [
              const Icon(Symbols.search_rounded,
                  size: 20, color: AppColors.iconInactive),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '지역명 · 장소명 검색',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vector map
// ─────────────────────────────────────────────────────────────────────────────

/// Max pinch-zoom on the vector map. Needs to be well past the auto-fit zoom
/// of the smallest 시도 (서울·대전·광주 …) so the user can still zoom into its
/// 자치구 after focusing it.
const double _kMaxScale = 40;

/// Short 시도 names for on-map labels, keyed by the GeoJSON's 행정구역 코드
/// (legacy 2-digit scheme). Falls back to the GeoJSON title if a code is new.
const _sidoShortName = <String, String>{
  '11': '서울', '21': '부산', '22': '대구', '23': '인천', '24': '광주',
  '25': '대전', '26': '울산', '29': '세종', '31': '경기', '32': '강원',
  '33': '충북', '34': '충남', '35': '전북', '36': '전남', '37': '경북',
  '38': '경남', '39': '제주',
};

class _KoreaMap extends StatefulWidget {
  const _KoreaMap({required this.onEnterRegion});

  /// Called with a 시군구/구 code + name when the user taps a leaf region
  /// (a 군, a 자치구, or a 구 within a drilled 시) — `MapScreen` then swaps in
  /// the real tile map for it.
  final void Function(String regionCode, String regionName) onEnterRegion;

  @override
  State<_KoreaMap> createState() => _KoreaMapState();
}

class _KoreaMapState extends State<_KoreaMap>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnim;

  final ValueNotifier<double> _scale = ValueNotifier<double>(1);
  final ValueNotifier<Rect> _viewport = ValueNotifier<Rect>(Rect.zero);

  /// Drill state: `_focusedSido` (2-digit) expands one 시도 into its units
  /// ([_units]); `_focusedGroup` (4-digit prefix) then expands one multi-구 시
  /// into its 구. Tapping a leaf (a 군, a 자치구, or a 구) calls `onEnterRegion`.
  final ValueNotifier<String?> _focusedSido = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _focusedGroup = ValueNotifier<String?>(null);

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

  /// The device's position once "내 위치" is tapped, and its projected
  /// scene-space point (kept in sync by the layout builder) for the painter.
  LatLng? _myLatLng;
  bool _locating = false;
  final ValueNotifier<Offset?> _myPoint = ValueNotifier<Offset?>(null);

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
    _myPoint.dispose();
    super.dispose();
  }

  /// "내 위치": locate the device, drop the dot, and zoom the map to it.
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final here = await UserLocation.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _myLatLng = here;
    });
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치를 가져올 수 없어요. 위치 권한과 GPS를 확인해 주세요.')),
      );
      return;
    }
    final geo = _geo;
    if (geo == null || _boxSize == Size.zero) return;
    final project = MapProjector(bounds: geo.bounds, size: _boxSize);
    final crs = Epsg5179.fromLatLng(here);
    _myPoint.value = project(crs);
    // Zoom to a ~30 km window around the point (clamped to the map's max zoom).
    const half = 15000.0;
    _zoomToSceneRect(Rect.fromPoints(
      project(Offset(crs.dx - half, crs.dy - half)),
      project(Offset(crs.dx + half, crs.dy + half)),
    ));
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
    final scale =
        math.min(w / padded.width, h / padded.height).clamp(1.0, _kMaxScale);
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

  /// Step out one level: 구 → 시도, 시도 → 전국.
  void _popFocus() {
    if (_focusedGroup.value != null) {
      setState(() => _focusedGroup.value = null);
      for (final r in _geo?.sido ?? const <GeoRegion>[]) {
        if (r.id == _focusedSido.value) {
          _zoomToRegion(r);
          break;
        }
      }
      return;
    }
    setState(() => _focusedSido.value = null);
    _animateTo(Matrix4.identity());
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

    // ── Level 2: drilled into a multi-구 시 ──────────────────────────────────
    if (group != null) {
      for (final r in geo.sigungu) {
        if (!r.id.startsWith(group)) continue;
        if (_sigunguPaths[r.id]?.contains(scenePos) ?? false) {
          widget.onEnterRegion(r.id, r.title); // a 구 → real tile map
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
          widget.onEnterRegion(u.leafId, u.title); // 군/자치구 → real tile map
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
    return PopScope(
      // Back steps out one drill level at a time; only leaves the screen once
      // we're at the nationwide view.
      canPop: _focusedSido.value == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popFocus();
      },
      child: _buildMap(context, _geo),
    );
  }

  /// Fills whatever space the parent gives it — the projection is uniform-fit
  /// so the map keeps its shape and the overlay buttons stay pinned to the
  /// box's corners regardless of aspect ratio.
  Widget _buildMap(BuildContext context, KoreaGeo? geo) {
    return SizedBox.expand(
      child: geo == null
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _boxSize = size;
                _rebuildPaths(geo, size);
                _ensureFocusOutline();
                _ensureUnits();
                if (_viewport.value == Rect.zero) {
                  _viewport.value = Offset.zero & size;
                }
                // Keep the "내 위치" dot glued to its lat/lng across layout
                // changes (the projector depends on the box size).
                final here = _myLatLng;
                _myPoint.value = here == null
                    ? null
                    : MapProjector(bounds: geo.bounds, size: size)(
                        Epsg5179.fromLatLng(here),
                      );

                return ClipRect(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _tc,
                        minScale: 1,
                        maxScale: _kMaxScale,
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
                              focusOutline: _focusOutline,
                              units: _units,
                              myPoint: _myPoint,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: MyLocationButton(
                          onTap: _goToMyLocation,
                          busy: _locating,
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: _ResetViewButton(
                          scale: _scale,
                          focusedSido: _focusedSido,
                          focusedGroup: _focusedGroup,
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
    required this.onTap,
  });

  final ValueListenable<double> scale;
  final ValueListenable<String?> focusedSido;
  final ValueListenable<String?> focusedGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scale, focusedSido, focusedGroup]),
      builder: (context, child) {
        final drilled = focusedGroup.value != null;
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
/// (L1) or one opened 시's 구 (L2), each filled by its 갭지수 colour. Strokes
/// / text sizes are divided by the live zoom so they keep a constant
/// on-screen weight.
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
    required this.focusOutline,
    required this.units,
    required this.myPoint,
  }) : super(
          repaint: Listenable.merge(
              [scale, viewport, focusedSido, focusedGroup, myPoint]),
        );

  final KoreaGeo geo;
  final Map<String, Path> sidoPaths;
  final Map<String, Path> sigunguPaths;
  final Path countryOutline;
  final ValueListenable<double> scale;
  final ValueListenable<Rect> viewport;
  final ValueListenable<String?> focusedSido;
  final ValueListenable<String?> focusedGroup;

  /// Union of the focused 시도's 시군구 — drawn as that province's outline so
  /// it hugs the 시군구 fills. `null` when nothing is focused / not ready yet.
  final Path? focusOutline;

  /// The focused 시도's tappable units (see [_MapUnit]).
  final List<_MapUnit> units;

  /// Scene-space position of the device ("내 위치"), or `null` if not located.
  final ValueListenable<Offset?> myPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final z = scale.value.clamp(1.0, _kMaxScale);
    final view = viewport.value;
    final focused = focusedSido.value;
    final group = focusedGroup.value;

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

    if (focused != null && geo.sigunguReady) {
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
    if (focused == null) {
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

    _paintLabels(canvas, project, z, view, focused, group);
    _paintMyLocation(canvas, z, view);
  }

  /// The "you are here" dot — constant on-screen size (÷ z), with a white ring
  /// and a soft halo, matching `MyLocationDot` on the real tile map.
  void _paintMyLocation(Canvas canvas, double z, Rect view) {
    final p = myPoint.value;
    if (p == null || !view.contains(p)) return;
    final r = 5.5 / z;
    canvas.drawCircle(
      p,
      r * 2.6,
      Paint()..color = AppColors.info.withValues(alpha: 0.18),
    );
    canvas.drawCircle(p, r + 2.4 / z, Paint()..color = AppColors.surface);
    canvas.drawCircle(p, r, Paint()..color = AppColors.info);
  }

  void _paintLabels(
    Canvas canvas,
    MapProjector project,
    double z,
    Rect view,
    String? focused,
    String? group,
  ) {

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
      old.focusOutline != focusOutline ||
      old.myPoint != myPoint ||
      !identical(old.units, units);
}

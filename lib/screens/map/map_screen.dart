import 'dart:math' as math;
import 'dart:ui' as ui show Image;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/favorites.dart';
import '../../data/korea_crs.dart' show Epsg5179, LatLng;
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart';
import '../../data/mock_region_ranking.dart' show MockTouristSpot;
import '../../data/user_location.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/drag_to_resize_handle.dart';
import '../../widgets/favorites_list.dart';
import '../../widgets/gap_index_info_dialog.dart';
import '../../widgets/my_location_button.dart';
import '../place/place_info_screen.dart';
import '../ranking/region_ranking_screen.dart';
import '../record/my_footprint_screen.dart';
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
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// "즐겨찾기" — slides a favorites list up *over* the bottom of the map and
  /// toggles the star pins on. The map keeps its full size and position. State
  /// lives in [Favorites.mapOverlayActive] so it carries across the vector ↔
  /// real-map 전환 (drilling into a region and stepping back).
  ValueNotifier<bool> get _favorites => Favorites.instance.mapOverlayActive;

  /// A favorite tapped in the slide-up list — the vector map pans/zooms here.
  /// [_favFocusTick] bumps on every tap so re-selecting the same spot still
  /// re-centres the map.
  LatLng? _favFocusPoint;
  int _favFocusTick = 0;

  /// Height of the 즐겨찾기 panel as a fraction of the body — the user drags its
  /// grip to resize it. [_favPanelResizing] drops the slide animation so the
  /// drag tracks the finger 1:1.
  double _favPanelFraction = 0.52;
  bool _favPanelResizing = false;

  void _focusFavorite(MockTouristSpot spot) {
    if (spot.lat == null || spot.lng == null) return;
    setState(() {
      _favFocusPoint = LatLng(spot.lat!, spot.lng!);
      _favFocusTick++;
    });
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
      body: _buildVectorBody(context),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).maybePop();
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFootprintScreen()),
            );
          }
          // * TODO: 랭킹 탭 — 해당 화면 구현 후 연결
        },
      ),
    );
  }

  /// Nationwide → 시도 → 시군구 → 구 vector drill-down. The map fills the whole
  /// body; the chrome (검색 바 + 갭지수 범례/설명) is a **translucent overlay**
  /// on its top, so the map stays visible behind it when dragged. "즐겨찾기"
  /// slides a favorites list up over the map's lower half.
  Widget _buildVectorBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyHeight = constraints.maxHeight;
        final panelHeight = bodyHeight * _favPanelFraction;
        return ValueListenableBuilder<bool>(
          valueListenable: _favorites,
          builder: (context, favoritesOpen, _) => Stack(
            children: [
              Positioned.fill(
                child: _KoreaMap(
                  favoritesActive: favoritesOpen,
                  onToggleFavorites: () => _favorites.value = !favoritesOpen,
                  overlayBottomInset: favoritesOpen ? panelHeight : 0,
                  topInset: kMapChromeInset,
                  focusPoint: _favFocusPoint,
                  focusTick: _favFocusTick,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _MapChrome(
                  onSearch: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration:
                    _favPanelResizing ? Duration.zero : AppMotion.standard,
                curve: AppMotion.curve,
                left: 0,
                right: 0,
                height: panelHeight,
                bottom: favoritesOpen ? 0 : -panelHeight,
                child: _FavoritesPanel(
                  onResizeStart: () =>
                      setState(() => _favPanelResizing = true),
                  onResize: (dy) => setState(() {
                    _favPanelFraction =
                        (_favPanelFraction - dy / bodyHeight).clamp(0.30, 0.80);
                  }),
                  onResizeEnd: () =>
                      setState(() => _favPanelResizing = false),
                  onFocusSpot: _focusFavorite,
                  onOpenDetail: (spot) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaceInfoScreen(spot: spot),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The search bar + 갭지수 범례/설명, laid over the top of the map like the
/// login screen's cards over its scene: **fully transparent behind** — each
/// control carries its own opaque surface, the map shows through the gaps.
class _MapChrome extends StatelessWidget {
  const _MapChrome({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchBar(onTap: onSearch),
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
    );
  }
}

/// The favorites list as a floating panel laid over the map's lower half —
/// rounded top, top shadow, so it reads as sitting *on* the map. Its grip is
/// draggable to resize the panel (parent owns the height).
class _FavoritesPanel extends StatelessWidget {
  const _FavoritesPanel({
    required this.onResizeStart,
    required this.onResize,
    required this.onResizeEnd,
    required this.onFocusSpot,
    required this.onOpenDetail,
  });

  final VoidCallback onResizeStart;
  final ValueChanged<double> onResize;
  final VoidCallback onResizeEnd;
  final ValueChanged<MockTouristSpot> onFocusSpot;
  final ValueChanged<MockTouristSpot> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.modalOrBottomSheet,
      ),
      child: Column(
        children: [
          DragToResizeHandle(
            bordered: false,
            onDragStart: onResizeStart,
            onDrag: onResize,
            onDragEnd: onResizeEnd,
          ),
          Expanded(
            child: FavoritesList(
              onFocusSpot: onFocusSpot,
              onOpenDetail: onOpenDetail,
            ),
          ),
        ],
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

/// Compact "낮음 —— 높음" scale. Its own surface pill so it stays readable
/// floating over the map.
class _GapLegend extends StatelessWidget {
  const _GapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('낮음', style: AppTextStyles.caption),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 88,
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
      ),
    );
  }
}

/// Tappable "input" that opens `<지도>` search (지역명·장소명 → `<지역별 랭킹>`).
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.inputField),
      child: BackdropFilter(
        // Slight frost so the sea/land behind reads through the bar without
        // muddying the placeholder text.
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Material(
          color: AppColors.surface.withValues(alpha: 0.74),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
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

/// Default nationwide zoom: how much the map is scaled past "cover" (fills the
/// frame) at the un-drilled view. 1.0 = exactly fill; higher = bigger map, more
/// of the coastline cropped but reachable by dragging. **This is the knob for
/// "make the default map bigger".**
const double kMapZoom = 1.2;

/// Extra empty (sea) room the user can pan *past* the map's top & bottom
/// coastline before the drag stops — so e.g. dragging down to 제주 leaves a
/// gap between it and the bottom nav. **The knob for map top/bottom slack.**
const double kMapPanMarginV = 44;

/// Approx. height of the translucent chrome (검색 바 + 갭지수 범례) overlaid on
/// the map's top. The nationwide view keeps this much clear at the top so the
/// country sits below the chrome (but drags up behind it, faintly visible).
const double kMapChromeInset = 128;

/// Blank sea margin above & below the country in the nationwide view — equal
/// breathing room at the top (under the chrome) and bottom (over the nav bar).
const double kMapMarginV = 20;

/// Side length (≈ real metres) of the box the camera frames when a favorite is
/// tapped in the slide-up list — a 시군구-ish zoom that shows the spot with some
/// surrounding context, without advancing the drill stage.
const double _kFavoriteFocusMetres = 44000;

class _KoreaMap extends StatefulWidget {
  const _KoreaMap({
    required this.onEnterRegion,
    required this.favoritesActive,
    required this.onToggleFavorites,
    this.overlayBottomInset = 0,
    this.topInset = 0,
    this.focusPoint,
    this.focusTick = 0,
  });

  /// Called with a 시군구/구 code + name when the user taps a leaf region
  /// (a 군, a 자치구, or a 구 within a drilled 시) — `MapScreen` then swaps in
  /// the real tile map for it.
  final void Function(String regionCode, String regionName) onEnterRegion;

  /// Whether the 즐겨찾기 overlay (star pins) is on — parent-controlled so the
  /// split favorites list stays in sync with it.
  final bool favoritesActive;
  final VoidCallback onToggleFavorites;

  /// Lifts the bottom-corner overlay buttons this many px, so the favorites
  /// panel sliding up over the map doesn't cover them.
  final double overlayBottomInset;

  /// Clear space at the top taken by the translucent chrome overlay — the
  /// nationwide "home" view is nudged down by half this so the country sits
  /// below the chrome (not hidden behind it).
  final double topInset;

  /// A favorite chosen in the slide-up list — the camera pans/zooms to it at
  /// the current drill stage (no level change). Paired with [focusTick] which
  /// bumps on every pick so re-choosing the same spot still re-centres.
  final LatLng? focusPoint;
  final int focusTick;

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

  /// Widget-space size of the map box (the viewport), from the latest layout.
  Size _boxSize = Size.zero;

  /// The drawn canvas — the whole map at "cover" scale, so one axis overflows
  /// the viewport and the user can pan to the clipped coastline.
  Size _sceneSize = Size.zero;
  bool _didCentre = false;

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

  /// Projected scene-space point of the device position ([UserLocation]),
  /// kept in sync by the layout builder — the painter draws the dot there.
  final ValueNotifier<Offset?> _myPoint = ValueNotifier<Offset?>(null);

  /// Scene-space points of every favorited located spot, kept in sync by the
  /// layout builder when [widget.favoritesActive] — the painter draws stars.
  final ValueNotifier<List<Offset>> _favPoints =
      ValueNotifier<List<Offset>>(const []);

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onFavoritesChanged);
    UserLocation.position.addListener(_onLocation);
    UserLocation.ensure();
    ensureMyLocationImage();
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
    Favorites.instance.removeListener(_onFavoritesChanged);
    UserLocation.position.removeListener(_onLocation);
    _tc.removeListener(_onTransform);
    _tc.dispose();
    _animController.dispose();
    _scale.dispose();
    _viewport.dispose();
    _focusedSido.dispose();
    _focusedGroup.dispose();
    _myPoint.dispose();
    _favPoints.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_KoreaMap old) {
    super.didUpdateWidget(old);
    // A favorite was tapped in the slide-up list — fly there. Deferred a frame
    // so a first pick right after layout still has a projector to work with.
    if (widget.focusTick != old.focusTick && widget.focusPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusOnLatLng(widget.focusPoint!);
      });
    }
    // Favorites list just closed — the extra bottom pan room goes away. If the
    // user had dragged the nationwide view up (to reach 제주 etc. past the
    // panel), ease it back to the default framing rather than leave it stranded
    // over where the panel was. Only at the un-drilled, un-zoomed view.
    if (old.overlayBottomInset > 0 &&
        widget.overlayBottomInset == 0 &&
        _focusedSido.value == null &&
        _scale.value < 1.05) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(_homeMatrix());
      });
    }
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {}); // refresh the star pins / removals
  }

  void _onLocation() {
    if (mounted) setState(() {}); // let the layout builder re-project the dot
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
    final project = _projector =
        MapProjector.cover(
      bounds: geo.bounds,
      viewport: size,
      overscan: kMapZoom,
      insetTop: widget.topInset + kMapMarginV,
      insetBottom: kMapMarginV,
    );
    _sceneSize = project.size;
    // First layout — centre the (oversized) map in the viewport.
    if (!_didCentre) {
      _didCentre = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tc.value = _homeMatrix();
      });
    }

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

  /// The nationwide "home" transform — scale 1, the canvas (which already bakes
  /// in the top/bottom sea margin) centred in the viewport.
  Matrix4 _homeMatrix() => Matrix4.identity()
    ..translateByDouble(
      -(_sceneSize.width - _boxSize.width) / 2,
      -(_sceneSize.height - _boxSize.height) / 2,
      0,
      1,
    );

  /// A transform that frames [rect] (scene space). [bottomInset] shrinks the
  /// area the region is centred in — used so a favorite tapped in the slide-up
  /// list lands in the map band still visible above the panel, not behind it.
  Matrix4 _matrixForSceneRect(Rect rect, {double bottomInset = 0}) {
    final w = _boxSize.width;
    final h = math.max(_boxSize.height - bottomInset, 1.0);
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

  void _zoomToSceneRect(Rect sceneRect, {double bottomInset = 0}) =>
      _animateTo(_matrixForSceneRect(sceneRect, bottomInset: bottomInset));

  void _zoomToRegion(GeoRegion region) {
    final project = _projector ??
        MapProjector.cover(
          bounds: _geo!.bounds,
          viewport: _boxSize,
          overscan: kMapZoom,
          insetTop: widget.topInset + kMapMarginV,
          insetBottom: kMapMarginV,
        );
    final b = region.bounds;
    _zoomToSceneRect(Rect.fromPoints(
      project(Offset(b.left, b.top)),
      project(Offset(b.right, b.bottom)),
    ));
  }

  /// Recentre on the device location (the "내 위치" button) — same ~44 km frame
  /// as a favorite pick, drill stage unchanged. No-op until a fix is known.
  void _goToMyLocation() {
    final here = UserLocation.position.value;
    if (here != null) _focusOnLatLng(here);
  }

  /// Pan/zoom the camera to a favorited spot picked in the slide-up list —
  /// a fixed ~44 km frame around it, drill stage unchanged.
  void _focusOnLatLng(LatLng where) {
    final project = _projector;
    if (project == null || _geo == null || _boxSize == Size.zero) return;
    final raw = Epsg5179.fromLatLng(where);
    const half = _kFavoriteFocusMetres / 2;
    _zoomToSceneRect(
      Rect.fromPoints(
        project(Offset(raw.dx - half, raw.dy - half)),
        project(Offset(raw.dx + half, raw.dy + half)),
      ),
      bottomInset: widget.overlayBottomInset,
    );
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
    _animateTo(_homeMatrix());
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
        final stats = statsForRegion(r.id);
        units.add(_MapUnit(
          key: r.id,
          leafId: r.id,
          title: r.title,
          path: path,
          labelPoint: proj(labelPoint[r.id] ?? r.bounds.center),
          gapIndex: stats.avgGapIndex,
          spotCount: stats.spotCount,
          memberCount: 1,
        ));
        return;
      }
      Path? union;
      var gapSum = 0, spotSum = 0, count = 0;
      var lx = 0.0, ly = 0.0;
      for (final r in members) {
        final path = _sigunguPaths[r.id];
        if (path == null) continue;
        union =
            union == null ? path : Path.combine(PathOperation.union, union, path);
        final stats = statsForRegion(r.id);
        gapSum += stats.avgGapIndex;
        spotSum += stats.spotCount;
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
        spotCount: spotSum,
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
          ? const ColoredBox(color: kMapSeaColor)
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
                // Keep the "내 위치" dot and 즐겨찾기 star pins glued to their
                // lat/lng across layout changes.
                final project = _projector!;
                final here = UserLocation.position.value;
                _myPoint.value =
                    here == null ? null : project(Epsg5179.fromLatLng(here));
                _favPoints.value = widget.favoritesActive
                    ? [
                        for (final f in Favorites.instance.locatedSpots())
                          project(Epsg5179.fromLatLng(
                            LatLng(f.spot.lat!, f.spot.lng!),
                          )),
                      ]
                    : const [];

                return ClipRect(
                  child: Stack(
                    children: [
                      // Sea behind the land — also fills the pan slack past the
                      // coastline so dragging never shows the cream Scaffold.
                      const Positioned.fill(
                        child: ColoredBox(color: kMapSeaColor),
                      ),
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _tc,
                          constrained: false,
                          minScale: 1,
                          maxScale: _kMaxScale,
                          // Pannable sea beyond the top & bottom coastline.
                          // While the favorites list is up it also covers the
                          // map's lower part — add that height to the bottom so
                          // 전남·제주 can be dragged up clear of the panel and
                          // still tapped. The map itself never moves/resizes;
                          // only the allowed pan range grows.
                          boundaryMargin: EdgeInsets.only(
                            top: kMapPanMarginV,
                            bottom: kMapPanMarginV + widget.overlayBottomInset,
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _handleTap(d.localPosition),
                            child: CustomPaint(
                              size: _sceneSize,
                              painter: _KoreaMapPainter(
                                geo: geo,
                                project: _projector!,
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
                                myPin: myLocationImage,
                                showFavorites: widget.favoritesActive,
                                favPoints: _favPoints,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: AppMotion.standard,
                        curve: AppMotion.curve,
                        left: AppSpacing.sm,
                        bottom: AppSpacing.sm + widget.overlayBottomInset,
                        // IntrinsicWidth + stretch → both buttons take the
                        // wider one's width so they match.
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (UserLocation.position.value != null) ...[
                                MyLocationButton(onTap: _goToMyLocation),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              MapToggleButton(
                                icon: Symbols.star_rounded,
                                label: '즐겨찾기',
                                active: widget.favoritesActive,
                                onTap: widget.onToggleFavorites,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: AppMotion.standard,
                        curve: AppMotion.curve,
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm + widget.overlayBottomInset,
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
    required this.spotCount,
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

  /// Total 관광 스팟 수 across the unit (a solo 군/자치구, or every 구 of a
  /// merged 시) — shown as the label subtitle alongside [gapIndex].
  final int spotCount;

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
    required this.project,
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
    required this.myPin,
    required this.showFavorites,
    required this.favPoints,
  }) : super(
          repaint: Listenable.merge([
            scale,
            viewport,
            focusedSido,
            focusedGroup,
            myPoint,
            myPin,
            favPoints,
          ]),
        );

  final KoreaGeo geo;

  /// The exact projector the paths were built with (baked-in sea insets).
  final MapProjector project;

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

  /// Decoded `current_location.png` pin, or `null` while it's still loading
  /// (a plain dot is drawn until then).
  final ValueListenable<ui.Image?> myPin;

  /// "즐겨찾기" — draw an amber star pin at every favorited spot.
  final bool showFavorites;

  /// Scene-space positions of every favorited located spot.
  final ValueListenable<List<Offset>> favPoints;

  /// Scene-space rects of the label cards drawn this frame — a new card that
  /// would overlap one already placed is skipped (falls back to its bare name).
  final List<Rect> _labelRects = [];

  @override
  void paint(Canvas canvas, Size size) {
    final z = scale.value.clamp(1.0, _kMaxScale);
    final view = viewport.value;
    final focused = focusedSido.value;
    final group = focusedGroup.value;
    _labelRects.clear();

    canvas.drawShadow(
      focused != null && focusOutline != null ? focusOutline! : countryOutline,
      AppColors.textPrimary.withValues(alpha: 0.5),
      6,
      false,
    );

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
    _paintFavorites(canvas, z);
    _paintMyLocation(canvas, z, view);
  }

  /// Amber star pins for **every** favorited spot in the country (constant
  /// on-screen size ÷ z, white edge), matching the star pins on the real tile
  /// map. Not viewport-culled: whichever region the camera sits on, the other
  /// regions' favorites stay on the canvas and a small pan brings them in.
  void _paintFavorites(Canvas canvas, double z) {
    if (!showFavorites) return;
    final pts = favPoints.value;
    if (pts.isEmpty) return;
    final r = 7 / z;
    final edge = Paint()..color = AppColors.surface;
    final fill = Paint()..color = AppColors.secondaryAccent;
    for (final p in pts) {
      canvas.drawPath(_starPath(p, r + 2.4 / z), edge);
      canvas.drawPath(_starPath(p, r), fill);
    }
  }

  Path _starPath(Offset c, double rOuter) {
    final rInner = rOuter * 0.42;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? rOuter : rInner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  /// The "you are here" marker — the `current_location.png` pin (tip on the
  /// point), constant on-screen size (÷ z). Falls back to a blue dot while the
  /// image is still decoding.
  void _paintMyLocation(Canvas canvas, double z, Rect view) {
    final p = myPoint.value;
    if (p == null || !view.contains(p)) return;

    final img = myPin.value;
    if (img != null) {
      final h = 34 / z;
      final w = h * img.width / img.height;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(p.dx - w / 2, p.dy - h, w, h),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }

    final r = 6 / z;
    canvas.drawCircle(
      p,
      r * 2.8,
      Paint()..color = myLocationColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(p, r + 3 / z, Paint()..color = AppColors.surface);
    canvas.drawCircle(p, r, Paint()..color = myLocationColor);
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
      final name = kSidoShortName[label.id] ?? label.title;

      if (focused == null) {
        // Province names anchor the country view — always shown (short form);
        // the 갭지수·스팟 card is added only when it actually fits.
        _drawStatLabel(
          canvas,
          text: name,
          center: p,
          gapIndex: stats.avgGapIndex,
          spotCount: stats.spotCount,
          fontPx: 13 / z,
          region: region,
        );
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
      // Level 1 — one label per unit (the merged 시 name, or 군/자치구 name),
      // with the 갭지수·스팟 subtitle when it fits, else just the name.
      for (final u in units) {
        if (!view.contains(u.labelPoint)) continue;
        _drawStatLabel(
          canvas,
          text: u.title,
          center: u.labelPoint,
          gapIndex: u.gapIndex,
          spotCount: u.spotCount,
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
        _drawStatLabel(
          canvas,
          text: label.title.split(' ').last,
          center: p,
          gapIndex: stats.avgGapIndex,
          spotCount: stats.spotCount,
          fontPx: 12 / z,
          region: region,
        );
      }
    }
  }

  /// The "갭지수 N · 스팟 M" card when it fits inside the shape and clears the
  /// labels already placed; otherwise the bare region name (always — it anchors
  /// the view), and the card shows once you zoom in enough for it to fit.
  void _drawStatLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required int gapIndex,
    required int spotCount,
    required double fontPx,
    required Path region,
  }) {
    final drewCard = _drawLabel(
      canvas,
      text: text,
      center: center,
      gap: gapIndex,
      spotCount: spotCount,
      fontPx: fontPx,
      region: region,
    );
    if (!drewCard) {
      _drawLabel(
        canvas,
        text: text,
        center: center,
        gap: gapIndex,
        fontPx: fontPx,
        region: region,
        enforceFit: false,
      );
    }
  }

  bool _boxInside(Path region, Rect box) =>
      region.contains(box.topLeft) &&
      region.contains(box.topRight) &&
      region.contains(box.bottomLeft) &&
      region.contains(box.bottomRight);

  /// Draws [text] centred at [center] — but only if the label fits inside
  /// [region] at the current scale and doesn't collide with a label already
  /// placed this frame, so labels appear as you zoom in rather than piling up.
  /// Returns whether it drew.
  ///
  /// With [spotCount] the whole label is a solid card — surface fill + a
  /// gap-coloured frame + soft shadow — with the name over a coloured
  /// "갭지수 N · 스팟 M" line, so the numbers stay readable over any region.
  bool _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required int gap,
    required double fontPx,
    required Path region,
    int? spotCount,
    bool enforceFit = true,
  }) {
    if (spotCount == null) {
      final onDark =
          ThemeData.estimateBrightnessForColor(gapIndexColor(gap)) ==
              Brightness.dark;
      final fg = onDark ? AppColors.surface : AppColors.textPrimary;
      final halo =
          (onDark ? Colors.black : AppColors.surface).withValues(alpha: 0.55);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: fg,
            fontSize: fontPx,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: halo, blurRadius: fontPx * 0.4)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromCenter(
        center: center,
        width: tp.width * 1.1,
        height: tp.height * 1.2,
      );
      if (enforceFit && !_boxInside(region, box)) return false;
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      _labelRects.add(box);
      return true;
    }

    final accent = gapIndexAccent(gap);
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontPx,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          TextSpan(
            text: '\n갭지수 $gap',
            style: TextStyle(
              color: accent,
              fontSize: fontPx * 0.86,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: '  ·  스팟 $spotCount',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: fontPx * 0.86,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = fontPx * 0.55;
    final padV = fontPx * 0.4;
    final cardRect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    if (enforceFit && !_boxInside(region, cardRect.inflate(fontPx * 0.1))) {
      return false;
    }
    if (_labelRects.any((r) => r.overlaps(cardRect.inflate(fontPx * 0.1)))) {
      return false;
    }

    final rr = RRect.fromRectAndRadius(
      cardRect,
      Radius.circular(fontPx * 0.55),
    );
    canvas.drawShadow(
      Path()..addRRect(rr),
      Colors.black.withValues(alpha: 0.4),
      fontPx * 0.25,
      false,
    );
    canvas.drawRRect(rr, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fontPx * 0.1
        ..color = accent,
    );
    tp.paint(canvas, cardRect.topLeft + Offset(padH, padV));
    _labelRects.add(cardRect);
    return true;
  }

  @override
  bool shouldRepaint(_KoreaMapPainter old) =>
      old.geo != geo ||
      old.project != project ||
      old.sidoPaths != sidoPaths ||
      old.sigunguPaths != sigunguPaths ||
      old.countryOutline != countryOutline ||
      old.focusedSido != focusedSido ||
      old.focusedGroup != focusedGroup ||
      old.focusOutline != focusOutline ||
      old.myPoint != myPoint ||
      old.myPin != myPin ||
      old.showFavorites != showFavorites ||
      old.favPoints != favPoints ||
      !identical(old.units, units);
}

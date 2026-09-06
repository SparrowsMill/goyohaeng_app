import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/gap_index_info_dialog.dart';
import 'region_naver_map.dart';

/// `<지도>` (user_flow §6) — the whole country as a continuously zoomable
/// vector map drawn from `assets/maps/` GeoJSON. Reached via the "지도 열기"
/// button under the mill-home TOP 3 list and the 지도 bottom-nav tab.
///
/// Drill-down (tap, not zoom):
///   - 처음 : 시도 17개만, 평균 갭지수 색으로 채움
///   - 시도 탭 : 그 시도 하나만 시군구로 펼침 + 카메라 이동
///   - 시군구 탭 : 실제 지도(네이버맵)로 크로스페이드 ([RegionNaverMap])
///
/// The "갭지수란?" button opens the explainer; "전국 보기" clears the focus.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// The 시군구 the user has drilled into — `null` shows the vector map, set
  /// shows [RegionNaverMap] for that region (the two cross-fade).
  ({String code, String name})? _detail;

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
            AnimatedSwitcher(
              duration: AppMotion.modalTransition,
              switchInCurve: AppMotion.curve,
              switchOutCurve: AppMotion.curve,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _detail == null
                  ? _KoreaMap(
                      key: const ValueKey('vector'),
                      onEnterDetail: (code, name) =>
                          setState(() => _detail = (code: code, name: name)),
                    )
                  : RegionNaverMap(
                      key: ValueKey('region_${_detail!.code}'),
                      regionCode: _detail!.code,
                      regionName: _detail!.name,
                      onBack: () => setState(() => _detail = null),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _detail == null
                  ? '도를 누르면 시·군·구가 펼쳐져요'
                  : '지도의 장소를 눌러 자세히 살펴보세요',
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

class _KoreaMap extends StatefulWidget {
  const _KoreaMap({super.key, required this.onEnterDetail});

  /// Called with a 시군구 code + name when the user drills in far enough.
  final void Function(String regionCode, String regionName) onEnterDetail;

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

  /// The 시도 the user has tapped into — `null` shows just 시도 nationwide,
  /// set expands that one 시도 into its 시군구. Tapping a 시군구 while focused
  /// drills to the real map (`onEnterDetail`).
  final ValueNotifier<String?> _focusedSido = ValueNotifier<String?>(null);

  KoreaGeo? _geo;
  bool _sigunguRequested = false;

  /// Widget-space size of the map box, from the latest layout.
  Size _boxSize = Size.zero;

  /// Cached projected paths, rebuilt when [_boxSize] changes.
  Size? _pathsForSize;
  final Map<String, Path> _sidoPaths = {};
  final Map<String, Path> _sigunguPaths = {};
  Path _countryOutline = Path();

  /// Union of the focused 시도's 시군구 paths — its outer edge, used instead of
  /// the coarse `sido_boundary` polygon (the two files are simplified
  /// differently, so the 시도 outline otherwise floats off the 시군구 fills).
  /// Keyed by `"<sidoId>@<size>"` so it rebuilds on focus or layout change.
  Path? _focusOutline;
  String? _focusOutlineKey;

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
    final project = MapProjector(bounds: geo.bounds, size: size);

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

    _focusOutlineKey = null; // paths changed — force the focus outline to rebuild
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

  void _zoomToRegion(GeoRegion region) {
    final project = MapProjector(bounds: _geo!.bounds, size: _boxSize);
    final b = region.bounds;
    final sceneRect = Rect.fromPoints(
      project(Offset(b.left, b.top)),
      project(Offset(b.right, b.bottom)),
    );
    _animateTo(_matrixForSceneRect(sceneRect));
  }

  /// Focus one 시도: expand it to 시군구 and zoom the camera to it.
  void _focusSido(GeoRegion sido) {
    setState(() => _focusedSido.value = sido.id);
    _ensureSigungu();
    _zoomToRegion(sido);
  }

  /// Back to the nationwide 시도 view.
  void _resetView() {
    setState(() => _focusedSido.value = null);
    _animateTo(Matrix4.identity());
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
    final focused = _focusedSido.value;

    if (focused != null) {
      // Within the focused 시도: a 시군구 hit drills to the real map.
      if (geo.sigunguReady) {
        for (final r in geo.sigungu) {
          if (r.sidoId != focused) continue;
          if (_sigunguPaths[r.id]?.contains(scenePos) ?? false) {
            widget.onEnterDetail(r.id, r.title);
            return;
          }
        }
      }
      // Still inside the focused 시도 but 시군구 not ready yet — ignore.
      if (_sidoPaths[focused]?.contains(scenePos) ?? false) return;
    }

    // A 시도 hit: focus it, or unfocus if it's the one already focused.
    for (final r in geo.sido) {
      if (_sidoPaths[r.id]?.contains(scenePos) ?? false) {
        if (r.id == focused) {
          _resetView();
        } else {
          _focusSido(r);
        }
        return;
      }
    }

    // Tapped the sea / outside every 시도.
    if (focused != null) _resetView();
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
                              focusOutline: _focusOutline,
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
                          onTap: _resetView,
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

/// "전국 보기" pill — visible once the user has focused a 시도 or zoomed in.
class _ResetViewButton extends StatelessWidget {
  const _ResetViewButton({
    required this.scale,
    required this.focusedSido,
    required this.onTap,
  });

  final ValueListenable<double> scale;
  final ValueListenable<String?> focusedSido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scale, focusedSido]),
      builder: (context, child) {
        final visible = scale.value > 1.02 || focusedSido.value != null;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.standard,
          child: IgnorePointer(ignoring: !visible, child: child),
        );
      },
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
                const Icon(
                  Symbols.zoom_out_map_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '전국 보기',
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
    );
  }
}

/// Paints the 17 시도, and — once one is focused ([focusedSido]) — that 시도's
/// 시군구 on top, each filled by its 갭지수 color. The focused 시도 shows its
/// 시군구 place-names; the rest keep their 시도 name. All strokes / text sizes
/// are divided by the live zoom so they hold a constant on-screen weight.
class _KoreaMapPainter extends CustomPainter {
  _KoreaMapPainter({
    required this.geo,
    required this.sidoPaths,
    required this.sigunguPaths,
    required this.countryOutline,
    required this.scale,
    required this.viewport,
    required this.focusedSido,
    required this.focusOutline,
  }) : super(repaint: Listenable.merge([scale, viewport, focusedSido]));

  final KoreaGeo geo;
  final Map<String, Path> sidoPaths;
  final Map<String, Path> sigunguPaths;
  final Path countryOutline;
  final ValueListenable<double> scale;
  final ValueListenable<Rect> viewport;
  final ValueListenable<String?> focusedSido;

  /// Union of the focused 시도's 시군구 — drawn as that province's outline so
  /// it hugs the 시군구 fills. `null` when nothing is focused / not ready yet.
  final Path? focusOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final z = scale.value.clamp(1.0, 12.0);
    final view = viewport.value;
    final focused = focusedSido.value;
    final showSigungu = focused != null && geo.sigunguReady;

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

    // 시도 fills (base layer — always).
    for (final region in geo.sido) {
      final path = sidoPaths[region.id];
      if (path == null) continue;
      final stats = statsForRegion(region.id);
      canvas.drawPath(path, Paint()..color = gapIndexColor(stats.avgGapIndex));
    }

    // 시군구 fills for the focused 시도 only.
    if (showSigungu) {
      final sigunguStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 0.9 / z
        ..color = AppColors.surface.withValues(alpha: 0.85);

      for (final r in geo.sigungu) {
        if (r.sidoId != focused) continue;
        final path = sigunguPaths[r.id];
        if (path == null) continue;
        final stats = statsForRegion(r.id);
        canvas.drawPath(path, Paint()..color = gapIndexColor(stats.avgGapIndex));
        canvas.drawPath(path, sigunguStroke);
      }
    }

    // Outlines drawn last so they read over the 시군구 subdivisions.
    // `sido_boundary` and `sigungu_boundary` are generalised differently, so
    // while one 시도 is focused only *its* outline is drawn — from the 시군구
    // union ([focusOutline]) — and the other provinces' coarse outlines are
    // dropped rather than left as stray white lines that miss the fills.
    if (focused == null) {
      for (final path in sidoPaths.values) {
        canvas.drawPath(path, sidoStroke);
      }
    } else {
      canvas.drawPath(focusOutline ?? sidoPaths[focused] ?? Path(), sidoStroke);
    }

    _paintLabels(canvas, project, z, view, focused);
  }

  void _paintLabels(
    Canvas canvas,
    MapProjector project,
    double z,
    Rect view,
    String? focused,
  ) {
    // 시도 labels — every 시도 but the focused one (that one shows 시군구).
    for (final label in geo.sidoLabels) {
      if (label.id == focused) continue;
      final p = project(label.point);
      if (!view.contains(p)) continue;
      final stats = statsForRegion(label.id);
      _drawLabel(
        canvas,
        text: label.title,
        center: p,
        gap: stats.avgGapIndex,
        fontPx: 13 / z,
        opacity: 1,
        subtitle: focused == null
            ? '갭지수 ${stats.avgGapIndex} · 스팟 ${stats.spotCount}'
            : null,
      );
    }

    // 시군구 labels for the focused 시도.
    if (focused != null && geo.sigunguReady) {
      for (final label in geo.sigunguLabels) {
        if (label.sidoId != focused) continue;
        final p = project(label.point);
        if (!view.contains(p)) continue;
        final stats = statsForRegion(label.id);
        _drawLabel(
          canvas,
          text: label.title,
          center: p,
          gap: stats.avgGapIndex,
          fontPx: 12 / z,
          opacity: 1,
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    required int gap,
    required double fontPx,
    required double opacity,
    String? subtitle,
  }) {
    final onDark = ThemeData.estimateBrightnessForColor(gapIndexColor(gap)) ==
        Brightness.dark;
    final fg = (onDark ? AppColors.surface : AppColors.textPrimary)
        .withValues(alpha: opacity);
    final halo = (onDark ? Colors.black : AppColors.surface)
        .withValues(alpha: 0.55 * opacity);

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
    builder.paint(
      canvas,
      center - Offset(builder.width / 2, builder.height / 2),
    );
  }

  @override
  bool shouldRepaint(_KoreaMapPainter old) =>
      old.geo != geo ||
      old.sidoPaths != sidoPaths ||
      old.sigunguPaths != sigunguPaths ||
      old.countryOutline != countryOutline ||
      old.focusedSido != focusedSido ||
      old.focusOutline != focusOutline;
}

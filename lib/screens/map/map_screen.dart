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
import '../ranking/region_ranking_screen.dart';

/// `<지도>` (user_flow §6) — the whole country as a continuously zoomable
/// vector map drawn from `assets/maps/` GeoJSON. Reached via the "지도 열기"
/// button under the mill-home TOP 3 list and the 지도 bottom-nav tab.
///
/// Zoom levels of detail:
///   - 낮은 배율 : 시도 17개만, 평균 갭지수 색으로 채움
///   - 중간 배율 : 화면에 걸친 시도의 시군구 경계 + 시군구별 갭지수 색 추가
///   - 높은 배율 / 시군구 탭 : 상세 진입 (지금은 `<지역별 랭킹>` 스탠드인,
///     추후 실제 지도 SDK 크로스페이드)
///
/// The "갭지수란?" button opens the explainer; "전체 보기" resets the zoom.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _openRanking(BuildContext context, String regionCode, String regionName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegionRankingScreen(
          regionKey: regionCode,
          regionName: regionName,
        ),
      ),
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
            _KoreaMap(
              onEnterDetail: (code, name) => _openRanking(context, code, name),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '지도를 확대하면 시·군·구까지 살펴볼 수 있어요',
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

/// Zoom past this (max-axis scale) to reveal 시군구 boundaries + labels.
// TODO(tune): 실기기에서 조정.
const double _kSigunguInScale = 2.6;

/// Zoom past this — or tap a 시군구 while already this deep — to trigger the
/// detail step (`onEnterDetail`).
// TODO(tune): 실기기에서 조정.
const double _kDetailScale = 7.0;

/// 시군구 labels finish fading in by this scale.
const double _kSigunguLabelFull = 4.2;

class _KoreaMap extends StatefulWidget {
  const _KoreaMap({required this.onEnterDetail});

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

  KoreaGeo? _geo;
  bool _sigunguRequested = false;

  /// Widget-space size of the map box, from the latest layout.
  Size _boxSize = Size.zero;

  /// Cached projected paths, rebuilt when [_boxSize] changes.
  Size? _pathsForSize;
  final Map<String, Path> _sidoPaths = {};
  final Map<String, Path> _sigunguPaths = {};
  Path _countryOutline = Path();

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
    super.dispose();
  }

  void _onTransform() {
    _scale.value = _tc.value.getMaxScaleOnAxis();
    if (_boxSize != Size.zero) {
      final topLeft = _tc.toScene(Offset.zero);
      final bottomRight = _tc.toScene(_boxSize.bottomRight(Offset.zero));
      _viewport.value = Rect.fromPoints(topLeft, bottomRight);
    }
    _maybeLoadSigungu();
  }

  void _maybeLoadSigungu() {
    if (_sigunguRequested || _geo == null) return;
    if (_scale.value < _kSigunguInScale - 0.4) return;
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

  void _handleTap(Offset scenePos) {
    final geo = _geo;
    if (geo == null) return;
    final scale = _scale.value;

    if (scale >= _kSigunguInScale && geo.sigunguReady) {
      for (final r in geo.sigungu) {
        if (_sigunguPaths[r.id]?.contains(scenePos) ?? false) {
          if (scale >= _kDetailScale) {
            widget.onEnterDetail(r.id, r.title);
          } else {
            _zoomToRegion(r);
          }
          return;
        }
      }
    }
    for (final r in geo.sido) {
      if (_sidoPaths[r.id]?.contains(scenePos) ?? false) {
        _zoomToRegion(r);
        return;
      }
    }
  }

  void _resetView() => _animateTo(Matrix4.identity());

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
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: _ResetViewButton(
                          scale: _scale,
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

/// "전체 보기" pill — only visible once the user has zoomed in.
class _ResetViewButton extends StatelessWidget {
  const _ResetViewButton({required this.scale, required this.onTap});

  final ValueListenable<double> scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scale,
      builder: (context, value, child) {
        final visible = value > 1.02;
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
                  '전체 보기',
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

/// Paints the 시도 (always) and, past [_kSigunguInScale], the 시군구 of every
/// 시도 touching the viewport — each filled by its 갭지수 color. Place-name
/// labels cross-fade between the two levels. All strokes / text sizes are
/// divided by the live zoom so they hold a constant on-screen weight.
class _KoreaMapPainter extends CustomPainter {
  _KoreaMapPainter({
    required this.geo,
    required this.sidoPaths,
    required this.sigunguPaths,
    required this.countryOutline,
    required this.scale,
    required this.viewport,
  }) : super(repaint: Listenable.merge([scale, viewport]));

  final KoreaGeo geo;
  final Map<String, Path> sidoPaths;
  final Map<String, Path> sigunguPaths;
  final Path countryOutline;
  final ValueListenable<double> scale;
  final ValueListenable<Rect> viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final z = scale.value.clamp(1.0, 12.0);
    final view = viewport.value;

    canvas.drawShadow(
      countryOutline,
      AppColors.textPrimary.withValues(alpha: 0.5),
      6,
      false,
    );

    final project = MapProjector(bounds: geo.bounds, size: size);
    final showSigungu = z >= _kSigunguInScale && geo.sigunguReady;

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

    // 시군구 fills for 시도 overlapping the viewport.
    if (showSigungu) {
      final sigunguStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 0.9 / z
        ..color = AppColors.surface.withValues(alpha: 0.85);

      final activeSido = <String>{
        for (final s in geo.sido)
          if (_sceneBounds(project, s.bounds).overlaps(view)) s.id,
      };

      for (final r in geo.sigungu) {
        if (!activeSido.contains(r.sidoId)) continue;
        final path = sigunguPaths[r.id];
        if (path == null) continue;
        final stats = statsForRegion(r.id);
        canvas.drawPath(path, Paint()..color = gapIndexColor(stats.avgGapIndex));
        canvas.drawPath(path, sigunguStroke);
      }
    }

    // 시도 outlines drawn last so they read over the 시군구 subdivisions.
    for (final path in sidoPaths.values) {
      canvas.drawPath(path, sidoStroke);
    }

    _paintLabels(canvas, project, z, view, showSigungu);
  }

  void _paintLabels(
    Canvas canvas,
    MapProjector project,
    double z,
    Rect view,
    bool showSigungu,
  ) {
    // 시도 labels: full below the threshold, fading out approaching it.
    final sidoOpacity = (1 - (z - _kSigunguInScale * 0.7) /
            (_kSigunguInScale * 0.3))
        .clamp(0.0, 1.0);
    if (sidoOpacity > 0.02) {
      for (final label in geo.sidoLabels) {
        final stats = statsForRegion(label.id);
        _drawLabel(
          canvas,
          text: label.title,
          center: project(label.point),
          gap: stats.avgGapIndex,
          fontPx: 13 / z,
          opacity: sidoOpacity,
          subtitle: '갭지수 ${stats.avgGapIndex} · 스팟 ${stats.spotCount}',
        );
      }
    }

    // 시군구 labels: fade in from the threshold.
    if (showSigungu) {
      final sgOpacity = ((z - _kSigunguInScale) /
              (_kSigunguLabelFull - _kSigunguInScale))
          .clamp(0.0, 1.0);
      if (sgOpacity > 0.02) {
        for (final label in geo.sigunguLabels) {
          final p = project(label.point);
          if (!view.contains(p)) continue;
          final stats = statsForRegion(label.id);
          _drawLabel(
            canvas,
            text: label.title,
            center: p,
            gap: stats.avgGapIndex,
            fontPx: 11 / z,
            opacity: sgOpacity,
          );
        }
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

  Rect _sceneBounds(MapProjector project, Rect rawBounds) => Rect.fromPoints(
        project(Offset(rawBounds.left, rawBounds.top)),
        project(Offset(rawBounds.right, rawBounds.bottom)),
      );

  @override
  bool shouldRepaint(_KoreaMapPainter old) =>
      old.geo != geo ||
      old.sidoPaths != sidoPaths ||
      old.sigunguPaths != sigunguPaths ||
      old.countryOutline != countryOutline;
}

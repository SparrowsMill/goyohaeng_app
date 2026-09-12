import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/korea_crs.dart' show Epsg5179, LatLng;
import '../data/korea_map_geo.dart';
import '../data/mock_map_regions.dart'
    show gapIndexColor, kMapSeaColor, kSidoShortName, statsForRegion;
import '../data/user_location.dart';
import '../theme/app_colors.dart';
import 'my_location_button.dart';

/// A small 시도-level slice of the `<지도>` vector map — same 갭지수 colours —
/// cropped around the device's position ([UserLocation]) with the "you are
/// here" dot pinned at the centre. Falls back to the whole peninsula, fit,
/// until a position is known. Static (no gestures); used on the mill home.
class MiniKoreaMap extends StatefulWidget {
  const MiniKoreaMap({super.key});

  @override
  State<MiniKoreaMap> createState() => _MiniKoreaMapState();
}

class _MiniKoreaMapState extends State<MiniKoreaMap> {
  KoreaGeo? _geo;

  @override
  void initState() {
    super.initState();
    UserLocation.position.addListener(_rebuild);
    UserLocation.ensure();
    myLocationImage.addListener(_rebuild);
    ensureMyLocationImage();
    KoreaGeo.load().then((geo) {
      if (mounted) setState(() => _geo = geo);
    });
  }

  @override
  void dispose() {
    UserLocation.position.removeListener(_rebuild);
    myLocationImage.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    if (geo == null) {
      return const ColoredBox(color: kMapSeaColor);
    }
    return CustomPaint(
      painter: _MiniMapPainter(
        geo,
        UserLocation.position.value,
        myLocationImage.value,
      ),
      size: Size.infinite,
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.geo, this.myLatLng, this.pin);

  final KoreaGeo geo;
  final LatLng? myLatLng;
  final ui.Image? pin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = kMapSeaColor);

    final project = MapProjector(bounds: geo.bounds, size: size);
    final centre = Offset(size.width / 2, size.height / 2);
    final located = myLatLng != null;
    // Zoom in around the user; show the whole country while we don't know.
    final zoom = located ? 3.0 : 1.0;
    final focus = located
        ? project(Epsg5179.fromLatLng(myLatLng!))
        : project(geo.bounds.center);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);

    final fill = Paint();
    for (final region in geo.sido) {
      fill.color = gapIndexColor(statsForRegion(region.id).avgGapIndex);
      canvas.drawPath(_path(region, project), fill);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.surface
      ..strokeWidth = 1.2 / zoom;
    for (final region in geo.sido) {
      canvas.drawPath(_path(region, project), stroke);
    }
    canvas.restore();

    // 시도 names — placed with the crop transform applied manually so the text
    // stays a constant on-screen size.
    final frame = Offset.zero & size;
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    for (final label in geo.sidoLabels) {
      final at = centre + (project(label.point) - focus) * zoom;
      if (!frame.contains(at)) continue;
      tp.text = TextSpan(
        text: kSidoShortName[label.id] ?? label.title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          shadows: [Shadow(color: AppColors.surface, blurRadius: 3)],
        ),
      );
      tp.layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    if (located) {
      _paintPin(canvas, centre, 30);
    }
  }

  /// The "you are here" pin: [pin] asset with its tip at [tip], or a plain
  /// dot fallback while the image is still decoding.
  void _paintPin(Canvas canvas, Offset tip, double height) {
    final img = pin;
    if (img != null) {
      final w = height * img.width / img.height;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(tip.dx - w / 2, tip.dy - height, w, height),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    canvas.drawCircle(
      tip,
      13,
      Paint()..color = myLocationColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(tip, 8, Paint()..color = AppColors.surface);
    canvas.drawCircle(tip, 5.5, Paint()..color = myLocationColor);
  }

  Path _path(GeoRegion region, MapProjector project) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in region.rings) {
      if (ring.length < 2) continue;
      path.addPolygon([for (final pt in ring) project(pt)], true);
    }
    return path;
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.geo != geo || old.myLatLng != myLatLng || old.pin != pin;
}

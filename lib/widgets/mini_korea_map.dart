import 'package:flutter/material.dart';

import '../data/korea_map_geo.dart';
import '../data/mock_map_regions.dart'
    show gapIndexColor, kMapSeaColor, kSidoShortName, statsForRegion;
import '../theme/app_colors.dart';

/// A small 시도-level slice of the `<지도>` vector map — same 갭지수 colours —
/// fit to the whole peninsula. Static (no gestures); used on the mill home.
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
    KoreaGeo.load().then((geo) {
      if (mounted) setState(() => _geo = geo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    if (geo == null) {
      return const ColoredBox(color: kMapSeaColor);
    }
    return CustomPaint(
      painter: _MiniMapPainter(geo),
      size: Size.infinite,
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.geo);

  final KoreaGeo geo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = kMapSeaColor);

    final project = MapProjector(bounds: geo.bounds, size: size);
    final centre = Offset(size.width / 2, size.height / 2);
    const zoom = 1.0;
    final focus = project(geo.bounds.center);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);

    final fill = Paint();
    for (final region in geo.sido) {
      fill.color = gapIndexColor(statsForRegion(region.id).avgGapIndex);
      canvas.drawPath(_path(region, project), fill);
    }
    // 실제 `<지도>`의 시도 경계선(`_KoreaMapPainter.sidoStroke`)과 같은 두께 —
    // 두 화면이 같은 시도 폴리곤을 그리니 테두리도 맞춘다.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.surface
      ..strokeWidth = 1.6 / zoom;
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
  bool shouldRepaint(_MiniMapPainter old) => old.geo != geo;
}

import 'package:flutter/material.dart';

import '../data/korea_crs.dart' show Epsg5179, LatLng;
import '../data/korea_map_geo.dart';
import '../data/mock_map_regions.dart' show gapIndexColor, statsForRegion;
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
    KoreaGeo.load().then((geo) {
      if (mounted) setState(() => _geo = geo);
    });
  }

  @override
  void dispose() {
    UserLocation.position.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    if (geo == null) {
      return const ColoredBox(color: AppColors.appBackground);
    }
    return CustomPaint(
      painter: _MiniMapPainter(geo, UserLocation.position.value),
      size: Size.infinite,
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.geo, this.myLatLng);

  final KoreaGeo geo;
  final LatLng? myLatLng;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.appBackground);

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

    if (located) {
      canvas.drawCircle(
        centre,
        13,
        Paint()..color = myLocationColor.withValues(alpha: 0.22),
      );
      canvas.drawCircle(centre, 8, Paint()..color = AppColors.surface);
      canvas.drawCircle(centre, 5.5, Paint()..color = myLocationColor);
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
  bool shouldRepaint(_MiniMapPainter old) =>
      old.geo != geo || old.myLatLng != myLatLng;
}

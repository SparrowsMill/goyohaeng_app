import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/data/korea_crs.dart';
import 'package:goyohaeng_app/data/korea_map_geo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Known EPSG:5179 label points → expected WGS84 (from the sido_labels
  /// GeoJSON, cross-checked against a reference proj4 inverse-TM).
  const cases = <String, (Offset, LatLng)>{
    '서울': (Offset(955018.98, 1950397.56), LatLng(37.55182, 126.99076)),
    '부산': (Offset(1143421.94, 1691662.07), LatLng(35.21007, 129.07569)),
    '제주': (Offset(911879.61, 1488496.48), LatLng(33.38447, 126.55257)),
    '강원': (Offset(1070630.60, 1969823.14), LatLng(37.72529, 128.30149)),
  };

  test('Epsg5179.toLatLng matches reference values within ~1 m', () {
    cases.forEach((name, c) {
      final got = Epsg5179.toLatLng(c.$1);
      expect(got.lat, closeTo(c.$2.lat, 1e-5), reason: '$name lat');
      expect(got.lng, closeTo(c.$2.lng, 1e-5), reason: '$name lng');
    });
  });

  test('every 시도/시군구 label projects inside the Korean bbox', () async {
    final geo = await KoreaGeo.load();
    await geo.ensureSigungu();

    for (final label in [...geo.sidoLabels, ...geo.sigunguLabels]) {
      final ll = label.latLng;
      expect(ll.lat, inInclusiveRange(33.0, 39.0), reason: '${label.title} lat');
      expect(ll.lng, inInclusiveRange(124.0, 132.0),
          reason: '${label.title} lng');
    }
  });

  test('GeoRegion.latLngBounds is a sane, ordered box around its centre', () {
    final seoul = GeoRegion(
      id: '11',
      title: '서울',
      rings: [
        [
          const Offset(940000, 1930000),
          const Offset(970000, 1930000),
          const Offset(970000, 1965000),
          const Offset(940000, 1965000),
        ],
      ],
    );

    final b = seoul.latLngBounds;
    expect(b.southwest.lat, lessThan(b.northeast.lat));
    expect(b.southwest.lng, lessThan(b.northeast.lng));

    final c = seoul.centerLatLng;
    expect(c.lat, inInclusiveRange(b.southwest.lat, b.northeast.lat));
    expect(c.lng, inInclusiveRange(b.southwest.lng, b.northeast.lng));
    expect(c.lat, closeTo(37.55, 0.15));
    expect(c.lng, closeTo(126.99, 0.15));
  });
}

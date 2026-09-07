import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../data/favorites.dart';
import '../../data/korea_crs.dart' show Epsg5179;
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../data/user_location.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/my_location_button.dart';
import '../../widgets/spot_pin.dart';
import '../place/place_info_screen.dart';

/// The map half of `<지역별 랭킹>`: a real slippy map (VWorld tiles when
/// [vworldApiKey] is set, else just the region outline) with a pin per located
/// spot. Selecting a spot in the list flies the camera to it and highlights
/// its pin; tapping a pin calls [onMarkerTap].
///
/// When 즐겨찾기 mode is on, **every** favorited spot in the country is also
/// drawn as an amber star pin — not just this region's — so panning/zooming out
/// on the tile map keeps the national favorites picture continuous with `<지도>`.
class RegionSpotMap extends StatefulWidget {
  const RegionSpotMap({
    super.key,
    required this.regionCode,
    required this.spots,
    required this.selected,
    required this.onMarkerTap,
    this.mapController,
  });

  /// 행정구역 코드 (시군구 5자리).
  final String regionCode;
  final List<MockTouristSpot> spots;
  final MockTouristSpot? selected;
  final void Function(MockTouristSpot spot) onMarkerTap;

  /// Injected in tests to read/drive the camera; otherwise one is created.
  final MapController? mapController;

  @override
  State<RegionSpotMap> createState() => _RegionSpotMapState();
}

class _RegionSpotMapState extends State<RegionSpotMap> {
  late final Future<List<List<LatLng>>> _ringsFuture = _loadRings();
  late final MapController _map = widget.mapController ?? MapController();
  bool _ready = false;

  /// "즐겨찾기" filter — driven by [Favorites.mapOverlayActive], the shared
  /// toggle. When on, this region's favorited spots become amber star pins and
  /// the ranking list (which owns the visible toggle chip) narrows to them, so
  /// [widget.spots] is already the favorites-only set here. Stays in sync with
  /// `<지도>`: arrive with it on and the region opens filtered.
  ValueNotifier<bool> get _favorites => Favorites.instance.mapOverlayActive;
  bool get _showFavorites => _favorites.value;

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onChanged);
    _favorites.addListener(_onChanged);
    UserLocation.position.addListener(_onChanged);
    UserLocation.ensure();
  }

  @override
  void dispose() {
    Favorites.instance.removeListener(_onChanged);
    _favorites.removeListener(_onChanged);
    UserLocation.position.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<MockTouristSpot> get _located =>
      widget.spots.where((s) => s.hasLocation).toList();

  /// Every favorited located spot **outside** the spots this screen already
  /// plots — drawn as extra star pins in 즐겨찾기 mode so all regions' favorites
  /// show no matter which region the camera sits on.
  List<MockTouristSpot> get _otherFavorites {
    final here = widget.spots.map((s) => s.name).toSet();
    return [
      for (final f in Favorites.instance.locatedSpots())
        if (!here.contains(f.spot.name)) f.spot,
    ];
  }

  Future<List<List<LatLng>>> _loadRings() async {
    final geo = await KoreaGeo.load();
    await geo.ensureSigungu();
    for (final r in geo.sigungu) {
      if (r.id == widget.regionCode) {
        return [
          for (final ring in r.rings)
            [for (final p in ring) Epsg5179.toLatLng(p)],
        ];
      }
    }
    return const [];
  }

  @override
  void didUpdateWidget(RegionSpotMap old) {
    super.didUpdateWidget(old);
    final s = widget.selected;
    if (_ready && s != null && s.hasLocation && s != old.selected) {
      final zoom = _map.camera.zoom;
      _map.move(LatLng(s.lat!, s.lng!), zoom < 14 ? 14 : zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<LatLng>>>(
      future: _ringsFuture,
      builder: (context, snapshot) {
        final rings = snapshot.data;
        if (rings == null) {
          return const ColoredBox(color: AppColors.appBackground);
        }
        // The 즐겨찾기 toggle lives in the ranking list header below the map
        // (`_FavoritesOnlyChip`); this map just reflects the shared state.
        return _buildMap(rings);
      },
    );
  }

  Widget _buildMap(List<List<LatLng>> rings) {
    final allPoints = [for (final ring in rings) ...ring];
    final located = _located;

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        backgroundColor: AppColors.appBackground,
        minZoom: 6,
        maxZoom: 19,
        onMapReady: () {
          _ready = true;
          // Opened from search with a spot already chosen → centre on its pin.
          final s = widget.selected;
          if (s != null && s.hasLocation) {
            _map.move(LatLng(s.lat!, s.lng!), 15);
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
        ),
        // 즐겨찾기 모드로 들어오면 목록은 즐겨찾기만 남아 located가 1~2곳일 수
        // 있다 — 거기에 맞추면 과하게 확대된다. 그럴 땐 지역 경계 전체가
        // 한눈에 들어오게. (스팟은 목록에서 눌러 집중.)
        initialCameraFit: allPoints.isEmpty
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(
                  (_showFavorites || located.isEmpty)
                      ? allPoints
                      : [for (final s in located) LatLng(s.lat!, s.lng!)],
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
              ),
      ),
      children: [
        if (vworldTileUrl.isNotEmpty)
          TileLayer(
            urlTemplate: vworldTileUrl,
            userAgentPackageName: 'com.goyohaeng',
          ),
        if (rings.isNotEmpty)
          PolygonLayer(
            polygons: [
              for (final ring in rings)
                Polygon(
                  points: ring,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderColor: AppColors.primary,
                  borderStrokeWidth: 2,
                ),
            ],
          ),
        // Every other region's favorites, drawn under this region's own pins.
        if (_showFavorites)
          MarkerLayer(
            markers: [for (final s in _otherFavorites) _favMarker(s)],
          ),
        MarkerLayer(
          markers: [
            for (final spot in located)
              if (spot != widget.selected)
                _marker(spot, selected: false),
            // draw the selected one last so it sits on top
            if (widget.selected != null && widget.selected!.hasLocation)
              _marker(widget.selected!, selected: true),
          ],
        ),
        if (UserLocation.position.value != null)
          MarkerLayer(
            markers: [
              Marker(
                point: UserLocation.position.value!,
                width: 32,
                height: 32,
                child: const MyLocationDot(),
              ),
            ],
          ),
      ],
    );
  }

  /// A star pin for a favorite that belongs to another region — tapping it
  /// opens `<장소 정보>` (it isn't in this screen's ranked list).
  Marker _favMarker(MockTouristSpot spot) {
    return Marker(
      point: LatLng(spot.lat!, spot.lng!),
      width: 170,
      height: 34,
      alignment: Alignment.bottomCenter,
      child: SpotPin(
        label: spot.name,
        color: gapIndexColor(spot.gapIndex),
        selected: false,
        favorite: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
        ),
      ),
    );
  }

  Marker _marker(MockTouristSpot spot, {required bool selected}) {
    return Marker(
      point: LatLng(spot.lat!, spot.lng!),
      width: 170,
      height: selected ? 68 : 34,
      // The pin's tip sits on the geo point; name/label grow upward.
      alignment: Alignment.bottomCenter,
      child: SpotPin(
        label: spot.name,
        color: gapIndexColor(spot.gapIndex),
        selected: selected,
        // Star pin only while the 즐겨찾기 overlay is on; otherwise a normal
        // gap-coloured pin.
        favorite: _showFavorites && Favorites.instance.contains(spot.name),
        onTap: () => widget.onMarkerTap(spot),
      ),
    );
  }
}

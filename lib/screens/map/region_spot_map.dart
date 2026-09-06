import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../config/map_config.dart';
import '../../data/favorites.dart';
import '../../data/korea_crs.dart' show Epsg5179;
import '../../data/korea_map_geo.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../data/user_location.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/favorites_sheet.dart';
import '../../widgets/my_location_button.dart';
import '../../widgets/spot_pin.dart';

/// The map half of `<지역별 랭킹>`: a real slippy map (VWorld tiles when
/// [vworldApiKey] is set, else just the region outline) with a pin per located
/// spot. Selecting a spot in the list flies the camera to it and highlights
/// its pin; tapping a pin calls [onMarkerTap].
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

  /// The device's position, once "내 위치" has been tapped.
  LatLng? _myLocation;
  bool _locating = false;

  /// "즐겨찾기" toggle — this region's favorited spots become amber star pins
  /// (in place, no camera change) and the favorites list slides up.
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    Favorites.instance.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    Favorites.instance.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _toggleFavorites() {
    if (_showFavorites) {
      setState(() => _showFavorites = false);
      return;
    }
    setState(() => _showFavorites = true);
    showFavoritesSheet(context).then((_) {
      if (mounted) setState(() => _showFavorites = false);
    });
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final here = await UserLocation.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _myLocation = here;
    });
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치를 가져올 수 없어요. 위치 권한과 GPS를 확인해 주세요.')),
      );
      return;
    }
    if (_ready) {
      final zoom = _map.camera.zoom;
      _map.move(here, zoom < 15 ? 15 : zoom);
    }
  }

  List<MockTouristSpot> get _located =>
      widget.spots.where((s) => s.hasLocation).toList();

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
        return Stack(
          children: [
            _buildMap(rings),
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapToggleButton(
                    icon: Symbols.star_rounded,
                    label: '즐겨찾기',
                    active: _showFavorites,
                    onTap: _toggleFavorites,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MyLocationButton(
                    onTap: _goToMyLocation,
                    busy: _locating,
                  ),
                ],
              ),
            ),
          ],
        );
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
        initialCameraFit: allPoints.isEmpty
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(
                  located.isEmpty
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
        if (_myLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _myLocation!,
                width: 28,
                height: 28,
                child: const MyLocationDot(),
              ),
            ],
          ),
      ],
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

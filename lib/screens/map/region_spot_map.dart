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
import '../../theme/app_text_styles.dart';
import '../../widgets/favorites_sheet.dart';
import '../../widgets/my_location_button.dart';

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

  /// "즐겨찾기" toggle — also drops every favorited spot's star pin on the map.
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

  /// Favorited spots to pin: this region's list already covers its own, so
  /// only add favorites from *other* regions (deduped by name) when the
  /// toggle is on.
  List<MockTouristSpot> get _extraFavorites {
    if (!_showFavorites) return const [];
    final shown = {for (final s in _located) s.name};
    return [
      for (final f in Favorites.instance.locatedSpots())
        if (!shown.contains(f.spot.name)) f.spot,
    ];
  }

  void _toggleFavorites() {
    if (_showFavorites) {
      setState(() => _showFavorites = false);
      return;
    }
    setState(() => _showFavorites = true);

    // Frame the region's spots together with every favorite.
    final pts = <LatLng>[
      for (final s in _located) LatLng(s.lat!, s.lng!),
      for (final s in _extraFavorites) LatLng(s.lat!, s.lng!),
    ];
    if (_ready && pts.length > 1) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(AppSpacing.xxl),
        ),
      );
    } else if (_ready && pts.length == 1) {
      _map.move(pts.single, 13);
    }

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
            // Favorites pinned from other regions (toggle on) sit underneath.
            for (final spot in _extraFavorites) _marker(spot, selected: false),
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
      child: _SpotPin(
        label: spot.name,
        color: gapIndexColor(spot.gapIndex),
        selected: selected,
        // Star pins only while the 즐겨찾기 overlay is on; otherwise every
        // spot is a normal gap-coloured pin.
        favorite: _showFavorites && Favorites.instance.contains(spot.name),
        onTap: () => widget.onMarkerTap(spot),
      ),
    );
  }
}

/// A map pin tinted by the spot's 갭지수 colour, with its name above;
/// enlarged + filled-label when selected.
class _SpotPin extends StatelessWidget {
  const _SpotPin({
    required this.label,
    required this.color,
    required this.selected,
    required this.favorite,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;

  /// Favorited spots use a star glyph instead of the teardrop pin.
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Favorites are always the amber star; other pins keep their 갭지수 tint.
    final pinColor = favorite ? AppColors.secondaryAccent : color;
    final onColor =
        ThemeData.estimateBrightnessForColor(pinColor) == Brightness.dark
            ? AppColors.surface
            : AppColors.textPrimary;
    final size = selected ? 36.0 : 26.0;
    final glyph =
        favorite ? Symbols.star_rounded : Symbols.location_on_rounded;
    // A white-edged pin for contrast on light tiles.
    final pin = Stack(
      alignment: Alignment.center,
      children: [
        Icon(glyph, size: size + 4, color: AppColors.surface, fill: 1),
        Icon(glyph, size: size, color: pinColor, fill: 1),
      ],
    );

    return GestureDetector(
      // deferToChild (default): only the chip/icon absorb taps so the map
      // still gets pan/zoom gestures that start near a pin.
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the selected pin carries its name — keeps a cluster readable.
          if (selected) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pinColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: pinColor),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption
                    .copyWith(color: onColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 1),
          ],
          pin,
        ],
      ),
    );
  }
}

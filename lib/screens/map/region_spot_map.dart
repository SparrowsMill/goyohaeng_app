import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../config/map_config.dart';
import '../../data/korea_crs.dart' show Epsg5179;
import '../../data/korea_map_geo.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

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
        onMapReady: () => _ready = true,
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
      ],
    );
  }

  Marker _marker(MockTouristSpot spot, {required bool selected}) {
    return Marker(
      point: LatLng(spot.lat!, spot.lng!),
      width: 160,
      height: selected ? 66 : 52,
      alignment: Alignment.topCenter,
      child: _SpotPin(
        label: spot.name,
        selected: selected,
        onTap: () => widget.onMarkerTap(spot),
      ),
    );
  }
}

/// Orange map pin with the spot name above it; enlarged + filled when selected.
class _SpotPin extends StatelessWidget {
  const _SpotPin({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // deferToChild (default): only the chip/icon absorb taps so the map
      // still gets pan/zoom gestures that start near a pin.
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.secondaryAccent : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.secondaryAccent : AppColors.border,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: selected
                    ? AppColors.textOnPrimaryButton
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            Symbols.location_on_rounded,
            size: selected ? 34 : 24,
            color: AppColors.secondaryAccent,
            fill: 1,
          ),
        ],
      ),
    );
  }
}

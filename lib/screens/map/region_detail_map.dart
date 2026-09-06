import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../config/map_config.dart';
import '../../data/korea_crs.dart' show Epsg5179;
import '../../data/korea_map_geo.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../place/place_info_screen.dart';
import '../ranking/region_ranking_screen.dart';

/// The deepest `<지도>` level: once the user drills into a 군/자치구/구 on the
/// vector map, `MapScreen` cross-fades its map card to this — a real slippy
/// map (VWorld tiles when [vworldApiKey] is set, otherwise just the region
/// outline on the app background) with a pin per ranked tourist spot. Tapping
/// a pin opens `<장소 정보 페이지>`; "뒤로" returns to the vector map.
class RegionDetailMap extends StatefulWidget {
  const RegionDetailMap({
    super.key,
    required this.regionCode,
    required this.regionName,
    required this.onBack,
    this.aspectRatio = 0.92,
  });

  /// 행정구역 코드 (시군구 5자리).
  final String regionCode;
  final String regionName;
  final VoidCallback onBack;

  /// Kept equal to the vector map's box so the cross-fade doesn't resize.
  final double aspectRatio;

  @override
  State<RegionDetailMap> createState() => _RegionDetailMapState();
}

class _RegionDetailMapState extends State<RegionDetailMap> {
  late final List<MockTouristSpot> _spots = rankingForRegion(widget.regionCode);
  late final Future<List<List<LatLng>>> _ringsFuture = _loadRings();

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

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
    );
  }

  void _openRanking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegionRankingScreen(
          regionKey: widget.regionCode,
          regionName: widget.regionName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<List<List<LatLng>>>(
              future: _ringsFuture,
              builder: (context, snapshot) {
                final rings = snapshot.data;
                if (rings == null) {
                  return const ColoredBox(color: AppColors.appBackground);
                }
                return _buildMap(rings);
              },
            ),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: _MapPill(
                icon: Symbols.arrow_back_rounded,
                label: '뒤로',
                onTap: widget.onBack,
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: _MapPill(
                icon: Symbols.leaderboard_rounded,
                label: '${widget.regionName} 랭킹',
                onTap: _openRanking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<List<LatLng>> rings) {
    final allPoints = [for (final ring in rings) ...ring];
    final located = _spots.where((s) => s.hasLocation).toList();

    return FlutterMap(
      options: MapOptions(
        backgroundColor: AppColors.appBackground,
        minZoom: 6,
        maxZoom: 19,
        initialCameraFit: allPoints.isEmpty
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.all(AppSpacing.lg),
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
              Marker(
                point: LatLng(spot.lat!, spot.lng!),
                width: 120,
                height: 52,
                alignment: Alignment.topCenter,
                child: _SpotPin(
                  label: spot.name,
                  onTap: () => _openSpot(spot),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Orange map pin with the spot name above it.
class _SpotPin extends StatelessWidget {
  const _SpotPin({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Icon(Symbols.location_on_rounded,
              size: 24, color: AppColors.secondaryAccent, fill: 1),
        ],
      ),
    );
  }
}

/// Small floating pill button, matching the vector map's "전국 보기" control.
class _MapPill extends StatelessWidget {
  const _MapPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../config/map_config.dart';
import '../../data/korea_crs.dart';
import '../../data/korea_map_geo.dart';
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../place/place_info_screen.dart';
import '../ranking/region_ranking_screen.dart';

/// The real-map half of `<지도>`: once the user drills into a 시군구 on the
/// vector map, `MapScreen` cross-fades its map card to this — a NAVER map
/// centred on that 시군구 with a marker per ranked tourist spot. Tapping a
/// marker opens `<장소 정보 페이지>`; "전체 지도로" returns to the vector map.
class RegionNaverMap extends StatefulWidget {
  const RegionNaverMap({
    super.key,
    required this.regionCode,
    required this.regionName,
    required this.onBack,
    this.aspectRatio = 0.92,
  });

  /// 행정구역 코드 (시군구 5자리).
  final String regionCode;
  final String regionName;

  /// Return to the vector map.
  final VoidCallback onBack;

  /// Kept equal to the vector map's box so the cross-fade doesn't resize.
  final double aspectRatio;

  @override
  State<RegionNaverMap> createState() => _RegionNaverMapState();
}

class _RegionNaverMapState extends State<RegionNaverMap> {
  late final List<MockTouristSpot> _spots = rankingForRegion(widget.regionCode);
  late final Future<GeoRegion?> _regionFuture = _loadRegion();

  Future<GeoRegion?> _loadRegion() async {
    final geo = await KoreaGeo.load();
    await geo.ensureSigungu();
    for (final r in geo.sigungu) {
      if (r.id == widget.regionCode) return r;
    }
    return null;
  }

  Future<void> _onMapReady(NaverMapController controller, GeoRegion? region) async {
    final located = _spots.where((s) => s.hasLocation).toList();

    final markers = <NMarker>{};
    for (var i = 0; i < located.length; i++) {
      final spot = located[i];
      final marker = NMarker(
        id: 'spot_$i',
        position: NLatLng(spot.lat!, spot.lng!),
        caption: NOverlayCaption(
          text: spot.name,
          color: AppColors.textPrimary,
          haloColor: AppColors.surface,
        ),
      )..setOnTapListener((_) => _openPlace(spot));
      markers.add(marker);
    }
    if (markers.isNotEmpty) await controller.addOverlayAll(markers);

    await controller.updateCamera(_framingCamera(located, region));
  }

  NCameraUpdate _framingCamera(List<MockTouristSpot> located, GeoRegion? region) {
    if (located.length >= 2) {
      return NCameraUpdate.fitBounds(
        NLatLngBounds.from(
          [for (final s in located) NLatLng(s.lat!, s.lng!)],
        ),
        padding: const EdgeInsets.all(AppSpacing.xxl),
      );
    }
    if (located.length == 1) {
      return NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(located.first.lat!, located.first.lng!),
        zoom: 12,
      );
    }
    if (region != null) {
      final b = region.latLngBounds;
      return NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(b.southwest.lat, b.southwest.lng),
          northEast: NLatLng(b.northeast.lat, b.northeast.lng),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
      );
    }
    return NCameraUpdate.scrollAndZoomTo(zoom: 10);
  }

  void _openPlace(MockTouristSpot spot) {
    if (!mounted) return;
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
            naverMapInitialized
                ? FutureBuilder<GeoRegion?>(
                    future: _regionFuture,
                    builder: (context, snapshot) {
                      final region = snapshot.data;
                      final center = region?.centerLatLng;
                      return NaverMap(
                        // Sits inside a SingleChildScrollView — let the map win
                        // the vertical drag gesture.
                        forceGesture: true,
                        options: NaverMapViewOptions(
                          initialCameraPosition: NCameraPosition(
                            target: center == null
                                ? const NLatLng(36.5, 127.85)
                                : NLatLng(center.lat, center.lng),
                            zoom: 10,
                          ),
                          scaleBarEnable: false,
                          logoAlign: NLogoAlign.leftBottom,
                        ),
                        onMapReady: (controller) =>
                            _onMapReady(controller, region),
                      );
                    },
                  )
                : const _NaverMapUnavailable(),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: _MapPill(
                icon: Symbols.arrow_back_rounded,
                label: '전체 지도로',
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
}

/// Shown on platforms without the NAVER Map SDK (desktop/web preview).
class _NaverMapUnavailable extends StatelessWidget {
  const _NaverMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSelected,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.map_rounded,
                  size: 32, color: AppColors.iconInactive),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '이 기기에서는 지도 미리보기를\n사용할 수 없어요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small floating pill button, matching the vector map's "전체 보기" control.
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

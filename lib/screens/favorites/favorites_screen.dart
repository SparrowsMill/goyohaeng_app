import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../config/map_config.dart';
import '../../data/favorites.dart';
import '../../data/mock_map_regions.dart' show gapIndexColor;
import '../../data/mock_region_ranking.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/my_location_button.dart';
import '../../widgets/spot_pin.dart';
import '../place/place_info_screen.dart';

/// `<즐겨찾기>` — a real tile map on top, the favorites list below (filterable
/// by 시/군/구), like `<지역별 랭킹>`.
///
/// Map pins:
///   - default / a list item picked : just that spot's ⭐ (camera flies to it)
///   - "즐겨찾기" 버튼 활성화 : every favorite's ⭐
///   - 활성화 해제 : back to the picked spot's ⭐ (the list stays put)
///
/// Back exits the screen (= leaves favorites mode).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.mapController});

  /// Injected in tests to read/drive the camera.
  final MapController? mapController;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final MapController _map = widget.mapController ?? MapController();
  bool _ready = false;

  MockTouristSpot? _selected;
  bool _showAll = false;

  /// `null` == 전체.
  String? _sigungu;

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
    if (!mounted) return;
    setState(() {
      // A removed favorite can't stay selected.
      if (_selected != null && !Favorites.instance.contains(_selected!.name)) {
        _selected = null;
      }
    });
    _fitMap();
  }

  List<MockTouristSpot> get _allLocated =>
      [for (final f in Favorites.instance.locatedSpots()) f.spot];

  /// Which favorites get a pin right now.
  List<MockTouristSpot> get _pinSpots {
    if (_showAll) return _allLocated;
    final sel = _selected;
    if (sel != null && sel.hasLocation) return [sel];
    return _allLocated;
  }

  void _select(MockTouristSpot spot) {
    setState(() => _selected = spot);
    if (_ready && spot.hasLocation) {
      final zoom = _map.camera.zoom;
      _map.move(LatLng(spot.lat!, spot.lng!), zoom < 14 ? 14 : zoom);
    }
  }

  void _toggleShowAll() {
    setState(() => _showAll = !_showAll);
    _fitMap();
  }

  void _fitMap() {
    if (!_ready) return;
    final pts = [for (final s in _pinSpots) LatLng(s.lat!, s.lng!)];
    if (pts.length > 1) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(AppSpacing.xxl),
        ),
      );
    } else if (pts.length == 1) {
      _map.move(pts.single, 14);
    }
  }

  void _openSpot(MockTouristSpot spot) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceInfoScreen(spot: spot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [for (final f in Favorites.instance.spots()) f.spot];
    final regions = <String>{for (final s in all) _sigunguOf(s)}.toList()..sort();
    final activeFilter =
        _sigungu != null && regions.contains(_sigungu) ? _sigungu : null;
    final listSpots = activeFilter == null
        ? all
        : [for (final s in all) if (_sigunguOf(s) == activeFilter) s];

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Symbols.arrow_back_rounded),
        ),
        title: Text('즐겨찾기 ${all.length}곳'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: _buildMap(),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (regions.length > 1)
            _SigunguFilter(
              regions: regions,
              selected: activeFilter,
              onChanged: (value) => setState(() => _sigungu = value),
            ),
          Expanded(child: _buildList(listSpots)),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }

  Widget _buildMap() {
    final pins = _pinSpots;
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            backgroundColor: AppColors.appBackground,
            minZoom: 6,
            maxZoom: 19,
            onMapReady: () {
              _ready = true;
              _fitMap();
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            initialCameraFit: pins.isEmpty
                ? null
                : CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(
                      [for (final s in pins) LatLng(s.lat!, s.lng!)],
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
            MarkerLayer(
              markers: [
                for (final spot in pins)
                  if (spot != _selected) _marker(spot, selected: false),
                if (_selected != null &&
                    _selected!.hasLocation &&
                    pins.contains(_selected))
                  _marker(_selected!, selected: true),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: MapToggleButton(
            icon: Symbols.star_rounded,
            label: '즐겨찾기',
            active: _showAll,
            onTap: _toggleShowAll,
          ),
        ),
      ],
    );
  }

  Marker _marker(MockTouristSpot spot, {required bool selected}) {
    return Marker(
      point: LatLng(spot.lat!, spot.lng!),
      width: 170,
      height: selected ? 68 : 34,
      alignment: Alignment.bottomCenter,
      child: SpotPin(
        label: spot.name,
        color: gapIndexColor(spot.gapIndex),
        selected: selected,
        favorite: true,
        onTap: () => _select(spot),
      ),
    );
  }

  Widget _buildList(List<MockTouristSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            '아직 즐겨찾기한 장소가 없어요.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      itemCount: spots.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _FavCard(
        spot: spots[i],
        selected: spots[i] == _selected,
        onTap: () => _select(spots[i]),
        onDetail: () => _openSpot(spots[i]),
      ),
    );
  }
}

/// "전주시" — 2nd address token, the 시/군/구 filter key.
String _sigunguOf(MockTouristSpot spot) {
  final parts = spot.address.split(' ');
  return parts.length > 1 ? parts[1] : parts.first;
}

class _SigunguFilter extends StatelessWidget {
  const _SigunguFilter({
    required this.regions,
    required this.selected,
    required this.onChanged,
  });

  final List<String> regions;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String? value})>[
      (label: '전체', value: null),
      for (final r in regions) (label: r, value: r),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.sm,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final on = selected == items[i].value;
          return Material(
            color: on ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => onChanged(items[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  items[i].label,
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: on
                        ? AppColors.textOnPrimaryButton
                        : AppColors.primaryPressed,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  const _FavCard({
    required this.spot,
    required this.selected,
    required this.onTap,
    required this.onDetail,
  });

  final MockTouristSpot spot;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final region = spot.address.split(' ').take(2).join(' ');
    return Material(
      color: selected ? AppColors.surfaceSelected : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(
                      color: gapIndexColor(spot.gapIndex),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$region · ${spot.category.label} · 갭지수 ${spot.gapIndex}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FavoriteStarButton(spotName: spot.name, size: 22),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.smallButton),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppRadius.smallButton),
                      onTap: onDetail,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '자세히 보기',
                              style: TextStyle(
                                color: AppColors.textOnPrimaryButton,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Symbols.arrow_forward_rounded,
                                size: 18,
                                color: AppColors.textOnPrimaryButton),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

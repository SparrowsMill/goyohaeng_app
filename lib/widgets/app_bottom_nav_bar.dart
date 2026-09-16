import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/map/map_screen.dart';
import '../screens/mill/mill_home_screen.dart';
import '../screens/ranking/ranking_screen.dart';
import '../screens/record/my_footprint_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The four tab-root screens, in nav-bar order. Tapping a tab always lands
/// here directly — never on whatever screen happened to be underneath it on
/// the stack — so navigation clears the stack down to a fresh instance of
/// the target tab instead of pushing/popping relative to the current route.
Widget _tabRootScreen(int index) {
  switch (index) {
    case 0:
      return const MillHomeScreen();
    case 1:
      return const MapScreen();
    case 2:
      return const RankingScreen();
    case 3:
    default:
      return const MyFootprintScreen();
  }
}

/// One nav-bar icon backed by an illustration asset in
/// `assets/illustrations/icon/`, sized to 34px.
class _NavAsset extends StatelessWidget {
  const _NavAsset(this.name, {required this.fallback, this.active = false});

  final String name;
  final IconData fallback;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Image.asset(
        'assets/illustrations/icon/$name.png',
        width: 34,
        height: 34,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallback,
          size: 34,
          color: active ? AppColors.iconActive : AppColors.iconInactive,
        ),
      ),
    );
  }
}

/// App-wide bottom navigation — CLAUDE.md §7 Bottom Navigation. Exactly the
/// four tabs defined there (no "마이" tab). Visual styling comes from
/// `AppTheme.light`'s `navigationBarTheme`; this widget only supplies the
/// destinations, selection, and the top divider the theme doesn't add.
///
/// Tapping a tab always navigates directly to that tab's screen, clearing
/// the navigation stack in the process — it never pops to whatever screen
/// happens to be underneath on the stack (which used to make some tabs look
/// like they went "back" instead of to the tapped tab). Tapping the tab
/// that's already active does the same thing — so from a screen pushed on
/// top of it (e.g. `<지역별 랭킹>`, `<장소 정보>`) it lands back on that tab's
/// own root screen, same as any other tab switch.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const double barHeight = 76;
  static const double topMargin = 8;
  static const double bottomMargin = 12;

  /// Extra scroll space beneath content covered by the floating navigation.
  static EdgeInsets scrollPadding(BuildContext context, EdgeInsets padding) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return padding.copyWith(
      bottom:
          padding.bottom +
          barHeight +
          topMargin +
          (safeBottom > bottomMargin ? safeBottom : bottomMargin),
    );
  }

  void _onDestinationSelected(BuildContext context, int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _tabRootScreen(index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, topMargin, 16, bottomMargin),
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  for (var index = 0; index < 4; index++)
                    Expanded(
                      child: ColoredBox(
                        color: index == currentIndex
                            ? AppColors.successBackground
                            : AppColors.surface,
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
            NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              child: NavigationBar(
                height: barHeight,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                selectedIndex: currentIndex,
                onDestinationSelected: (index) =>
                    _onDestinationSelected(context, index),
                destinations: const [
                  NavigationDestination(
                    icon: _NavAsset(
                      'spot_2',
                      fallback: Symbols.cottage_rounded,
                    ),
                    selectedIcon: _NavAsset(
                      'spot_2',
                      fallback: Symbols.cottage_rounded,
                      active: true,
                    ),
                    label: '방앗간',
                  ),
                  NavigationDestination(
                    icon: _NavAsset(
                      'map',
                      fallback: Symbols.location_on_rounded,
                    ),
                    selectedIcon: _NavAsset(
                      'map',
                      fallback: Symbols.location_on_rounded,
                      active: true,
                    ),
                    label: '지도',
                  ),
                  NavigationDestination(
                    icon: _NavAsset(
                      'ranking',
                      fallback: Symbols.emoji_events_rounded,
                    ),
                    selectedIcon: _NavAsset(
                      'ranking',
                      fallback: Symbols.emoji_events_rounded,
                      active: true,
                    ),
                    label: '랭킹',
                  ),
                  NavigationDestination(
                    icon: _NavAsset(
                      'diary',
                      fallback: Symbols.auto_stories_rounded,
                    ),
                    selectedIcon: _NavAsset(
                      'diary',
                      fallback: Symbols.auto_stories_rounded,
                      active: true,
                    ),
                    label: '기록',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

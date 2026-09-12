import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One nav-bar icon backed by an illustration asset in
/// `assets/illustrations/icon/`, sized to the §7 nav icon size (24px).
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
        width: 28,
        height: 28,
        errorBuilder: (context, error, stackTrace) => Icon(
          fallback,
          size: 24,
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
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: NavigationBarTheme(
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
          selectedIndex: currentIndex,
          onDestinationSelected: onTap ?? (_) {},
          destinations: const [
            NavigationDestination(
              icon: _NavAsset('spot_2', fallback: Symbols.cottage_rounded),
              selectedIcon: _NavAsset('spot_2',
                  fallback: Symbols.cottage_rounded, active: true),
              label: '방앗간',
            ),
            NavigationDestination(
              icon: _NavAsset('map', fallback: Symbols.location_on_rounded),
              selectedIcon: _NavAsset('map',
                  fallback: Symbols.location_on_rounded, active: true),
              label: '지도',
            ),
            NavigationDestination(
              icon: _NavAsset('ranking', fallback: Symbols.emoji_events_rounded),
              selectedIcon: _NavAsset('ranking',
                  fallback: Symbols.emoji_events_rounded, active: true),
              label: '랭킹',
            ),
            NavigationDestination(
              icon: _NavAsset('diary', fallback: Symbols.auto_stories_rounded),
              selectedIcon: _NavAsset('diary',
                  fallback: Symbols.auto_stories_rounded, active: true),
              label: '기록',
            ),
          ],
        ),
      ),
    );
  }
}

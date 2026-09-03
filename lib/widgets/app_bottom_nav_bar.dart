import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

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
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap ?? (_) {},
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.cottage_rounded),
            label: '방앗간',
          ),
          NavigationDestination(
            icon: Icon(Symbols.location_on_rounded),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Symbols.emoji_events_rounded),
            label: '랭킹',
          ),
          NavigationDestination(
            icon: Icon(Symbols.auto_stories_rounded),
            label: '기록',
          ),
        ],
      ),
    );
  }
}

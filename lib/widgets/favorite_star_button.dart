import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/favorites.dart';
import '../theme/app_colors.dart';

/// A star toggle for one place. Filled amber star when favorited, hollow
/// otherwise; tapping adds/removes it from [Favorites] and shows a brief
/// snackbar. Compact enough to sit in a card row or an app-bar action.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.spotName,
    this.size = 24,
  });

  final String spotName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Favorites.instance,
      builder: (context, _) {
        final on = Favorites.instance.contains(spotName);
        return Semantics(
          button: true,
          label: on ? '즐겨찾기 해제' : '즐겨찾기 추가',
          child: InkResponse(
            onTap: () {
              Favorites.instance.toggle(spotName);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 1200),
                    content: Text(on ? '즐겨찾기에서 뺐어요' : '즐겨찾기에 담았어요'),
                  ),
                );
            },
            radius: size,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                on ? Symbols.star_rounded : Symbols.star_outline_rounded,
                size: size,
                fill: on ? 1 : 0,
                color: on ? AppColors.secondaryAccent : AppColors.iconInactive,
              ),
            ),
          ),
        );
      },
    );
  }
}

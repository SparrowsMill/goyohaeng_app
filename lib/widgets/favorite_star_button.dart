import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../api/api.dart';
import '../data/favorites.dart';
import '../theme/app_colors.dart';

/// A star toggle for one place. Filled amber star when favorited, hollow
/// otherwise; tapping adds/removes it from [Favorites] and shows a brief
/// snackbar. Compact enough to sit in a card row or an app-bar action.
///
/// [placeId]가 있고 로그인 상태면 로컬 토글과 별개로 `POST`/`DELETE
/// /places/{id}/favorite`도 best-effort로 호출한다(스펙 §6.6–6.7). 로컬
/// [Favorites] 스토어가 여전히 화면의 즉시 반영 기준이므로, API 호출이 실패해도
/// 로컬 상태는 롤백하지 않고 실패 메시지만 스낵바로 보여준다.
class FavoriteStarButton extends StatelessWidget {
  const FavoriteStarButton({
    super.key,
    required this.spotName,
    this.size = 24,
    this.placeId,
  });

  final String spotName;
  final double size;
  final int? placeId;

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

              final id = placeId;
              if (id != null && AuthStore.instance.isSignedIn) {
                final call = on
                    ? PlaceService().removeFavorite(id)
                    : PlaceService().addFavorite(id);
                call.catchError((e) {
                  if (context.mounted && e is ApiException) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                  return FavoriteToggleResult(placeId: id, isFavorite: !on);
                });
              }
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

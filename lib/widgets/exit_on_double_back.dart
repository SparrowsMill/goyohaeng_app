import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

const Duration exitOnDoubleBackWindow = Duration(seconds: 2);

/// Shared "second press within [window] exits the app, first press just
/// shows a hint" handler for a screen sitting at the bottom of the
/// navigation stack (nothing left to pop, so a bare `PopScope(canPop: false)`
/// would otherwise trap the back button silently).
///
/// Call this from a `PopScope.onPopInvokedWithResult` once you've determined
/// this specific back-press attempt should be treated as "leave the app"
/// (as opposed to some other in-screen meaning, e.g. `map_screen.dart`'s
/// `_KoreaMap` zooming out a drill level first). [lastBackPress] is whatever
/// the caller had stored from the previous call (usually a `State` field);
/// the returned value replaces it.
DateTime? handleExitBackPress(
  BuildContext context,
  DateTime? lastBackPress, {
  Duration window = exitOnDoubleBackWindow,
}) {
  final now = DateTime.now();
  if (lastBackPress != null && now.difference(lastBackPress) < window) {
    SystemNavigator.pop();
    return lastBackPress;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '종료하려면 다시 누르세요',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textOnPrimaryButton,
          ),
        ),
        duration: window,
        backgroundColor: AppColors.textPrimary,
      ),
    );
  return now;
}

/// Wrap a bottom-nav tab's root [Scaffold] with this so the device's system
/// back (Android hardware/gesture back — not the in-app `AppBar` arrow) needs
/// two presses within [window] to exit the app, via [handleExitBackPress].
///
/// [AppBottomNavBar]'s tab switch (`_onDestinationSelected`) always does a
/// `pushAndRemoveUntil`, so whichever tab is open sits at the very bottom of
/// the navigation stack — pressing system back there has nothing left to pop,
/// and Flutter's default behaviour is to exit immediately. This intercepts
/// that so the tab roots need a confirming second press instead.
///
/// Only use this when nothing else on the screen already has its own
/// `PopScope` — Flutter requires *every* `PopScope` registered on a route to
/// report `canPop: true` before the route can pop, so a second, independent
/// `canPop: false` here would also fire this widget's snackbar on every back
/// press the other `PopScope` blocks for an unrelated reason (see
/// `map_screen.dart`'s `_KoreaMap`, which calls [handleExitBackPress]
/// directly from its own combined `PopScope` instead of using this widget).
class ExitOnDoubleBack extends StatefulWidget {
  const ExitOnDoubleBack({
    super.key,
    required this.child,
    this.window = exitOnDoubleBackWindow,
  });

  final Widget child;
  final Duration window;

  @override
  State<ExitOnDoubleBack> createState() => _ExitOnDoubleBackState();
}

class _ExitOnDoubleBackState extends State<ExitOnDoubleBack> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _lastBackPress = handleExitBackPress(
          context,
          _lastBackPress,
          window: widget.window,
        );
      },
      child: widget.child,
    );
  }
}

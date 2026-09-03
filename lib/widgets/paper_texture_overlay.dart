import 'package:flutter/material.dart';

/// Wraps [child] with a faint, tiled paper-grain texture over the whole
/// screen. Applied once via `MaterialApp.builder` in `main.dart` so every
/// screen — including dialogs and bottom sheets — gets it without any
/// per-screen wiring.
class PaperTextureOverlay extends StatelessWidget {
  const PaperTextureOverlay({super.key, required this.child});

  final Widget? child;

  /// Keep faint — this is a grain hint, not a visible pattern.
  static const _opacity = 0.20;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ?child,
        const Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity,
              child: Image(
                image: AssetImage('assets/branding/paper_texture.png'),
                repeat: ImageRepeat.repeat,
                fit: BoxFit.none,
                alignment: Alignment.topLeft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

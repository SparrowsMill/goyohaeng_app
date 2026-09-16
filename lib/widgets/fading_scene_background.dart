import 'package:flutter/material.dart';

/// Fades the bottom 30% of a scene into the screen background.
class FadingSceneBackground extends StatelessWidget {
  const FadingSceneBackground({
    super.key,
    required this.asset,
    required this.height,
    this.fit = BoxFit.fitWidth,
  });

  final String asset;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.7, 1],
        ).createShader(bounds),
        child: Image.asset(
          asset,
          height: height,
          width: double.infinity,
          fit: fit,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) =>
              SizedBox(height: height),
        ),
      ),
    );
  }
}

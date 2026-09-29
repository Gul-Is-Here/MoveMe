import 'package:flutter/material.dart';

/// A faint dot grid that fades out radially from [center] — ambient texture
/// behind the splash and auth screens. Wrap in `Opacity` to fade it in.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    required this.color,
    this.center = const Alignment(0, -0.15),
    this.radius = 0.85,
  });

  final Color color;
  final Alignment center;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => RadialGradient(
          center: center,
          radius: radius,
          colors: const [Colors.white, Colors.transparent],
        ).createShader(bounds),
        child: RepaintBoundary(
          child: CustomPaint(painter: _DotGridPainter(color: color)),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.07);
    for (var y = _spacing / 2; y < size.height; y += _spacing) {
      for (var x = _spacing / 2; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => old.color != color;
}

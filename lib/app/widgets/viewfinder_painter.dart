import 'package:flutter/material.dart';

/// Four rounded scanner-viewfinder brackets around the paint box, pushed
/// [gap] pixels outward — the "scan" motif shared by the splash and auth
/// screens. Animate [gap] toward 0 to have the brackets lock on.
class ViewfinderPainter extends CustomPainter {
  ViewfinderPainter({
    required this.gap,
    required this.color,
    this.arm = 20,
    this.radius = 8,
    this.strokeWidth = 3,
  });

  final double gap;
  final Color color;
  final double arm;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(gap);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    void corner(Offset c, double sx, double sy) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy + sy * arm)
          ..lineTo(c.dx, c.dy + sy * radius)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + sx * radius, c.dy)
          ..lineTo(c.dx + sx * arm, c.dy),
        paint,
      );
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant ViewfinderPainter old) =>
      old.gap != gap ||
      old.color != color ||
      old.arm != arm ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

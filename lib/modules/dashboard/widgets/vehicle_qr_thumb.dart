import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Decorative QR-style thumbnail for a vehicle card. Not a real scannable
/// code — the actual QR (FR-03) renders on the Vehicle Detail screen.
class VehicleQrThumb extends StatelessWidget {
  const VehicleQrThumb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.yellow, width: 2),
      ),
      child: Center(
        child: CustomPaint(size: const Size(34, 34), painter: QrGlyphPainter(color: AppColors.yellow)),
      ),
    );
  }
}

/// Stylised QR mark (three finder squares plus a few modules), drawn in a
/// 34x34 design grid scaled to the paint size.
class QrGlyphPainter extends CustomPainter {
  QrGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final s = size.width / 34;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * s, y * s, w * s, h * s);

    for (final corner in [r(2, 2, 10, 10), r(22, 2, 10, 10), r(2, 22, 10, 10)]) {
      canvas.drawRect(corner, stroke);
    }
    canvas.drawRect(r(5.5, 5.5, 3, 3), fill);
    canvas.drawRect(r(25.5, 5.5, 3, 3), fill);
    canvas.drawRect(r(5.5, 25.5, 3, 3), fill);

    canvas.drawRect(r(19, 19, 4, 4), fill);
    canvas.drawRect(r(26, 19, 4, 4), fill);
    canvas.drawRect(r(19, 26, 4, 4), fill);
    canvas.drawRect(r(28, 28, 4, 4), fill);
  }

  @override
  bool shouldRepaint(covariant QrGlyphPainter old) => old.color != color;
}

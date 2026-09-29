import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/motion.dart';

/// A photo slot: a dashed, accent-tinted drop zone while empty, and the
/// photo (with its [label] and a remove button) once filled. Swapping
/// between the two scales and fades rather than jumping.
class VehiclePhotoTile extends StatelessWidget {
  const VehiclePhotoTile({
    super.key,
    required this.label,
    this.imagePath,
    required this.onTap,
    this.onRemove,
    this.aspectRatio = 1,
    this.borderRadius = 14,
    this.emptyIcon = Icons.add_a_photo_outlined,
  });

  final String label;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  /// Width/height ratio of the tile — e.g. 1.586 for an ID-card (CR80)
  /// shaped box like an RC card or CNIC.
  final double aspectRatio;

  /// Corner radius in logical pixels.
  final double borderRadius;

  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imagePath != null;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: hasPhoto
            ? _FilledTile(
                key: ValueKey(imagePath),
                imagePath: imagePath!,
                label: label,
                borderRadius: borderRadius,
                onRemove: onRemove,
              )
            : Semantics(
                key: const ValueKey('empty'),
                button: true,
                label: label,
                child: Pressable(
                  onTap: onTap,
                  child: _EmptyTile(
                    label: label,
                    icon: emptyIcon,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({
    required this.label,
    required this.icon,
    required this.borderRadius,
  });

  final String label;
  final IconData icon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: accent.withValues(alpha: 0.6),
        radius: borderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.09),
              accent.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  color: accent,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilledTile extends StatelessWidget {
  const _FilledTile({
    super.key,
    required this.imagePath,
    required this.label,
    required this.borderRadius,
    this.onRemove,
  });

  final String imagePath;
  final String label;
  final double borderRadius;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ImageProvider image = imagePath.startsWith('http')
        ? NetworkImage(imagePath)
        : FileImage(File(imagePath));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Scrim so the label stays legible on any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              right: 10,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: Semantics(
                  button: true,
                  label: 'Remove $label',
                  child: Pressable(
                    onTap: onRemove,
                    scale: 0.85,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 7.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.8),
      Radius.circular(radius),
    );
    for (final PathMetric metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

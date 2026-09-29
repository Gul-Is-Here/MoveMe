import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/viewfinder_painter.dart';

/// Decorative, animated RC card: it floats with a slight 3D tilt while the
/// app's scanner viewfinder sweeps a scan line across it. A stylised card,
/// not a real document — it only illustrates what "scan the RC card" means.
class RcCardIllustration extends StatefulWidget {
  const RcCardIllustration({super.key, this.width = 230});

  final double width;

  @override
  State<RcCardIllustration> createState() => _RcCardIllustrationState();
}

class _RcCardIllustrationState extends State<RcCardIllustration>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final cardWidth = widget.width;
    // CR80 ID-card proportions, like the real RC card.
    final cardHeight = cardWidth / 1.586;

    return ExcludeSemantics(
      child: SizedBox(
        width: cardWidth + 56,
        height: cardHeight + 72,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final phase = _loop.value * 2 * math.pi;
            final animating = _loop.isAnimating;
            final bob = 6 * math.sin(phase);
            final sweep = (1 - math.cos(phase * 2)) / 2;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Soft accent glow the card floats over.
                Container(
                  width: cardWidth * 1.1,
                  height: cardHeight * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 70,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Ground shadow — shrinks as the card rises.
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: cardWidth * (0.7 - bob / 120),
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, bob - 4),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateX(0.10 + 0.04 * math.sin(phase))
                      ..rotateY(-0.16 + 0.08 * math.cos(phase)),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Card(width: cardWidth, height: cardHeight),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ViewfinderPainter(
                              gap: 12 + 2 * math.sin(phase * 2),
                              color: accent,
                              arm: 22,
                              radius: 10,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        if (animating)
                          Positioned(
                            left: -8,
                            right: -8,
                            top: sweep * cardHeight - 1,
                            height: 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.8),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final line = AppColors.border;

    Widget bar(double w, {double h = 6, Color? color}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color ?? line,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Standard ID-card corner radius (3.18mm) at 96dpi.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height * 0.2,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, AppColors.accentDeep]),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              'VEHICLE REGISTRATION',
              style: AppTextStyles.overline.copyWith(
                color: Colors.white,
                fontSize: 8.5,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: height * 0.42,
                    height: height * 0.5,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: accent,
                      size: height * 0.24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        bar(width * 0.3, color: AppColors.ink.withValues(alpha: 0.7), h: 7),
                        const SizedBox(height: 7),
                        bar(width * 0.38),
                        const SizedBox(height: 6),
                        bar(width * 0.26),
                        const SizedBox(height: 6),
                        bar(width * 0.34),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // MRZ-style strip along the bottom edge.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                for (var i = 0; i < 9; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(child: bar(0, h: 4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

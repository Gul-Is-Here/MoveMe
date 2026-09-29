import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/dot_grid_background.dart';
import '../../../app/widgets/viewfinder_painter.dart';
import '../controllers/splash_controller.dart';

/// Launch screen. One [_SplashStageState._intro] timeline choreographs the
/// reveal — hazard stripes slide in, the logo lands, a scanner viewfinder
/// locks onto it and sweeps a scan line, then the wordmark and tagline rise
/// in. A second, looping [_SplashStageState._ambient] controller keeps the
/// screen alive afterwards (radar ripples, breathing glow, marching stripes,
/// loader) while [SplashController] decides where to route.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) => const _SplashStage();
}

/// Progress of [t] through the `[begin, end]` window of a timeline, eased.
double _span(double t, double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

class _SplashStage extends StatefulWidget {
  const _SplashStage();

  @override
  State<_SplashStage> createState() => _SplashStageState();
}

class _SplashStageState extends State<_SplashStage> with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect the OS "reduce motion" setting: show the settled end state.
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final ink = AppColors.ink;
    final wordmarkStyle = AppTextStyles.displayLg.copyWith(fontSize: 40, color: ink);
    final accentWordmarkStyle = wordmarkStyle.copyWith(color: accent);
    final taglineStyle = AppTextStyles.tagline.copyWith(color: AppColors.muted);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _ambient]),
        builder: (context, _) {
          final t = _intro.value;
          final loop = _ambient.value;
          final breath = 0.75 + 0.25 * math.sin(loop * 2 * math.pi);

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _span(t, 0.0, 0.5),
                child: DotGridBackground(color: ink),
              ),
              _HazardStripe(
                alignTop: true,
                reveal: _span(t, 0.0, 0.35),
                march: loop,
              ),
              _HazardStripe(
                alignTop: false,
                reveal: _span(t, 0.0, 0.35),
                march: loop,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LogoStage(t: t, loop: loop, breath: breath, accent: accent),
                    const SizedBox(height: 8),
                    _Wordmark(
                      t: t,
                      style: wordmarkStyle,
                      accentStyle: accentWordmarkStyle,
                    ),
                    const SizedBox(height: 10),
                    _Tagline(t: t, style: taglineStyle, accent: accent),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: Opacity(
                  opacity: _span(t, 0.8, 1.0),
                  child: _Loader(loop: loop, accent: accent, track: ink),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo stage: glow, radar ripples, viewfinder and the logo itself.
// ---------------------------------------------------------------------------

class _LogoStage extends StatelessWidget {
  const _LogoStage({
    required this.t,
    required this.loop,
    required this.breath,
    required this.accent,
  });

  final double t;
  final double loop;
  final double breath;
  final Color accent;

  static const _stageSize = 230.0;

  @override
  Widget build(BuildContext context) {
    final landing = _span(t, 0.05, 0.45, Curves.easeOutBack);
    final settle = _span(t, 0.05, 0.45);
    final lockOn = _span(t, 0.15, 0.5, Curves.easeOutQuart);
    // Once the scan completes the viewfinder relaxes into the background.
    final relax = _span(t, 0.75, 0.95);

    return SizedBox.square(
      dimension: _stageSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: OverflowBox(
              maxWidth: 440,
              maxHeight: 440,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.2 * _span(t, 0.2, 0.7) * breath),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(_stageSize),
              painter: _RipplePainter(
                phase: loop,
                strength: _span(t, 0.45, 0.8),
                innerRadius: _Logo.size / 2 + 10,
                color: accent,
              ),
            ),
          ),
          Opacity(
            opacity: lockOn * (1 - 0.65 * relax),
            child: CustomPaint(
              size: const Size.square(_Logo.size + 28),
              painter: ViewfinderPainter(gap: 40 * (1 - lockOn), color: accent),
            ),
          ),
          Opacity(
            opacity: _span(t, 0.05, 0.3),
            child: Transform.rotate(
              angle: -0.14 * (1 - settle),
              child: Transform.scale(
                scale: 0.55 + 0.45 * landing,
                child: _Logo(
                  scan: _span(t, 0.42, 0.72, Curves.easeInOutSine),
                  accent: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.scan, required this.accent});

  /// 0 → 1 progress of the scan line down the logo.
  final double scan;
  final Color accent;

  static const size = 112.0;
  static const _beamHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 48,
            spreadRadius: -8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Applogo.png', fit: BoxFit.cover),
          if (scan > 0 && scan < 1)
            Positioned(
              left: 0,
              right: 0,
              top: scan * (size + _beamHeight) - _beamHeight,
              height: _beamHeight,
              child: Opacity(
                opacity: math.sin(math.pi * scan),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0),
                        accent.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.95),
                      ],
                      stops: const [0, 0.92, 1],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.phase,
    required this.strength,
    required this.innerRadius,
    required this.color,
  });

  final double phase;
  final double strength;
  final double innerRadius;
  final Color color;

  static const _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    for (var i = 0; i < _rings; i++) {
      final p = (phase + i / _rings) % 1;
      final fade = (1 - p) * (1 - p);
      canvas.drawCircle(
        center,
        innerRadius + p * (outerRadius - innerRadius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.45 * fade * strength),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.phase != phase || old.strength != strength || old.color != color;
}

// ---------------------------------------------------------------------------
// Type: letter-by-letter wordmark and word-by-word tagline.
// ---------------------------------------------------------------------------

class _Wordmark extends StatelessWidget {
  const _Wordmark({
    required this.t,
    required this.style,
    required this.accentStyle,
  });

  final double t;
  final TextStyle style;
  final TextStyle accentStyle;

  static const _letters = ['M', 'o', 'v', 'e', 'M', 'e'];

  @override
  Widget build(BuildContext context) {
    // Read as one word, not six letters.
    return Semantics(
      label: 'MoveMe',
      child: ExcludeSemantics(child: _letterRow()),
    );
  }

  Widget _letterRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _letters.length; i++)
          _RisingLetter(
            letter: _letters[i],
            style: i < 4 ? style : accentStyle,
            progress: _span(t, 0.45 + i * 0.045, 0.73 + i * 0.045),
          ),
      ],
    );
  }
}

class _RisingLetter extends StatelessWidget {
  const _RisingLetter({
    required this.letter,
    required this.style,
    required this.progress,
  });

  final String letter;
  final TextStyle style;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final blur = (1 - progress) * 8;
    Widget child = Text(letter, style: style);
    if (blur > 0.05) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      );
    }
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 22 * (1 - progress)),
        child: child,
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.t, required this.style, required this.accent});

  final double t;
  final TextStyle style;
  final Color accent;

  static const _words = ['Scan', 'Message', 'Move on'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Scan. Message. Move on.',
      child: ExcludeSemantics(child: _wordRow()),
    );
  }

  Widget _wordRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _words.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Builder(
            builder: (context) {
              final p = _span(t, 0.66 + i * 0.06, 0.88 + i * 0.06);
              return Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - p)),
                  child: Text.rich(
                    TextSpan(
                      text: _words[i],
                      style: style,
                      children: [
                        TextSpan(text: '.', style: TextStyle(color: accent)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ambient chrome: dot grid, hazard stripes, loader.
// ---------------------------------------------------------------------------

class _HazardStripe extends StatelessWidget {
  const _HazardStripe({
    required this.alignTop,
    required this.reveal,
    required this.march,
  });

  final bool alignTop;

  /// 0 → 1 slide-in from the side (top from the left, bottom from the right).
  final double reveal;

  /// 0 → 1 looping phase that walks the bands along, in opposite directions.
  final double march;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: alignTop ? 0 : null,
      bottom: alignTop ? null : 0,
      left: 0,
      right: 0,
      height: 10,
      child: FractionalTranslation(
        translation: Offset((1 - reveal) * (alignTop ? -1 : 1), 0),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _StripePainter(
              offset: (alignTop ? 1 : -1) * march * _StripePainter.period,
              background: AppColors.background,
              band: AppColors.yellow,
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({
    required this.offset,
    required this.background,
    required this.band,
  });

  final double offset;
  final Color background;
  final Color band;

  static const _bandWidth = 20.0;
  static const period = _bandWidth * 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()..color = band;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final start = -size.height - period + offset % period;
    for (double x = start; x < size.width + size.height; x += period) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + _bandWidth, 0)
        ..lineTo(x + _bandWidth, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) =>
      old.offset != offset || old.background != background || old.band != band;
}

class _Loader extends StatelessWidget {
  const _Loader({required this.loop, required this.accent, required this.track});

  final double loop;
  final Color accent;
  final Color track;

  static const _trackWidth = 132.0;
  static const _segmentWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    // Smooth back-and-forth glide across the track.
    final position = (1 - math.cos(loop * 2 * math.pi)) / 2;
    return Column(
      children: [
        Container(
          width: _trackWidth,
          height: 3,
          decoration: BoxDecoration(
            color: track.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: position * (_trackWidth - _segmentWidth)),
            child: Container(
              width: _segmentWidth,
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'GETTING THINGS READY',
          style: AppTextStyles.overline.copyWith(color: AppColors.faint),
        ),
      ],
    );
  }
}

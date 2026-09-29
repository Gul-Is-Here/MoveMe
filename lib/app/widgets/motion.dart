import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

/// A one-time staggered fade/rise on first build: [order] delays it in
/// 80ms steps, so a screen assembles top to bottom. Skipped entirely when
/// the OS asks for reduced motion.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.order, required this.child, this.distance = 18});

  final int order;
  final Widget child;
  final double distance;

  static const _step = 80;
  static const _travel = 520;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = order * _step;
    final total = delay + _travel;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, distance * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Shrinks [child] slightly while a finger is on it. Built on a raw
/// [Listener] so it never competes with the child's own tap handling (an
/// InkWell, a TextField) — and releases as soon as the touch turns into a
/// scroll.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  Offset? _downAt;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.onTap != null) {
      child = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return Listener(
      onPointerDown: (e) {
        _downAt = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_downAt != null && (e.position - _downAt!).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: child,
    );
  }
}

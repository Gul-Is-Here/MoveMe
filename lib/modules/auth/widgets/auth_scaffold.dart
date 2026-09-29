import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/dot_grid_background.dart';

/// Shared shell for Login and Sign Up: ambient glow + dot grid behind the
/// header, a scrollable column that still pins [footer] to the bottom when
/// there's room, and a staggered entrance — each of [children] (then the
/// footer) fades and rises in, one after another.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    required this.footer,
    this.gap = 28,
  });

  final List<Widget> children;
  final Widget footer;

  /// Vertical space between [children].
  final double gap;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 440,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _reveal,
                  curve: const Interval(0, 0.6, curve: Curves.easeOut),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DotGridBackground(
                      color: AppColors.ink,
                      center: const Alignment(0, -0.4),
                      radius: 0.9,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.45),
                          radius: 0.75,
                          colors: [
                            accent.withValues(alpha: 0.16),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _AuthRevealScope(
              animation: _reveal,
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < widget.children.length; i++) ...[
                            if (i > 0) SizedBox(height: widget.gap),
                            AuthReveal(index: i, child: widget.children[i]),
                          ],
                          const Spacer(),
                          SizedBox(height: widget.gap),
                          AuthReveal(
                            index: widget.children.length,
                            child: widget.footer,
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
      ),
    );
  }
}

class _AuthRevealScope extends InheritedWidget {
  const _AuthRevealScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_AuthRevealScope old) => old.animation != animation;
}

/// Fades and lifts [child] in as the enclosing [AuthScaffold]'s entrance
/// plays, staggered by [index]. Outside an [AuthScaffold] it's a no-op.
class AuthReveal extends StatelessWidget {
  const AuthReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// The enclosing [AuthScaffold]'s 0 → 1 entrance, for widgets that want to
  /// choreograph their own detail against it (e.g. the hero's viewfinder).
  static Animation<double>? animationOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AuthRevealScope>()
      ?.animation;

  @override
  Widget build(BuildContext context) {
    final animation = animationOf(context);
    if (animation == null) return child;

    final start = (index * 0.09).clamp(0.0, 0.55);
    final interval = Interval(start, start + 0.45, curve: Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = interval.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
        );
      },
    );
  }
}

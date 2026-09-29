import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/viewfinder_painter.dart';
import 'auth_scaffold.dart';

/// Centered header for the auth screens: the app logo framed by scanner
/// brackets that lock on as the screen enters (echoing the splash), then
/// the [title] with an accent full stop and a muted [subtitle].
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  static const _logoSize = 68.0;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final animation =
        AuthReveal.animationOf(context) ?? kAlwaysCompleteAnimation;
    final titleStyle = AppTextStyles.headingLg.copyWith(
      fontSize: 28,
      color: AppColors.ink,
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final v = animation.value;
            final pop = const Interval(
              0,
              0.5,
              curve: Curves.easeOutBack,
            ).transform(v);
            final lock = const Interval(
              0.1,
              0.6,
              curve: Curves.easeOutQuart,
            ).transform(v);

            return SizedBox.square(
              dimension: _logoSize + 40,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: const Size.square(_logoSize + 22),
                    painter: ViewfinderPainter(
                      gap: 22 * (1 - lock),
                      color: accent.withValues(alpha: 0.9 * lock),
                      arm: 14,
                      radius: 6,
                      strokeWidth: 2.5,
                    ),
                  ),
                  Transform.scale(scale: 0.7 + 0.3 * pop, child: _logo(accent)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        // The accent full stop is its own widget so [title] stays the
        // screen's exact, findable copy.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: titleStyle,
              ),
            ),
            Text('.', style: titleStyle.copyWith(color: accent)),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _logo(Color accent) {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 32,
            spreadRadius: -6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/Applogo.png', fit: BoxFit.cover),
    );
  }
}

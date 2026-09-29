import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/motion.dart';

/// Shared header for the Add Vehicle flow: a round back/close button and a
/// three-step tracker (Method -> Scan -> Details). On arrival the current
/// step's segment fills in, so moving between screens reads as progress.
class AddVehicleTopBar extends StatelessWidget {
  const AddVehicleTopBar({
    super.key,
    required this.step,
    required this.onLeading,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.leadingLabel = 'Back',
  });

  /// 0-based index of the current step.
  final int step;
  final VoidCallback onLeading;
  final IconData leadingIcon;
  final String leadingLabel;

  static const steps = ['Method', 'Scan', 'Details'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: leadingLabel,
          child: Pressable(
            onTap: onLeading,
            scale: 0.9,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(leadingIcon, color: AppColors.ink, size: 19),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _StepTracker(step: step)),
      ],
    );
  }
}

class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final steps = AddVehicleTopBar.steps;

    return Semantics(
      label: 'Step ${step + 1} of ${steps.length}: ${steps[step]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: AppColors.border),
                            if (i <= step)
                              // Earlier steps are already full; the current
                              // one sweeps in on arrival.
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: i < step ? 1 : 0, end: 1),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) => FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: t,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: LinearGradient(
                                        colors: [accent, AppColors.accentDeep],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  'STEP ${step + 1} OF ${steps.length}',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.faint,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[step],
                  style: AppTextStyles.label.copyWith(
                    color: accent,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

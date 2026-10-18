import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';

/// A round frosted button that flips between the light and dark theme. On
/// Auto it switches to the opposite of what is showing.
class AdminThemeToggle extends StatelessWidget {
  const AdminThemeToggle({super.key});

  static const size = 46.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Read so the button rebuilds when the mode changes.
      ThemeController.to.mode.value;
      final light = AppColors.isLight;
      return Semantics(
        button: true,
        label: light ? 'Switch to dark theme' : 'Switch to light theme',
        child: Pressable(
          scale: 0.9,
          onTap: () {
            HapticFeedback.selectionClick();
            ThemeController.to.setMode(light ? AppThemeMode.dark : AppThemeMode.light);
          },
          child: GlassPanel(
            padding: EdgeInsets.zero,
            radius: size / 2,
            expand: false,
            child: SizedBox(
              width: size,
              height: size,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween(begin: -0.25, end: 0.0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Icon(
                  light ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  key: ValueKey(light),
                  size: 22,
                  color: light ? GlassTokens.violet : const Color(0xFFFFB547),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Light / Dark / Auto on a frosted track, with a solid accent pill sliding
/// under the choice. [ThemeController] saves it and repaints every screen.
class AdminAppearancePicker extends StatelessWidget {
  const AdminAppearancePicker({super.key});

  static const _modes = [
    (mode: AppThemeMode.light, icon: Icons.light_mode_rounded, label: 'Light'),
    (mode: AppThemeMode.dark, icon: Icons.dark_mode_rounded, label: 'Dark'),
    (mode: AppThemeMode.system, icon: Icons.brightness_auto_rounded, label: 'Auto'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    return GlassPanel(
      padding: const EdgeInsets.all(6),
      child: Obx(() {
        final mode = ThemeController.to.mode.value;
        final index = _modes.indexWhere((m) => m.mode == mode);
        return SizedBox(
          height: 70,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segment = constraints.maxWidth / _modes.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: index * segment,
                    width: segment,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        color: accent,
                        boxShadow: [
                          BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5)),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final m in _modes)
                        Expanded(
                          child: _Option(
                            icon: m.icon,
                            label: m.label,
                            selected: m.mode == mode,
                            onTap: () {
                              if (m.mode != mode) HapticFeedback.selectionClick();
                              ThemeController.to.setMode(m.mode);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: fg,
                  letterSpacing: 0,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass.dart';
import 'motion.dart';

/// The rounded, bordered surface that groups content on a screen. Inside a
/// [GlassScope] (the admin side) it renders as a frosted [GlassPanel].
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = GlassScope.of(context)
        ? GlassPanel(padding: padding, child: child)
        : Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: Pressable(onTap: onTap, child: card),
    );
  }
}

/// Small uppercase label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: GlassScope.of(context) ? AppColors.muted : AppColors.faint),
      ),
    );
  }
}

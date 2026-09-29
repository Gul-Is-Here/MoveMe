import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// A titled, surface-colored card grouping related content — the form
/// sections of Add Vehicle's Review step and Edit Vehicle, and the info
/// groups on Vehicle Details.
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
    this.spacing = 16,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Vertical gap before each child.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 15.5),
                ),
              ),
              ?trailing,
            ],
          ),
          for (final child in children) ...[SizedBox(height: spacing), child],
        ],
      ),
    );
  }
}

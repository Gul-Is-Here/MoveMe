import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/glass.dart';
import 'admin_ui.dart';

/// A yes/no dialog for destructive admin actions. Resolves to true only
/// when the admin taps [confirmLabel].
class AdminConfirmDialog extends StatelessWidget {
  const AdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  static Future<bool> show({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = true,
  }) async {
    final result = await Get.dialog<bool>(
      AdminConfirmDialog(title: title, message: message, confirmLabel: confirmLabel, danger: danger),
      barrierColor: Colors.black.withValues(alpha: AppColors.isLight ? 0.2 : 0.5),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final accent = danger ? adminDanger : AppColors.yellow;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            decoration: BoxDecoration(
              color: GlassTokens.fillStrong,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: GlassTokens.rimHigh),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminIconBadge(
                  icon: danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                  color: accent,
                  size: 46,
                ),
                const SizedBox(height: 14),
                Text(title, style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
                const SizedBox(height: 6),
                Text(message, style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.buttonLabel.copyWith(color: AppColors.muted, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      style: TextButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(confirmLabel, style: AppTextStyles.buttonLabel.copyWith(color: accent, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

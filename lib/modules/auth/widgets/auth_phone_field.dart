import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'auth_field_shell.dart';

/// Pakistan-only phone entry: a fixed "+92" prefix plus the subscriber
/// number. FR-01 has no other country in scope, so the prefix is static
/// rather than a country picker.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final valueStyle = AppTextStyles.phoneValue.copyWith(color: AppColors.ink);

    return AuthFieldShell(
      label: 'Phone number',
      controller: controller,
      isComplete: (text) => text.trim().length == 10,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+92',
          style: valueStyle.copyWith(color: accent, fontWeight: FontWeight.w700),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        cursorColor: accent,
        style: valueStyle,
        decoration: authBareInputDecoration('300 1234567'),
      ),
    );
  }
}

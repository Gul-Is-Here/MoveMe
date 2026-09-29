import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'auth_field_shell.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.isComplete,
  });

  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  /// Restricts what can be typed or pasted into the field.
  final List<TextInputFormatter>? inputFormatters;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// When set, a check appears once this returns true for the text.
  final bool Function(String text)? isComplete;

  @override
  Widget build(BuildContext context) {
    return AuthFieldShell(
      label: label,
      helper: helper,
      controller: controller,
      isComplete: isComplete,
      leading: Icon(icon),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: AppColors.yellow,
        style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink),
        decoration: authBareInputDecoration(hint),
      ),
    );
  }
}

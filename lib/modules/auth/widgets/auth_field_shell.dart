import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Chrome shared by [AuthTextField] and [AuthPhoneField]: an uppercase
/// label (plus optional [helper]), and an input box that glows in the
/// accent while focused and shows a check once [isComplete] passes for the
/// current text of [controller].
class AuthFieldShell extends StatefulWidget {
  const AuthFieldShell({
    super.key,
    required this.label,
    required this.controller,
    required this.leading,
    required this.child,
    this.helper,
    this.isComplete,
  });

  final String label;
  final String? helper;
  final TextEditingController controller;

  /// Sits before the input — an icon (tinted by focus) or a prefix chip.
  final Widget leading;

  /// The bare, borderless input.
  final Widget child;

  final bool Function(String text)? isComplete;

  @override
  State<AuthFieldShell> createState() => _AuthFieldShellState();
}

class _AuthFieldShellState extends State<AuthFieldShell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final labelStyle = AppTextStyles.label.copyWith(
      color: _focused ? accent : AppColors.muted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label.toUpperCase(),
            style: labelStyle,
            children: widget.helper == null
                ? null
                : [
                    TextSpan(
                      text: '  ${widget.helper}',
                      style: labelStyle.copyWith(
                        color: AppColors.faint,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? accent : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _focused ? 0.18 : 0),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: _focused ? accent : AppColors.muted,
                  ),
                  child: widget.leading,
                ),
                const SizedBox(width: 12),
                Expanded(child: widget.child),
                if (widget.isComplete != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) => AnimatedScale(
                      scale: widget.isComplete!(value.text) ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Borderless decoration for the input inside an [AuthFieldShell]; the
/// vertical padding lets taps anywhere in the box's height hit the field.
InputDecoration authBareInputDecoration(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: AppTextStyles.manropeBase.copyWith(color: AppColors.faint),
  border: InputBorder.none,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(vertical: 16),
);

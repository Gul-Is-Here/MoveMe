import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Elevated surface that holds an auth form's fields and submit button.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// "New to MoveMe? Create an account" style link between Login and Sign Up.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.linkText.copyWith(color: AppColors.muted),
              children: [
                TextSpan(text: '$prompt '),
                TextSpan(
                  text: action,
                  style: AppTextStyles.linkTextEmphasis.copyWith(
                    color: AppColors.yellow,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Privacy reassurance pill plus the terms line, pinned under auth forms.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final captionStyle = AppTextStyles.caption;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'We never show your number to anyone who scans your car.',
                  style: captionStyle.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "By continuing you agree to MoveMe's Terms & Privacy Policy.",
          textAlign: TextAlign.center,
          style: captionStyle.copyWith(color: AppColors.faint),
        ),
      ],
    );
  }
}

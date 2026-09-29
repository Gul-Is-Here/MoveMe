import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset('assets/Applogo.png', width: 34, height: 34),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            style: AppTextStyles.headingSm.copyWith(color: AppColors.ink),
            children: [
              const TextSpan(text: 'Move'),
              TextSpan(text: 'Me', style: TextStyle(color: AppColors.yellow)),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/utils/auth_input.dart';
import '../controllers/signup_controller.dart';
import '../widgets/auth_form_parts.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_phone_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class SignUpView extends GetView<SignUpController> {
  const SignUpView({super.key});

  void _submit() {
    if (!controller.isSubmitting.value) controller.sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      footer: const AuthLegalFooter(),
      gap: 24,
      children: [
        const AuthHero(
          title: 'Create your account',
          subtitle: 'Just enough to tag your car and reach you. Verified with a '
              'one-time code, no password.',
        ),
        AuthFormCard(
          children: [
            AuthTextField(
              label: 'Full name',
              hint: 'e.g. Ayesha Khan',
              icon: Icons.person_outline_rounded,
              controller: controller.fullName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: nameInputFormatters,
            ),
            const SizedBox(height: 18),
            AuthPhoneField(
              controller: controller.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'CNIC',
              helper: '(required, for verification only)',
              hint: '42101-1234567-1',
              icon: Icons.badge_outlined,
              controller: controller.cnic,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              inputFormatters: cnicInputFormatters,
              // 13 digits + the two hyphens the formatter types in.
              isComplete: (text) => text.length == 15,
            ),
            const SizedBox(height: 22),
            Obx(
              () => AuthPrimaryButton(
                label: 'Send OTP',
                isLoading: controller.isSubmitting.value,
                onPressed: controller.sendOtp,
              ),
            ),
          ],
        ),
        AuthSwitchPrompt(
          prompt: 'Already have an account?',
          action: 'Log in',
          onTap: () => Get.offNamed(AppRoutes.login),
        ),
      ],
    );
  }
}

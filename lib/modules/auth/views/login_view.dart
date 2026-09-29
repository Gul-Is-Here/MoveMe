import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../controllers/login_controller.dart';
import '../widgets/auth_form_parts.dart';
import '../widgets/auth_hero.dart';
import '../widgets/auth_phone_field.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  void _submit() {
    if (!controller.isSubmitting.value) controller.sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      footer: const AuthLegalFooter(),
      children: [
        const AuthHero(
          title: 'Welcome back',
          subtitle: "Log in with your phone number. We'll text you a one-time code.",
        ),
        AuthFormCard(
          children: [
            AuthPhoneField(
              controller: controller.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
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
          prompt: 'New to MoveMe?',
          action: 'Create an account',
          onTap: () => Get.offNamed(AppRoutes.signUp),
        ),
      ],
    );
  }
}

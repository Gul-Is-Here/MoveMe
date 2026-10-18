import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../../app/utils/app_logger.dart';

class LoginController extends GetxController {
  final phone = TextEditingController();
  final isSubmitting = false.obs;

  final _authService = Get.find<AuthService>();

  bool get _isPhoneValid => phone.text.trim().length == 10;

  Future<void> sendOtp() async {
    if (!_isPhoneValid) {
      AppSnackbar.show('Check your number', 'Enter your 10-digit phone number.');
      return;
    }

    final e164Phone = '+92${phone.text.trim()}';
    isSubmitting.value = true;

    // FR-01.2: only a registered resident (or the admin) can log in —
    // anyone else is sent to sign up first.
    final PhoneLookup lookup;
    try {
      lookup = await _authService.lookupPhone(e164Phone);
    } catch (e, stack) {
      AppLogger.error('Login', e, stack);
      isSubmitting.value = false;
      AppSnackbar.show(
        'Could not reach the server',
        'Check your internet connection and try again.',
      );
      return;
    }
    if (lookup.blocked) {
      isSubmitting.value = false;
      AppSnackbar.show('Account blocked', 'This account has been blocked. Contact MoveMe if you think this is a mistake.');
      return;
    }
    if (!lookup.registered && !lookup.isAdmin) {
      isSubmitting.value = false;
      AppSnackbar.show('No account found', 'This number is not registered yet — please sign up first.');
      return;
    }

    await _authService.sendOtp(
      e164Phone: e164Phone,
      onCodeSent: (verificationId) {
        isSubmitting.value = false;
        Get.toNamed(
          AppRoutes.otp,
          arguments: {
            'phone': phone.text.trim(),
            'verificationId': verificationId,
            'mode': lookup.isAdmin ? 'admin' : 'login',
          },
        );
      },
      onError: (message) {
        isSubmitting.value = false;
        AppSnackbar.show('Could not send code', message);
      },
    );
  }

  @override
  void onClose() {
    phone.dispose();
    super.onClose();
  }
}

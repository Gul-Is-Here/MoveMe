import 'dart:async';

import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../widgets/app_snackbar.dart';
import 'auth_service.dart';

const _signedOutRoutes = {
  AppRoutes.splash,
  AppRoutes.onboarding,
  AppRoutes.login,
  AppRoutes.signUp,
  AppRoutes.otp,
};

/// Sends the user back to login when Firebase signs this device out on its
/// own — e.g. the admin blocked the account.
StreamSubscription<void> watchForcedSignOuts(AuthService authService) {
  return authService.forcedSignOuts.listen((_) {
    if (_signedOutRoutes.contains(Get.currentRoute)) return;
    Get.offAllNamed(AppRoutes.login);
    AppSnackbar.show(
      "You've been signed out",
      'This account was blocked or removed. Contact MoveMe if you think this is a mistake.',
    );
  });
}

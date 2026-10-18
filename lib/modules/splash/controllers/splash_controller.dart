import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/deep_link_service.dart';
import '../../../app/services/onboarding_service.dart';
import '../../../app/services/push_notification_service.dart';
import '../../../app/utils/app_logger.dart';

class SplashController extends GetxController {
  // The splash reveal runs ~2s; this leaves a brief beat on the settled
  // screen before routing away.
  static const _minDisplay = Duration(milliseconds: 2600);

  final _authService = Get.find<AuthService>();
  final _onboardingService = Get.find<OnboardingService>();
  final _pushService = Get.find<PushNotificationService>();
  final _deepLinkService = Get.find<DeepLinkService>();

  @override
  void onReady() {
    super.onReady();
    _proceed();
  }

  Future<void> _proceed() async {
    await Future.delayed(_minDisplay);

    // A signed-in resident always lands on Dashboard, regardless of
    // onboarding state — there's no point re-showing either screen once
    // they've already registered/logged in.
    if (_authService.isSignedIn) {
      // A token can be issued before this resident was signed in (fresh
      // install) or can rotate between app launches — keep it current.
      await _pushService.syncToken();

      // An order notification tapped while the app was closed.
      final pendingOrder = _pushService.consumePendingOrder();

      if (await _isAdmin()) {
        Get.offAllNamed(AppRoutes.admin);
        if (pendingOrder != null && pendingOrder.forAdmin) {
          Get.toNamed(AppRoutes.adminOrder, arguments: pendingOrder.number);
        }
        return;
      }

      // A QR/deep-link scan that arrived before routing was ready (app
      // cold-started straight from a tapped link) never gets silently
      // dropped — resolve it now and land directly in that chat instead of
      // just the home screen.
      final pendingScan = _deepLinkService.consumePendingVehicleScan();

      // Tapping a chat notification while the app was fully closed can't
      // navigate anywhere yet at that point (no GetMaterialApp) — it's
      // stashed instead, so pick it up now that routing is ready.
      final pendingThread = _pushService.consumePendingChatThread();

      Get.offAllNamed(AppRoutes.dashboard);
      if (pendingScan != null) {
        await _deepLinkService.resolveAndOpenChat(pendingScan);
      } else if (pendingThread != null) {
        Get.toNamed(AppRoutes.chatThread, arguments: pendingThread);
      } else if (pendingOrder != null && !pendingOrder.forAdmin) {
        Get.toNamed(AppRoutes.orderDetails, arguments: pendingOrder.number);
      }
      return;
    }

    final seenOnboarding = await _onboardingService.hasSeenOnboarding();
    Get.offAllNamed(seenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
  }

  Future<bool> _isAdmin() async {
    try {
      return await _authService.isAdmin();
    } catch (e, stack) {
      AppLogger.error('Splash', e, stack);
      return false;
    }
  }
}

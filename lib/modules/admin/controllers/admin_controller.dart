import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/push_notification_service.dart';
import '../../../app/widgets/app_snackbar.dart';

class AdminController extends GetxController {
  static const ordersTab = 0;
  static const usersTab = 1;
  static const profileTab = 2;

  final _authService = Get.find<AuthService>();
  final _pushService = Get.find<PushNotificationService>();

  final tabIndex = ordersTab.obs;
  final isSigningOut = false.obs;

  String get adminPhone => _authService.currentPhone ?? '';

  void changeTab(int index) => tabIndex.value = index;

  Future<void> signOut() async {
    if (isSigningOut.value) return;
    isSigningOut.value = true;
    await _pushService.unregisterToken();
    await _authService.signOut();
    Get.offAllNamed(AppRoutes.login);
    AppSnackbar.show('Signed out', "You've been signed out of the admin side.");
  }
}

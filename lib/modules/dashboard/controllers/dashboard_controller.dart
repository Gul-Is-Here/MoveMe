import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import 'inbox_controller.dart';

class DashboardController extends GetxController {
  static const tabCount = 3;

  final tabIndex = 0.obs;

  /// Unread state lives on the Inbox tab's controller, which already
  /// listens to the conversations collection — the nav bar reads it rather
  /// than opening a listener of its own.
  ///
  /// Resolved on demand and optional: the dashboard must still render if
  /// it is mounted without the Inbox (tests do this), and, after logout,
  /// `Get.offAllNamed` deletes the bindings while this bar is still
  /// painting its way off screen.
  InboxController? get _inbox =>
      Get.isRegistered<InboxController>() ? Get.find<InboxController>() : null;

  /// Whether there is an observable to read at all. The view checks this
  /// before wrapping the badge in `Obx`, since an `Obx` that reads no
  /// observable throws.
  bool get hasUnreadSource => _inbox != null;

  /// Total unread messages, for the Messages tab's badge.
  int get unreadMessageCount => _inbox?.unreadMessageCount ?? 0;

  void changeTab(int index) {
    if (index < 0 || index >= tabCount) return;
    tabIndex.value = index;
  }

  /// Starts the "Add vehicle" flow (RC card capture -> OCR, FR-02.1) — not
  /// to be confused with the QR scanner (top of the Home tab), which scans
  /// *another* car's MoveMe sticker to start a chat (FR-04).
  void openAddVehicle() {
    Get.toNamed(AppRoutes.addVehicleScan);
  }
}

import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/route_stack.dart';
import 'controllers/admin_user_controller.dart';

class AdminUserArgs {
  const AdminUserArgs({required this.uid, this.vehicleId});

  final String uid;

  /// The vehicle to open, highlight and scroll to.
  final String? vehicleId;
}

/// Links between the admin's users, vehicles and orders. Opening something
/// that is already open further back returns to it instead of stacking a
/// second copy.
abstract class AdminNav {
  static void openUser(String uid, {String? vehicleId}) {
    RouteStack.instance.openOrReturn(
      AppRoutes.adminUser,
      arguments: AdminUserArgs(uid: uid, vehicleId: vehicleId),
      sameTarget: (args) => args is AdminUserArgs && args.uid == uid,
    );
    if (vehicleId != null && Get.isRegistered<AdminUserController>(tag: uid)) {
      Get.find<AdminUserController>(tag: uid).focusVehicle(vehicleId);
    }
  }

  static void openOrder(String number) {
    RouteStack.instance.openOrReturn(AppRoutes.adminOrder, arguments: number, sameTarget: (args) => args == number);
  }
}

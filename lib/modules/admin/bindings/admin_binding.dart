import 'package:get/get.dart';

import '../controllers/admin_controller.dart';
import '../controllers/admin_order_controller.dart';
import '../controllers/admin_orders_controller.dart';
import '../admin_navigation.dart';
import '../controllers/admin_settings_controller.dart';
import '../controllers/admin_user_controller.dart';
import '../controllers/admin_users_controller.dart';

class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AdminController>(AdminController());
    Get.put<AdminSettingsController>(AdminSettingsController());
    Get.put<AdminOrdersController>(AdminOrdersController());
    Get.put<AdminUsersController>(AdminUsersController());
  }
}

class AdminOrderBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AdminOrderController(number: Get.arguments as String));
  }
}

class AdminUserBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments as AdminUserArgs;
    Get.put(
      AdminUserController(uid: args.uid, focusVehicleId: args.vehicleId),
      tag: args.uid,
    );
  }
}

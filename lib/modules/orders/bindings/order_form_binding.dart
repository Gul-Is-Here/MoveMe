import 'package:get/get.dart';

import '../controllers/order_form_controller.dart';

class OrderFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(OrderFormController(initialVehicleId: Get.arguments as String?));
  }
}

import 'package:get/get.dart';

import '../controllers/my_orders_controller.dart';
import '../controllers/order_details_controller.dart';

class OrderDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(OrderDetailsController(number: Get.arguments as String));
  }
}

class MyOrdersBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MyOrdersController());
  }
}

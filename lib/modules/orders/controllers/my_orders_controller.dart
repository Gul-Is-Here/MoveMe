import 'dart:async';

import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/order_service.dart';
import '../../../app/utils/app_logger.dart';

class MyOrdersController extends GetxController {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();

  final orders = <StickerOrder>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;

  StreamSubscription<List<StickerOrder>>? _sub;

  @override
  void onInit() {
    super.onInit();
    final uid = _authService.currentUid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    _sub = _orderService.watchMyOrders(uid).listen(
      (list) {
        orders.assignAll(list);
        hasError.value = false;
        isLoading.value = false;
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('MyOrders', e, s);
        hasError.value = true;
        isLoading.value = false;
      },
    );
  }

  void open(StickerOrder order) => Get.toNamed(AppRoutes.orderDetails, arguments: order.number);

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

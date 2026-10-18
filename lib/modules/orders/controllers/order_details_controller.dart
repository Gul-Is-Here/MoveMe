import 'dart:async';

import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/services/order_service.dart';
import '../../../app/utils/app_logger.dart';

/// Watches one order live, so status changes and the admin's note appear
/// while the customer is looking at it.
class OrderDetailsController extends GetxController {
  OrderDetailsController({required this.number});

  final String number;
  final _orderService = Get.find<OrderService>();

  final order = Rxn<StickerOrder>();
  final isLoading = true.obs;
  final notFound = false.obs;

  StreamSubscription<StickerOrder?>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _orderService.watchOrder(number).listen(
      (value) {
        order.value = value;
        notFound.value = value == null;
        isLoading.value = false;
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('OrderDetails', e, s);
        notFound.value = true;
        isLoading.value = false;
      },
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

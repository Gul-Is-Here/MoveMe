import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/services/order_service.dart';
import '../../../app/services/screen_security.dart';
import '../../../app/services/sticker_printer.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/widgets/app_snackbar.dart';
import 'admin_controller.dart';

/// One order on the admin side: check the payment, then set the status and
/// the note the customer sees.
class AdminOrderController extends GetxController {
  AdminOrderController({required this.number});

  final String number;
  final _orderService = Get.find<OrderService>();

  final order = Rxn<StickerOrder>();
  final isLoading = true.obs;
  final selectedStatus = Rxn<OrderStatus>();
  final note = TextEditingController();
  final noteError = RxnString();
  final isSaving = false.obs;

  StreamSubscription<StickerOrder?>? _sub;
  bool _formFilled = false;

  @override
  void onInit() {
    super.onInit();
    // Sticker QR codes are shown from this screen.
    ScreenSecurity.enable();
    _sub = _orderService
        .watchOrder(number)
        .listen(
          (value) {
            order.value = value;
            isLoading.value = false;
            // Fill the form once; later live updates must not wipe an edit.
            if (value != null && !_formFilled) {
              _formFilled = true;
              selectedStatus.value = value.status;
              note.text = value.note;
            }
          },
          onError: (Object e, StackTrace s) {
            AppLogger.error('AdminOrder', e, s);
            isLoading.value = false;
          },
        );
    note.addListener(() {
      if (note.text.trim().isNotEmpty) noteError.value = null;
    });
  }

  void selectStatus(OrderStatus status) {
    selectedStatus.value = status;
    if (!status.needsNote) noteError.value = null;
  }

  Future<void> save() async {
    final status = selectedStatus.value;
    if (status == null || isSaving.value) return;
    if (status.needsNote && note.text.trim().isEmpty) {
      noteError.value = 'Add a reason — tell the customer why.';
      return;
    }
    isSaving.value = true;
    try {
      await _orderService.updateOrderStatus(number, status: status, note: note.text.trim());
      if (Get.isRegistered<AdminController>()) {
        Get.find<AdminController>().changeTab(AdminController.ordersTab);
      }
      Get.back();
      AppSnackbar.show('Order updated', 'Order #$number is now ${status.label}.');
    } catch (e, s) {
      AppLogger.error('AdminOrder', e, s);
      AppSnackbar.show("Couldn't save the order", 'Check your connection and try again.');
    } finally {
      isSaving.value = false;
    }
  }

  /// The sticker job in flight ('pdf', or 'print:'/'image:' + vehicle id).
  final busyJob = RxnString();

  List<StickerPrint> get _allStickers => [
    for (final item in order.value?.items ?? const <OrderItem>[])
      StickerPrint(vehicleId: item.vehicleId, plateNumber: item.plateNumber, copies: item.quantity),
  ];

  String _fileName(Iterable<String> plates) => StickerPrinter.fileName(order.value?.customerName ?? '', plates);

  Future<void> _run(String job, Future<void> Function() action) async {
    if (busyJob.value != null) return;
    busyJob.value = job;
    try {
      await action();
    } catch (e, s) {
      AppLogger.error('AdminOrder', e, s);
      AppSnackbar.show("Couldn't make the sticker file", 'Please try again.');
    } finally {
      busyJob.value = null;
    }
  }

  /// Every sticker in the order, each repeated as many times as ordered.
  Future<void> shareOrderPdf() => _run('pdf', () async {
    final stickers = _allStickers;
    await StickerPrinter.sharePdf(stickers, name: _fileName(stickers.map((s) => s.plateNumber)));
  });

  Future<void> printSticker(OrderItem item) => _run('print:${item.vehicleId}', () async {
    await StickerPrinter.printStickers([
      StickerPrint(vehicleId: item.vehicleId, plateNumber: item.plateNumber, copies: item.quantity),
    ], name: _fileName([item.plateNumber]));
  });

  Future<void> shareStickerImage(OrderItem item) => _run('image:${item.vehicleId}', () async {
    await StickerPrinter.shareImage(
      StickerPrint(vehicleId: item.vehicleId, plateNumber: item.plateNumber),
      name: _fileName([item.plateNumber]),
    );
  });

  @override
  void onClose() {
    ScreenSecurity.disable();
    _sub?.cancel();
    note.dispose();
    super.onClose();
  }
}

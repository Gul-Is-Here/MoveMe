import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/services/order_service.dart';
import '../../../app/utils/app_logger.dart';
import '../admin_navigation.dart';

enum AdminOrderFilter {
  all('All'),
  toReview('To review'),
  inProgress('In progress'),
  closed('Rejected / cancelled');

  const AdminOrderFilter(this.label);

  final String label;

  bool matches(OrderStatus status) => switch (this) {
    all => true,
    toReview => status == OrderStatus.review,
    inProgress => status == OrderStatus.confirmed || status == OrderStatus.printing || status == OrderStatus.shipped,
    closed => status.isClosed,
  };
}

/// Digits only, without a leading 92/0 — so 0300 1234567, 92300…, +92300…
/// and 0092… all compare equal.
String normalizePhoneDigits(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) digits = digits.substring(4);
  if (digits.startsWith('92') && digits.length > 10) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return digits;
}

/// Letters and digits only, lower-case — "lea2231" finds LEA-2231.
String normalizePlate(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class AdminOrdersController extends GetxController {
  final _orderService = Get.find<OrderService>();

  final orders = <StickerOrder>[].obs;
  final isLoading = true.obs;
  final filter = AdminOrderFilter.all.obs;
  final query = ''.obs;
  final search = TextEditingController();

  StreamSubscription<List<StickerOrder>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _orderService.watchAllOrders().listen(
      (list) {
        orders.assignAll(list);
        isLoading.value = false;
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('AdminOrders', e, s);
        isLoading.value = false;
      },
    );
    search.addListener(() => query.value = search.text);
  }

  int get toReviewCount => orders.where((o) => o.status == OrderStatus.review).length;

  List<StickerOrder> get visible {
    final q = query.value.trim();
    return orders.where((o) => filter.value.matches(o.status) && (q.isEmpty || _matchesSearch(o, q))).toList();
  }

  static bool _matchesSearch(StickerOrder order, String q) {
    final lower = q.toLowerCase();
    if (order.number.toLowerCase().contains(lower)) return true;
    if (order.customerName.toLowerCase().contains(lower)) return true;
    final phoneDigits = normalizePhoneDigits(q);
    if (phoneDigits.length >= 3 && normalizePhoneDigits(order.customerPhone).contains(phoneDigits)) return true;
    final plate = normalizePlate(q);
    return plate.length >= 2 && order.items.any((i) => normalizePlate(i.plateNumber).contains(plate));
  }

  void open(StickerOrder order) => AdminNav.openOrder(order.number);

  @override
  void onClose() {
    _sub?.cancel();
    search.dispose();
    super.onClose();
  }
}

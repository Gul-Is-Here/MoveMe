import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/models/payment_account.dart';
import '../../../app/models/sticker_order.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/order_service.dart';
import '../../../app/services/vehicle_service.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/app_snackbar.dart';

/// A vehicle the customer can order stickers for.
class OrderableVehicle {
  const OrderableVehicle({required this.id, required this.plateNumber, required this.nickname});

  final String id;
  final String plateNumber;
  final String nickname;
}

/// The two-step sticker order: (1) stickers + delivery, (2) payment proof.
class OrderFormController extends GetxController {
  OrderFormController({this.initialVehicleId});

  /// The vehicle the order was started from; it begins at 1 sticker.
  final String? initialVehicleId;

  final _authService = Get.find<AuthService>();
  final _vehicleService = Get.find<VehicleService>();
  final _orderService = Get.find<OrderService>();
  final _picker = ImagePicker();

  final step = 0.obs;

  final vehicles = <OrderableVehicle>[].obs;
  final quantities = <String, int>{}.obs;
  final isLoadingVehicles = true.obs;
  final unitPrice = OrderService.defaultStickerPrice.obs;

  final fullName = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final postalCode = TextEditingController();
  final province = RxnString();

  final accounts = <PaymentAccount>[].obs;
  final isLoadingAccounts = true.obs;
  final selectedAccountId = RxnString();
  final screenshotPath = RxnString();

  final isPlacing = false.obs;

  /// 0-1 while the payment screenshot uploads.
  final uploadProgress = RxnDouble();

  final _subs = <StreamSubscription<Object?>>[];

  String get phone => _authService.currentPhone ?? '';

  int get stickerCount => quantities.values.fold(0, (total, q) => total + q);
  int get total => stickerCount * unitPrice.value;

  PaymentAccount? get selectedAccount =>
      accounts.firstWhereOrNull((a) => a.id == selectedAccountId.value);

  @override
  void onInit() {
    super.onInit();
    final uid = _authService.currentUid;
    if (uid == null) return;

    _subs.add(_vehicleService.watchVehicles(uid).listen(
      (list) {
        vehicles.assignAll(list.map(
          (v) => OrderableVehicle(
            id: v['id'] as String,
            plateNumber: v['plateNumber'] as String? ?? '',
            nickname: v['nickname'] as String? ?? '',
          ),
        ));
        for (final v in vehicles) {
          quantities.putIfAbsent(v.id, () => v.id == initialVehicleId ? 1 : 0);
        }
        quantities.removeWhere((id, _) => vehicles.every((v) => v.id != id));
        isLoadingVehicles.value = false;
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('OrderForm', e, s);
        isLoadingVehicles.value = false;
      },
    ));
    _subs.add(_orderService.watchStickerPrice().listen(
      (price) => unitPrice.value = price,
      onError: (Object e, StackTrace s) => AppLogger.error('OrderForm', e, s),
    ));
    _subs.add(_orderService.watchPaymentAccounts(activeOnly: true).listen(
      (list) {
        accounts.assignAll(list);
        if (selectedAccount == null) selectedAccountId.value = list.length == 1 ? list.first.id : null;
        isLoadingAccounts.value = false;
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('OrderForm', e, s);
        isLoadingAccounts.value = false;
      },
    ));
    _prefillName(uid);
  }

  Future<void> _prefillName(String uid) async {
    try {
      final profile = await _authService.fetchResidentProfile(uid);
      if (fullName.text.isEmpty) fullName.text = profile?['name'] as String? ?? '';
    } catch (e, s) {
      AppLogger.error('OrderForm', e, s);
    }
  }

  void increment(String vehicleId) => quantities[vehicleId] = (quantities[vehicleId] ?? 0) + 1;

  void decrement(String vehicleId) {
    final current = quantities[vehicleId] ?? 0;
    if (current > 0) quantities[vehicleId] = current - 1;
  }

  /// The first problem with step 1, or null when it's ready.
  String? stepOneProblem() {
    if (stickerCount == 0) return 'Add at least one sticker.';
    if (fullName.text.trim().length < 3) return 'Please enter your full name.';
    if (address.text.trim().length < 10) return 'Please enter your full address.';
    if (province.value == null) return 'Please choose your province.';
    if (city.text.trim().isEmpty) return 'Please enter your city.';
    if (!RegExp(r'^\d{5}$').hasMatch(postalCode.text.trim())) return 'Please enter a 5-digit postal code.';
    return null;
  }

  void next() {
    final problem = stepOneProblem();
    if (problem != null) {
      AppSnackbar.show('Check your order', problem);
      return;
    }
    step.value = 1;
  }

  void back() => step.value = 0;

  Future<void> copyAccountNumber(PaymentAccount account) async {
    await Clipboard.setData(ClipboardData(text: account.accountNumber));
    AppSnackbar.show('Number copied', 'Paste it in ${account.method} to send the payment.');
  }

  Future<void> pickScreenshot() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) screenshotPath.value = picked.path;
  }

  Future<void> placeOrder() async {
    if (isPlacing.value) return;
    final account = selectedAccount;
    if (account == null) {
      AppSnackbar.show('Choose an account', 'Pick the account you sent the payment to.');
      return;
    }
    final screenshot = screenshotPath.value;
    if (screenshot == null) {
      AppSnackbar.show('Add the payment screenshot', 'Upload a screenshot of your payment so we can check it.');
      return;
    }
    final uid = _authService.currentUid;
    if (uid == null) return;

    final order = StickerOrder(
      number: generateOrderNumber(),
      uid: uid,
      customerName: fullName.text.trim(),
      customerPhone: phone,
      items: [
        for (final v in vehicles)
          if ((quantities[v.id] ?? 0) > 0)
            OrderItem(vehicleId: v.id, plateNumber: v.plateNumber, nickname: v.nickname, quantity: quantities[v.id]!),
      ],
      unitPrice: unitPrice.value,
      delivery: OrderDelivery(
        fullName: fullName.text.trim(),
        phone: phone,
        address: address.text.trim(),
        province: province.value!,
        city: city.text.trim(),
        postalCode: postalCode.text.trim(),
      ),
      payment: OrderPayment(
        accountId: account.id,
        method: account.method,
        accountNumber: account.accountNumber,
        accountTitle: account.accountTitle,
        amount: total,
      ),
    );

    isPlacing.value = true;
    uploadProgress.value = 0;
    try {
      final placed = await _orderService.placeOrder(
        order,
        screenshotPath: screenshot,
        onUploadProgress: (p) => uploadProgress.value = p,
      );
      Get.offNamed(AppRoutes.orderDetails, arguments: placed.number);
      AppSnackbar.show(
        'Order #${placed.number}',
        "We'll check your ${account.method} payment, then print and send your stickers.",
      );
    } on PriceChangedException catch (e) {
      unitPrice.value = e.newPrice;
      AppSnackbar.show(
        'Price updated',
        'A sticker is now ${formatRupees(e.newPrice)}. Check the new total of ${formatRupees(total)} and send again.',
      );
    } catch (e, s) {
      AppLogger.error('OrderForm', e, s);
      AppSnackbar.show("Couldn't place the order", 'Check your connection and try again.');
    } finally {
      isPlacing.value = false;
      uploadProgress.value = null;
    }
  }

  @override
  void onClose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    fullName.dispose();
    address.dispose();
    city.dispose();
    postalCode.dispose();
    super.onClose();
  }
}

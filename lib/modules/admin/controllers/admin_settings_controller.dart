import 'dart:async';

import 'package:get/get.dart';

import '../../../app/models/payment_account.dart';
import '../../../app/services/order_service.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../widgets/admin_confirm_dialog.dart';
import '../widgets/payment_account_sheet.dart';
import '../widgets/sticker_price_sheet.dart';

/// The admin Profile tab's settings: sticker price and payment accounts.
class AdminSettingsController extends GetxController {
  final _orderService = Get.find<OrderService>();

  final stickerPrice = OrderService.defaultStickerPrice.obs;
  final accounts = <PaymentAccount>[].obs;
  final isLoadingAccounts = true.obs;

  /// The account whose switch or delete is in flight.
  final busyAccountId = RxnString();

  StreamSubscription<int>? _priceSub;
  StreamSubscription<List<PaymentAccount>>? _accountsSub;

  bool get hasActiveAccount => accounts.any((a) => a.active);

  @override
  void onInit() {
    super.onInit();
    _priceSub = _orderService.watchStickerPrice().listen(
      (price) => stickerPrice.value = price,
      onError: (Object e, StackTrace s) => AppLogger.error('AdminSettings', e, s),
    );
    _accountsSub = _orderService
        .watchPaymentAccounts(activeOnly: false)
        .listen(
          (list) {
            accounts.assignAll(list);
            isLoadingAccounts.value = false;
          },
          onError: (Object e, StackTrace s) {
            AppLogger.error('AdminSettings', e, s);
            isLoadingAccounts.value = false;
          },
        );
  }

  Future<void> changeStickerPrice() async {
    final price = await StickerPriceSheet.show(current: stickerPrice.value);
    if (price == null || price == stickerPrice.value) return;
    try {
      await _orderService.setStickerPrice(price);
      AppSnackbar.show('Price updated', 'New orders are now ${formatRupees(price)} per sticker.');
    } catch (e, s) {
      AppLogger.error('AdminSettings', e, s);
      AppSnackbar.show("Couldn't save the price", 'Check your connection and try again.');
    }
  }

  Future<void> addAccount() => _editAccount(null);

  Future<void> editAccount(PaymentAccount account) => _editAccount(account);

  Future<void> _editAccount(PaymentAccount? existing) async {
    final account = await PaymentAccountSheet.show(existing: existing);
    if (account == null) return;
    try {
      await _orderService.savePaymentAccount(account);
      AppSnackbar.show(
        existing == null ? 'Account added' : 'Account updated',
        account.active ? 'Customers can now pay into ${account.method}.' : 'It is hidden from customers.',
      );
    } catch (e, s) {
      AppLogger.error('AdminSettings', e, s);
      AppSnackbar.show("Couldn't save the account", 'Check your connection and try again.');
    }
  }

  Future<void> toggleActive(PaymentAccount account) async {
    if (busyAccountId.value != null) return;
    busyAccountId.value = account.id;
    try {
      await _orderService.savePaymentAccount(account.copyWith(active: !account.active));
    } catch (e, s) {
      AppLogger.error('AdminSettings', e, s);
      AppSnackbar.show("Couldn't update the account", 'Check your connection and try again.');
    } finally {
      busyAccountId.value = null;
    }
  }

  Future<void> deleteAccount(PaymentAccount account) async {
    final confirmed = await AdminConfirmDialog.show(
      title: 'Delete this account?',
      message:
          '${account.method} ${account.accountNumber} will no longer be shown to customers. '
          'Orders already paid into it keep their details.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    busyAccountId.value = account.id;
    try {
      await _orderService.deletePaymentAccount(account.id);
      AppSnackbar.show('Account deleted', '${account.method} ${account.accountNumber} was removed.');
    } catch (e, s) {
      AppLogger.error('AdminSettings', e, s);
      AppSnackbar.show("Couldn't delete the account", 'Check your connection and try again.');
    } finally {
      busyAccountId.value = null;
    }
  }

  @override
  void onClose() {
    _priceSub?.cancel();
    _accountsSub?.cancel();
    super.onClose();
  }
}

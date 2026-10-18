import 'dart:async';

import 'package:parktag_app/app/models/payment_account.dart';
import 'package:parktag_app/app/models/sticker_order.dart';
import 'package:parktag_app/app/services/order_service.dart';

class FakeOrderService implements OrderService {
  int price = OrderService.defaultStickerPrice;
  final List<PaymentAccount> accounts = [];
  int _accountSeq = 0;

  final _priceChanges = StreamController<int>.broadcast();
  final _accountChanges = StreamController<void>.broadcast();

  void _accountsChanged() => _accountChanges.add(null);

  /// Simulates the admin changing the price from another device.
  void changePriceRemotely(int newPrice) {
    price = newPrice;
    _priceChanges.add(newPrice);
  }

  @override
  Stream<int> watchStickerPrice() async* {
    yield price;
    yield* _priceChanges.stream;
  }

  @override
  Future<int> fetchStickerPrice() async => price;

  @override
  Future<void> setStickerPrice(int newPrice) async => changePriceRemotely(newPrice);

  List<PaymentAccount> _visible(bool activeOnly) =>
      accounts.where((a) => !activeOnly || a.active).toList()..sort((a, b) => a.method.compareTo(b.method));

  @override
  Stream<List<PaymentAccount>> watchPaymentAccounts({required bool activeOnly}) async* {
    yield _visible(activeOnly);
    yield* _accountChanges.stream.map((_) => _visible(activeOnly));
  }

  @override
  Future<void> savePaymentAccount(PaymentAccount account) async {
    if (account.id.isEmpty) {
      accounts.add(
        PaymentAccount(
          id: 'account-${_accountSeq++}',
          method: account.method,
          accountNumber: account.accountNumber,
          accountTitle: account.accountTitle,
          active: account.active,
        ),
      );
    } else {
      final index = accounts.indexWhere((a) => a.id == account.id);
      accounts[index] = account;
    }
    _accountsChanged();
  }

  @override
  Future<void> deletePaymentAccount(String id) async {
    accounts.removeWhere((a) => a.id == id);
    _accountsChanged();
  }

  final List<StickerOrder> orders = [];
  final _orderChanges = StreamController<void>.broadcast();

  /// Set to make [placeOrder] fail, to simulate a network error.
  bool failPlaceOrder = false;
  String? lastScreenshotPath;

  void _ordersChanged() => _orderChanges.add(null);

  @override
  Future<StickerOrder> placeOrder(
    StickerOrder order, {
    required String screenshotPath,
    void Function(double progress)? onUploadProgress,
  }) async {
    if (order.unitPrice != price) throw PriceChangedException(price);
    if (failPlaceOrder) throw Exception('Simulated network error');
    onUploadProgress?.call(0.5);
    onUploadProgress?.call(1);
    lastScreenshotPath = screenshotPath;
    final placed = StickerOrder(
      number: order.number,
      uid: order.uid,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items,
      unitPrice: order.unitPrice,
      delivery: order.delivery,
      payment: order.payment.withScreenshot('https://fake/$screenshotPath'),
      createdAt: DateTime(2026, 10, 15, 15, 40),
      statusTimes: {OrderStatus.review: DateTime(2026, 10, 15, 15, 40)},
    );
    orders.insert(0, placed);
    _ordersChanged();
    return placed;
  }

  @override
  Stream<List<StickerOrder>> watchMyOrders(String uid) async* {
    List<StickerOrder> mine() => orders.where((o) => o.uid == uid).toList();
    yield mine();
    yield* _orderChanges.stream.map((_) => mine());
  }

  @override
  Stream<List<StickerOrder>> watchAllOrders() async* {
    yield List.of(orders);
    yield* _orderChanges.stream.map((_) => List.of(orders));
  }

  @override
  Stream<StickerOrder?> watchOrder(String number) async* {
    StickerOrder? find() => orders.where((o) => o.number == number).firstOrNull;
    yield find();
    yield* _orderChanges.stream.map((_) => find());
  }

  @override
  Future<void> updateOrderStatus(String number, {required OrderStatus status, required String note}) async {
    final index = orders.indexWhere((o) => o.number == number);
    final o = orders[index];
    orders[index] = StickerOrder(
      number: o.number,
      uid: o.uid,
      customerName: o.customerName,
      customerPhone: o.customerPhone,
      items: o.items,
      unitPrice: o.unitPrice,
      delivery: o.delivery,
      payment: o.payment,
      status: status,
      note: note,
      createdAt: o.createdAt,
      statusTimes: {...o.statusTimes, status: DateTime(2026, 10, 16, 10)},
    );
    _ordersChanged();
  }
}

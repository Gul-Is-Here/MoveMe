import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/payment_account.dart';
import '../models/sticker_order.dart';

/// Sticker price, payment accounts and sticker orders.
abstract class OrderService {
  /// Used until the admin sets a price.
  static const defaultStickerPrice = 500;
  static const minStickerPrice = 1;
  static const maxStickerPrice = 100000;

  /// The current price of one QR sticker, in rupees; updates live.
  Stream<int> watchStickerPrice();

  Future<int> fetchStickerPrice();

  /// Admin only.
  Future<void> setStickerPrice(int price);

  /// Every account (admin), or only the active ones (customers).
  Stream<List<PaymentAccount>> watchPaymentAccounts({required bool activeOnly});

  /// Creates the account when its id is empty, otherwise updates it. Admin only.
  Future<void> savePaymentAccount(PaymentAccount account);

  /// Admin only.
  Future<void> deletePaymentAccount(String id);

  /// Uploads the payment screenshot and creates [order] (status: payment
  /// under review). Throws [PriceChangedException] when the sticker price
  /// changed since [order] was priced, so nothing is created at a stale price.
  Future<StickerOrder> placeOrder(
    StickerOrder order, {
    required String screenshotPath,
    void Function(double progress)? onUploadProgress,
  });

  /// The customer's own orders, newest first.
  Stream<List<StickerOrder>> watchMyOrders(String uid);

  /// Every order, newest first. Admin only.
  Stream<List<StickerOrder>> watchAllOrders();

  Stream<StickerOrder?> watchOrder(String number);

  /// Admin only. Sets the status and the note the customer sees.
  Future<void> updateOrderStatus(String number, {required OrderStatus status, required String note});
}

class PriceChangedException implements Exception {
  const PriceChangedException(this.newPrice);

  final int newPrice;
}

class FirebaseOrderService implements OrderService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _store => _firestore.collection('settings').doc('store');
  CollectionReference<Map<String, dynamic>> get _accounts => _firestore.collection('paymentAccounts');

  static int _priceFrom(Map<String, dynamic>? data) =>
      (data?['stickerPrice'] as num?)?.toInt() ?? OrderService.defaultStickerPrice;

  @override
  Stream<int> watchStickerPrice() => _store.snapshots().map((snap) => _priceFrom(snap.data()));

  @override
  Future<int> fetchStickerPrice() async {
    // Straight from the server: an order must use the price as it is now.
    final snap = await _store.get(const GetOptions(source: Source.server));
    return _priceFrom(snap.data());
  }

  @override
  Future<void> setStickerPrice(int price) {
    return _store.set({'stickerPrice': price, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Stream<List<PaymentAccount>> watchPaymentAccounts({required bool activeOnly}) {
    // Customers may only read active accounts, so their query must say so.
    final query = activeOnly ? _accounts.where('active', isEqualTo: true) : _accounts;
    return query.snapshots().map((snap) {
      final accounts = snap.docs.map((d) => PaymentAccount.fromMap(d.id, d.data())).toList();
      accounts.sort((a, b) => a.method.compareTo(b.method));
      return accounts;
    });
  }

  @override
  Future<void> savePaymentAccount(PaymentAccount account) {
    if (account.id.isEmpty) {
      return _accounts.add({...account.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    }
    return _accounts.doc(account.id).update(account.toMap());
  }

  @override
  Future<void> deletePaymentAccount(String id) => _accounts.doc(id).delete();

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  List<StickerOrder> _ordersFrom(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => StickerOrder.fromMap(d.id, d.data())).toList();

  @override
  Future<StickerOrder> placeOrder(
    StickerOrder order, {
    required String screenshotPath,
    void Function(double progress)? onUploadProgress,
  }) async {
    final currentPrice = await fetchStickerPrice();
    if (currentPrice != order.unitPrice) throw PriceChangedException(currentPrice);

    final ref = _storage.ref('payment_proofs/${order.uid}/${order.number}.jpg');
    final upload = ref.putFile(File(screenshotPath), SettableMetadata(contentType: 'image/jpeg'));
    final progressSub = upload.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) onUploadProgress?.call(snap.bytesTransferred / snap.totalBytes);
    });
    try {
      await upload;
    } finally {
      await progressSub.cancel();
    }
    final placed = order.withPayment(order.payment.withScreenshot(await ref.getDownloadURL()));
    await _orders.doc(order.number).set(placed.toNewOrderMap());
    return placed;
  }

  @override
  Stream<List<StickerOrder>> watchMyOrders(String uid) => _orders
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_ordersFrom);

  @override
  Stream<List<StickerOrder>> watchAllOrders() =>
      _orders.orderBy('createdAt', descending: true).snapshots().map(_ordersFrom);

  @override
  Stream<StickerOrder?> watchOrder(String number) => _orders.doc(number).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : StickerOrder.fromMap(snap.id, data);
      });

  @override
  Future<void> updateOrderStatus(String number, {required OrderStatus status, required String note}) {
    return _orders.doc(number).update({
      'status': status.name,
      'note': note,
      'statusTimes.${status.name}': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

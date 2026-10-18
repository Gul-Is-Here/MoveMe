import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  review('Payment under review', "We're checking your payment."),
  confirmed('Confirmed', 'Payment received — your order is confirmed.'),
  printing('Printing', 'Your QR stickers are being printed.'),
  shipped('Shipped', 'On the way to your address.'),
  rejected('Payment rejected', 'We could not confirm your payment.'),
  cancelled('Cancelled', 'This order was cancelled.');

  const OrderStatus(this.label, this.customerText);

  final String label;

  /// What the customer reads for this status on their order.
  final String customerText;

  /// The order's normal progress, shown as the customer's timeline.
  static const progress = [review, confirmed, printing, shipped];

  /// A rejected or cancelled order has stopped; the rest are still moving.
  bool get isClosed => this == rejected || this == cancelled;

  /// Rejecting or cancelling must tell the customer why.
  bool get needsNote => isClosed;

  static OrderStatus fromName(String? name) =>
      OrderStatus.values.firstWhere((s) => s.name == name, orElse: () => OrderStatus.review);
}

const pakistanProvinces = [
  'Punjab',
  'Sindh',
  'Khyber Pakhtunkhwa',
  'Balochistan',
  'Islamabad Capital Territory',
  'Gilgit-Baltistan',
  'Azad Kashmir',
];

/// 8 characters without look-alikes (0/O, 1/I/L), so it reads cleanly over
/// the phone.
const _orderNumberAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

String generateOrderNumber([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(8, (_) => _orderNumberAlphabet[rng.nextInt(_orderNumberAlphabet.length)]).join();
}

class OrderItem {
  const OrderItem({required this.vehicleId, required this.plateNumber, required this.nickname, required this.quantity});

  final String vehicleId;
  final String plateNumber;
  final String nickname;
  final int quantity;

  factory OrderItem.fromMap(Map<String, dynamic> data) => OrderItem(
        vehicleId: data['vehicleId'] as String? ?? '',
        plateNumber: data['plateNumber'] as String? ?? '',
        nickname: data['nickname'] as String? ?? '',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'plateNumber': plateNumber,
        'nickname': nickname,
        'quantity': quantity,
      };
}

class OrderDelivery {
  const OrderDelivery({
    required this.fullName,
    required this.phone,
    required this.address,
    required this.province,
    required this.city,
    required this.postalCode,
  });

  final String fullName;
  final String phone;
  final String address;
  final String province;
  final String city;
  final String postalCode;

  factory OrderDelivery.fromMap(Map<String, dynamic> data) => OrderDelivery(
        fullName: data['fullName'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        address: data['address'] as String? ?? '',
        province: data['province'] as String? ?? '',
        city: data['city'] as String? ?? '',
        postalCode: data['postalCode'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'phone': phone,
        'address': address,
        'province': province,
        'city': city,
        'postalCode': postalCode,
      };

  String get singleLine => '$address, $city, $province $postalCode';
}

class OrderPayment {
  const OrderPayment({
    required this.accountId,
    required this.method,
    required this.accountNumber,
    required this.accountTitle,
    required this.amount,
    this.screenshotUrl = '',
  });

  final String accountId;
  final String method;
  final String accountNumber;
  final String accountTitle;
  final int amount;
  final String screenshotUrl;

  factory OrderPayment.fromMap(Map<String, dynamic> data) => OrderPayment(
        accountId: data['accountId'] as String? ?? '',
        method: data['method'] as String? ?? '',
        accountNumber: data['accountNumber'] as String? ?? '',
        accountTitle: data['accountTitle'] as String? ?? '',
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        screenshotUrl: data['screenshotUrl'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'method': method,
        'accountNumber': accountNumber,
        'accountTitle': accountTitle,
        'amount': amount,
        'screenshotUrl': screenshotUrl,
      };

  OrderPayment withScreenshot(String url) => OrderPayment(
        accountId: accountId,
        method: method,
        accountNumber: accountNumber,
        accountTitle: accountTitle,
        amount: amount,
        screenshotUrl: url,
      );
}

class StickerOrder {
  const StickerOrder({
    required this.number,
    required this.uid,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.unitPrice,
    required this.delivery,
    required this.payment,
    this.status = OrderStatus.review,
    this.note = '',
    this.createdAt,
    this.statusTimes = const {},
  });

  /// Also the Firestore document id.
  final String number;
  final String uid;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final int unitPrice;
  final OrderDelivery delivery;
  final OrderPayment payment;
  final OrderStatus status;

  /// The admin's message to the customer — a tracking number, or why a
  /// payment was rejected.
  final String note;
  final DateTime? createdAt;

  /// When the order reached each status.
  final Map<OrderStatus, DateTime> statusTimes;

  int get quantity => items.fold(0, (stickers, item) => stickers + item.quantity);
  int get total => unitPrice * quantity;

  factory StickerOrder.fromMap(String id, Map<String, dynamic> data) {
    DateTime? time(Object? value) => value is Timestamp ? value.toDate() : null;
    final times = <OrderStatus, DateTime>{};
    (data['statusTimes'] as Map?)?.forEach((key, value) {
      final at = time(value);
      if (at != null) times[OrderStatus.fromName(key as String)] = at;
    });
    return StickerOrder(
      number: id,
      uid: data['uid'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      items: ((data['items'] as List?) ?? const [])
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      unitPrice: (data['unitPrice'] as num?)?.toInt() ?? 0,
      delivery: OrderDelivery.fromMap(Map<String, dynamic>.from((data['delivery'] as Map?) ?? const {})),
      payment: OrderPayment.fromMap(Map<String, dynamic>.from((data['payment'] as Map?) ?? const {})),
      status: OrderStatus.fromName(data['status'] as String?),
      note: data['note'] as String? ?? '',
      createdAt: time(data['createdAt']),
      statusTimes: times,
    );
  }

  /// The document a customer creates when placing the order.
  Map<String, dynamic> toNewOrderMap() => {
        'number': number,
        'uid': uid,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((i) => i.toMap()).toList(),
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
        'delivery': delivery.toMap(),
        'payment': payment.toMap(),
        'status': OrderStatus.review.name,
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusTimes': {OrderStatus.review.name: FieldValue.serverTimestamp()},
      };

  StickerOrder withPayment(OrderPayment newPayment) => StickerOrder(
        number: number,
        uid: uid,
        customerName: customerName,
        customerPhone: customerPhone,
        items: items,
        unitPrice: unitPrice,
        delivery: delivery,
        payment: newPayment,
        status: status,
        note: note,
        createdAt: createdAt,
        statusTimes: statusTimes,
      );
}

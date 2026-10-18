import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/models/sticker_order.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/admin_service.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/order_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/modules/admin/controllers/admin_orders_controller.dart';

import 'support/fake_admin_service.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_order_service.dart';
import 'support/fake_push_notification_service.dart';

StickerOrder _order(String number, {required String name, required String phone, required String plate, OrderStatus status = OrderStatus.review}) =>
    StickerOrder(
      number: number,
      uid: 'u-$number',
      customerName: name,
      customerPhone: phone,
      items: [OrderItem(vehicleId: 'v-$number', plateNumber: plate, nickname: '', quantity: 1)],
      unitPrice: 500,
      delivery: OrderDelivery(fullName: name, phone: phone, address: 'House 1, Street 2', province: 'Punjab', city: 'Lahore', postalCode: '54000'),
      payment: const OrderPayment(accountId: 'a1', method: 'EasyPaisa', accountNumber: '0311', accountTitle: 'MoveMe', amount: 500),
      status: status,
      createdAt: DateTime(2026, 10, 15),
    );

void main() {
  late FakeOrderService orders;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(
      FakeAuthService()
        ..signInAs(uid: 'admin-uid', phone: '+923079618674')
        ..adminClaimed = true,
    );
    Get.put<PushNotificationService>(FakePushNotificationService());
    Get.put<AdminService>(FakeAdminService());
    orders = FakeOrderService()
      ..orders.addAll([
        _order('AAAA2222', name: 'Ali Raza', phone: '+923001234567', plate: 'LEA-2231'),
        _order('BBBB3333', name: 'Sara Khan', phone: '+923217654321', plate: 'KHI-909', status: OrderStatus.shipped),
        _order('CCCC4444', name: 'Usman Tariq', phone: '+923331112223', plate: 'ISB-5', status: OrderStatus.cancelled),
      ]);
    Get.put<OrderService>(orders);
  });

  Future<void> pumpAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(initialRoute: AppRoutes.admin, getPages: AppPages.routes));
    await tester.pumpAndSettle();
  }

  test('Phone search matches any Pakistani format', () {
    expect(normalizePhoneDigits('0300 1234567'), '3001234567');
    expect(normalizePhoneDigits('923001234567'), '3001234567');
    expect(normalizePhoneDigits('+923001234567'), '3001234567');
    expect(normalizePhoneDigits('00923001234567'), '3001234567');
    expect(normalizePlate('lea2231'), normalizePlate('LEA-2231'));
  });

  testWidgets('Filters and search narrow the list', (tester) async {
    await pumpAdmin(tester);
    final controller = Get.find<AdminOrdersController>();

    expect(find.text('#AAAA2222'), findsOneWidget);
    expect(find.text('#BBBB3333'), findsOneWidget);
    expect(find.text('To review (1)'), findsOneWidget);

    await tester.ensureVisible(find.text('In progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    expect(controller.visible.map((o) => o.number), ['BBBB3333']);

    await tester.ensureVisible(find.text('Rejected / cancelled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rejected / cancelled'));
    await tester.pumpAndSettle();
    expect(controller.visible.map((o) => o.number), ['CCCC4444']);

    await tester.ensureVisible(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), '0321 7654321');
    await tester.pumpAndSettle();
    expect(controller.visible.map((o) => o.number), ['BBBB3333']);

    await tester.enterText(find.byType(TextField), 'lea2231');
    await tester.pumpAndSettle();
    expect(controller.visible.map((o) => o.number), ['AAAA2222']);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No orders here'), findsOneWidget);
  });

  testWidgets('Rejecting needs a reason; saving updates the order and returns to Orders', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('#AAAA2222'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.adminOrder);
    await tester.scrollUntilVisible(find.text('Check this amount arrived before confirming.'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Check this amount arrived before confirming.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Payment rejected'), 200, scrollable: find.byType(Scrollable).last);

    await tester.ensureVisible(find.text('Payment rejected'));
    await tester.tap(find.text('Payment rejected'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(find.text('Add a reason — tell the customer why.'), findsOneWidget);
    expect(orders.orders.first.status, OrderStatus.review);

    await tester.enterText(find.widgetWithText(TextField, 'Add a reason — tell the customer why.'), 'No payment arrived.');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = orders.orders.firstWhere((o) => o.number == 'AAAA2222');
    expect(saved.status, OrderStatus.rejected);
    expect(saved.note, 'No payment arrived.');
    expect(Get.currentRoute, AppRoutes.admin);
    expect(find.text('Order #AAAA2222 is now Payment rejected.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Shipping with a tracking note needs no reason', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('#AAAA2222'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save Changes'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.widgetWithText(AnimatedContainer, 'Shipped'));
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. a courier tracking number, or why a payment was rejected'),
      'TCS 123456',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = orders.orders.firstWhere((o) => o.number == 'AAAA2222');
    expect(saved.status, OrderStatus.shipped);
    expect(saved.note, 'TCS 123456');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

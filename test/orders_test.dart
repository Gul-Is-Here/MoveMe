import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/models/payment_account.dart';
import 'package:parktag_app/app/models/sticker_order.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/order_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/orders/controllers/order_form_controller.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_order_service.dart';
import 'support/fake_vehicle_service.dart';

const _uid = 'cust-1';

StickerOrder _sampleOrder({OrderStatus status = OrderStatus.review, String note = ''}) => StickerOrder(
      number: 'K7M4Q92X',
      uid: _uid,
      customerName: 'Ali Raza',
      customerPhone: '+923001234567',
      items: const [OrderItem(vehicleId: 'v1', plateNumber: 'LEA-2231', nickname: 'White Corolla', quantity: 2)],
      unitPrice: 500,
      delivery: const OrderDelivery(
        fullName: 'Ali Raza',
        phone: '+923001234567',
        address: 'House 12, Street 4, Model Town',
        province: 'Punjab',
        city: 'Lahore',
        postalCode: '54000',
      ),
      payment: const OrderPayment(
        accountId: 'a1',
        method: 'EasyPaisa',
        accountNumber: '03111111111',
        accountTitle: 'MoveMe',
        amount: 1000,
      ),
      status: status,
      note: note,
      createdAt: DateTime(2026, 10, 15, 15, 40),
      statusTimes: {
        OrderStatus.review: DateTime(2026, 10, 15, 15, 40),
        if (status != OrderStatus.review) status: DateTime(2026, 10, 16, 10),
      },
    );

void main() {
  late FakeOrderService orders;
  late FakeVehicleService vehicles;
  late String firstVehicleId;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    Get.reset();
    final auth = FakeAuthService()
      ..signInAs(uid: _uid, phone: '+923001234567', profile: {'name': 'Ali Raza'});
    Get.put<AuthService>(auth);
    vehicles = FakeVehicleService();
    Get.put<VehicleService>(vehicles);
    orders = FakeOrderService();
    Get.put<OrderService>(orders);

    Future<String> addVehicle(String plate, String nickname) => vehicles.saveVehicle(
          uid: _uid,
          ownerName: 'Ali Raza',
          nickname: nickname,
          make: 'Toyota',
          model: 'Corolla',
          plateNumber: plate,
          colorName: 'White',
          dateOfRegistration: '',
          engineNumber: '',
          chassisNumber: '',
          address: '',
          localPhotoPaths: const [],
        );
    firstVehicleId = await addVehicle('LEA-2231', 'White Corolla');
    await addVehicle('LEB-5566', 'Red Civic');
  });

  Future<void> pumpRoute(WidgetTester tester, String route, {Object? arguments}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(initialRoute: AppRoutes.dashboard, getPages: [
      GetPage(name: AppRoutes.dashboard, page: () => const SizedBox()),
      ...AppPages.routes.where((p) => p.name != AppRoutes.dashboard),
    ]));
    Get.toNamed(route, arguments: arguments);
    await tester.pumpAndSettle();
  }

  Future<void> flushSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> fillDelivery(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, 'House, street, area'), 'House 12, Street 4, Model Town');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Lahore'), 'Lahore');
    await tester.enterText(find.widgetWithText(TextField, '54000'), '54000');
    final controller = Get.find<OrderFormController>();
    controller.province.value = 'Punjab';
    await tester.pump();
  }

  test('Order numbers are 8 characters with no look-alikes', () {
    final rng = Random(1);
    for (var i = 0; i < 200; i++) {
      final number = generateOrderNumber(rng);
      expect(number, matches(RegExp(r'^[2-9A-HJKMNP-Z]{8}$')));
    }
  });

  test('An order totals price × stickers', () {
    expect(_sampleOrder().quantity, 2);
    expect(_sampleOrder().total, 1000);
  });

  testWidgets('Starting from a vehicle puts 1 sticker on it and 0 on the others', (tester) async {
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    final controller = Get.find<OrderFormController>();

    expect(controller.stickerCount, 1);
    expect(find.text('Rs 500'), findsOneWidget);
    // The other vehicle's minus button is greyed out at zero.
    final minus = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove_rounded).last);
    expect(minus.onPressed, isNull);

    await tester.tap(find.byTooltip('One more for LEB-5566'));
    await tester.pump();
    expect(controller.stickerCount, 2);
    expect(find.text('Rs 1,000'), findsOneWidget);
  });

  testWidgets('Next names the first problem, then moves to payment', (tester) async {
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    final controller = Get.find<OrderFormController>();

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Please enter your full address.'), findsOneWidget);
    expect(controller.step.value, 0);
    await flushSnackbar(tester);

    await fillDelivery(tester);
    await tester.enterText(find.widgetWithText(TextField, '54000'), '540');
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Please enter a 5-digit postal code.'), findsOneWidget);
    await flushSnackbar(tester);

    await tester.enterText(find.widgetWithText(TextField, '540'), '54000');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(controller.step.value, 1);
    expect(controller.fullName.text, 'Ali Raza');
  });

  testWidgets('With no payment account shown, ordering is closed', (tester) async {
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    await fillDelivery(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Sticker orders aren't open right now"), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Place order').first);
    expect(button.onPressed, isNull);
  });

  testWidgets('Back keeps everything typed', (tester) async {
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    await fillDelivery(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('House 12, Street 4, Model Town'), findsOneWidget);
    expect(Get.find<OrderFormController>().stickerCount, 1);
  });

  testWidgets('Placing an order opens it under review and confirms', (tester) async {
    orders.accounts.add(
      const PaymentAccount(id: 'a1', method: 'EasyPaisa', accountNumber: '03111111111', accountTitle: 'MoveMe'),
    );
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    await fillDelivery(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // The only account is picked for the customer.
    final controller = Get.find<OrderFormController>();
    expect(controller.selectedAccountId.value, 'a1');

    await tester.tap(find.text('Place order'));
    await tester.pump();
    expect(find.text('Add the payment screenshot'), findsOneWidget);
    await flushSnackbar(tester);

    controller.screenshotPath.value = '/tmp/proof.jpg';
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    final placed = orders.orders.single;
    expect(placed.quantity, 1);
    expect(placed.total, 500);
    expect(placed.payment.amount, 500);
    expect(placed.payment.method, 'EasyPaisa');
    expect(placed.delivery.city, 'Lahore');
    expect(placed.customerPhone, '+923001234567');
    expect(orders.lastScreenshotPath, '/tmp/proof.jpg');

    expect(Get.currentRoute, AppRoutes.orderDetails);
    expect(find.text('Order #${placed.number}'), findsWidgets);
    expect(find.text('Payment under review'), findsWidgets);
    expect(find.textContaining("We'll check your EasyPaisa payment"), findsOneWidget);
    await flushSnackbar(tester);
  });

  testWidgets('A price change before placing stops the order and shows the new total', (tester) async {
    orders.accounts.add(
      const PaymentAccount(id: 'a1', method: 'EasyPaisa', accountNumber: '03111111111', accountTitle: 'MoveMe'),
    );
    await pumpRoute(tester, AppRoutes.orderStickers, arguments: firstVehicleId);
    await fillDelivery(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final controller = Get.find<OrderFormController>()..screenshotPath.value = '/tmp/proof.jpg';

    // The admin raises the price, but this screen hasn't heard yet.
    orders.price = 600;
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(orders.orders, isEmpty);
    expect(controller.unitPrice.value, 600);
    expect(find.text('Price updated'), findsOneWidget);
    expect(find.text('Rs 600'), findsWidgets);
    expect(Get.currentRoute, AppRoutes.orderStickers);
    await flushSnackbar(tester);
  });

  testWidgets('My Orders lists orders and opens one', (tester) async {
    await pumpRoute(tester, AppRoutes.myOrders);
    expect(find.text('No orders yet'), findsOneWidget);

    orders.orders.add(_sampleOrder());
    Get.back();
    await tester.pumpAndSettle();
    Get.toNamed(AppRoutes.myOrders);
    await tester.pumpAndSettle();

    expect(find.text('#K7M4Q92X'), findsOneWidget);
    expect(find.text('2 stickers · 15 Oct 2026'), findsOneWidget);
    await tester.tap(find.text('#K7M4Q92X'));
    await tester.pumpAndSettle();
    expect(find.text('Order #K7M4Q92X'), findsOneWidget);
  });

  testWidgets("Order details shows the timeline and the admin's message", (tester) async {
    orders.orders.add(_sampleOrder(status: OrderStatus.shipped, note: 'TCS tracking 123456'));
    await pumpRoute(tester, AppRoutes.orderDetails, arguments: 'K7M4Q92X');

    expect(find.text('Message from MoveMe'), findsOneWidget);
    expect(find.text('TCS tracking 123456'), findsOneWidget);
    expect(find.text('On the way to your address.'), findsOneWidget);
    expect(find.text('Rs 1,000'), findsWidgets);
    expect(find.text('Lahore, Punjab'), findsOneWidget);
  });

  testWidgets('A rejected order shows where it stopped', (tester) async {
    orders.orders.add(_sampleOrder(status: OrderStatus.rejected, note: 'No payment arrived.'));
    await pumpRoute(tester, AppRoutes.orderDetails, arguments: 'K7M4Q92X');

    expect(find.text('Payment rejected'), findsWidgets);
    expect(find.text('No payment arrived.'), findsOneWidget);
    // The order never reached printing or shipping.
    expect(find.text('Printing'), findsNothing);
    expect(find.text('Shipped'), findsNothing);
  });
}

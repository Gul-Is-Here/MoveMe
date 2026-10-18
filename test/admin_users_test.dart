import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/models/sticker_order.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/routes/route_stack.dart';
import 'package:parktag_app/app/services/admin_service.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/order_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/services/session_watcher.dart';
import 'package:parktag_app/modules/admin/controllers/admin_user_controller.dart';
import 'package:parktag_app/modules/admin/controllers/admin_users_controller.dart';

import 'support/fake_admin_service.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_order_service.dart';
import 'support/fake_push_notification_service.dart';

void main() {
  late FakeAdminService admin;
  late FakeOrderService orders;
  late FakeAuthService auth;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Get.reset();
    auth = FakeAuthService()
      ..signInAs(uid: 'admin-uid', phone: '+923079618674')
      ..adminClaimed = true;
    Get.put<AuthService>(auth);
    Get.put<PushNotificationService>(FakePushNotificationService());
    orders = FakeOrderService();
    Get.put<OrderService>(orders);
    admin = FakeAdminService()
      ..users.addAll([
        AdminUser(uid: 'u1', name: 'Ali Raza', phone: '+923001234567', cnic: '42101-1234567-1', createdAt: DateTime(2026, 9, 1)),
        const AdminUser(uid: 'u2', name: 'Sara Khan', phone: '+923217654321'),
      ])
      ..vehicles.addAll(const [
        AdminVehicle(id: 'v1', uid: 'u1', nickname: 'White Corolla', make: 'Toyota', model: 'Corolla', plateNumber: 'LEA-2231'),
        AdminVehicle(id: 'v2', uid: 'u1', nickname: 'Bike', make: 'Honda', model: 'CD 70', plateNumber: 'LHR-77'),
        AdminVehicle(id: 'v3', uid: 'u2', nickname: 'Civic', make: 'Honda', model: 'Civic', plateNumber: 'lea 2231'),
      ]);
    Get.put<AdminService>(admin);
  });

  Future<void> pumpAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(initialRoute: AppRoutes.admin, getPages: AppPages.routes, navigatorObservers: [RouteStack.instance]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
  }

  Future<void> flushSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('Users lists everyone with counts; search finds by CNIC, phone and plate', (tester) async {
    await pumpAdmin(tester);
    final controller = Get.find<AdminUsersController>();

    expect(find.text('2 users'), findsOneWidget);
    expect(find.text('2 vehicles'), findsOneWidget);
    expect(find.text('1 vehicle'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4210112345671');
    await tester.pump();
    expect(controller.results.map((r) => r.user.uid), ['u1']);

    await tester.enterText(find.byType(TextField), '0321 7654321');
    await tester.pump();
    expect(controller.results.map((r) => r.user.uid), ['u2']);

    await tester.enterText(find.byType(TextField), 'lhr77');
    await tester.pump();
    expect(controller.results.single.matchedVehicle?.id, 'v2');
    expect(find.text('Matched LHR-77'), findsOneWidget);
  });

  testWidgets('A plate search opens the user at that vehicle, flagged as a duplicate plate', (tester) async {
    await pumpAdmin(tester);
    await tester.enterText(find.byType(TextField), 'lea2231');
    await tester.pump();

    await tester.tap(find.text('Ali Raza'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.adminUser);
    final ali = Get.find<AdminUserController>(tag: 'u1');
    expect(ali.user.value?.name, 'Ali Raza');
    expect(ali.focusedVehicleId.value, 'v1');
    expect(ali.expanded, contains('v1'));
    // The matched vehicle is open and shows the duplicate on Sara's account.
    expect(find.text('Duplicate plate'), findsOneWidget);
    expect(find.text('This registration number is also registered on:'), findsOneWidget);

    await tester.tap(find.text('Sara Khan'));
    await tester.pumpAndSettle();
    expect(Get.find<AdminUserController>(tag: 'u2').focusedVehicleId.value, 'v3');
  });

  testWidgets('Blocking asks first, then marks the user blocked', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('Sara Khan'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Block User'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Block User'));
    await tester.pumpAndSettle();
    expect(find.text('Block Sara?'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();

    expect(admin.users.firstWhere((u) => u.uid == 'u2').blocked, isTrue);
    expect(find.text('Unblock User'), findsOneWidget);
    await flushSnackbar(tester);
  });

  testWidgets('An order links to the account, and back to the open order instead of a copy', (tester) async {
    orders.orders.add(
      StickerOrder(
        number: 'AAAA2222',
        uid: 'u1',
        customerName: 'Ali Raza',
        customerPhone: '+923001234567',
        items: const [OrderItem(vehicleId: 'v1', plateNumber: 'LEA-2231', nickname: '', quantity: 1)],
        unitPrice: 500,
        delivery: const OrderDelivery(fullName: 'Ali', phone: '', address: 'House 1, Street 2', province: 'Punjab', city: 'Lahore', postalCode: '54000'),
        payment: const OrderPayment(accountId: 'a', method: 'EasyPaisa', accountNumber: '0', accountTitle: 'M', amount: 500),
        status: OrderStatus.confirmed,
        createdAt: DateTime(2026, 10, 15),
      ),
    );
    await pumpAdmin(tester);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#AAAA2222'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View account'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.adminUser);
    // Paid counts accepted orders.
    expect(find.text('Rs 500'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('#AAAA2222'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('#AAAA2222'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.adminOrder);

    // Back once lands on the Orders tab: the order was returned to, not stacked.
    Get.back();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.admin);
  });

  testWidgets('A blocked number is told so at login', (tester) async {
    Get.reset();
    final blockedAuth = FakeAuthService()..blockedPhones.add('+923001234567');
    Get.put<AuthService>(blockedAuth);
    Get.put<PushNotificationService>(FakePushNotificationService());
    await tester.pumpWidget(GetMaterialApp(initialRoute: AppRoutes.login, getPages: AppPages.routes));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '3001234567');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(find.text('Account blocked'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.login);
    await flushSnackbar(tester);
  });

  testWidgets('Being signed out by Firebase (blocked elsewhere) returns to login', (tester) async {
    Get.reset();
    final customer = FakeAuthService()..signInAs(uid: 'u1', phone: '+923001234567');
    Get.put<AuthService>(customer);
    Get.put<PushNotificationService>(FakePushNotificationService());
    final sub = watchForcedSignOuts(customer);
    addTearDown(sub.cancel);
    await tester.pumpWidget(GetMaterialApp(initialRoute: '/somewhere', getPages: [
      GetPage(name: '/somewhere', page: () => const SizedBox()),
      ...AppPages.routes,
    ]));
    await tester.pump();

    customer.simulateForcedSignOut();
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.login);
    expect(find.text("You've been signed out"), findsOneWidget);
    await flushSnackbar(tester);
  });
}

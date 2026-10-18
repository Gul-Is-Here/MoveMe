import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/models/payment_account.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/admin_service.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/order_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/utils/money.dart';
import 'package:parktag_app/modules/admin/widgets/sticker_price_sheet.dart';

import 'support/fake_admin_service.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_order_service.dart';
import 'support/fake_push_notification_service.dart';

void main() {
  late FakeOrderService orders;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Get.reset();
    final auth = FakeAuthService()
      ..signInAs(uid: 'admin-uid', phone: '+923079618674')
      ..adminClaimed = true;
    Get.put<AuthService>(auth);
    Get.put<PushNotificationService>(FakePushNotificationService());
    Get.put<AdminService>(FakeAdminService());
    orders = FakeOrderService();
    Get.put<OrderService>(orders);
  });

  Future<void> openProfileTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(initialRoute: AppRoutes.admin, getPages: AppPages.routes));
    await tester.pump();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
  }

  Future<void> flushSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  test('Rupees are grouped in thousands', () {
    expect(formatRupees(500), 'Rs 500');
    expect(formatRupees(1500), 'Rs 1,500');
    expect(formatRupees(100000), 'Rs 100,000');
  });

  test('The price sheet only accepts Rs 1 to Rs 100,000', () {
    expect(StickerPriceSheet.validate('500'), isNull);
    expect(StickerPriceSheet.validate('1'), isNull);
    expect(StickerPriceSheet.validate('100000'), isNull);
    expect(StickerPriceSheet.validate('0'), isNotNull);
    expect(StickerPriceSheet.validate('100001'), isNotNull);
    expect(StickerPriceSheet.validate(''), isNotNull);
  });

  testWidgets('Profile shows the default Rs 500 and warns that no account is shown', (tester) async {
    await openProfileTab(tester);

    expect(find.text('Rs 500'), findsOneWidget);
    expect(find.textContaining("customers can't place sticker orders"), findsOneWidget);
  });

  testWidgets('Changing the price saves it and confirms the new amount', (tester) async {
    await openProfileTab(tester);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '500'), '0');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a price from Rs 1'), findsOneWidget);
    expect(orders.price, 500);

    await tester.enterText(find.widgetWithText(TextField, '0'), '750');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();

    expect(orders.price, 750);
    expect(find.text('Rs 750'), findsOneWidget);
    expect(find.text('New orders are now Rs 750 per sticker.'), findsOneWidget);
    await flushSnackbar(tester);
  });

  testWidgets('Adding an account shows it to users and clears the warning', (tester) async {
    await openProfileTab(tester);

    await reveal(tester, find.text('Add payment account'));
    await tester.tap(find.text('Add payment account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JazzCash'));
    await tester.enterText(find.widgetWithText(TextField, '03XX XXXXXXX or IBAN'), '03001234567');
    await tester.enterText(find.widgetWithText(TextField, 'The name on the account'), 'Ali Raza');
    await tester.ensureVisible(find.text('Add account'));
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();

    expect(orders.accounts.single.method, 'JazzCash');
    expect(orders.accounts.single.active, isTrue);
    expect(find.text('03001234567'), findsOneWidget);
    expect(find.text('Account shown to users'), findsOneWidget);
    expect(find.textContaining("customers can't place sticker orders"), findsNothing);
    await flushSnackbar(tester);
  });

  testWidgets('An account can be hidden, then deleted after confirming', (tester) async {
    orders.accounts.add(
      const PaymentAccount(id: 'a1', method: 'EasyPaisa', accountNumber: '03111111111', accountTitle: 'MoveMe'),
    );
    await openProfileTab(tester);

    await reveal(tester, find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(orders.accounts.single.active, isFalse);
    expect(find.text('Account hidden from users'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this account?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(orders.accounts, isEmpty);
    await flushSnackbar(tester);
  });
}

/// Scrolls [finder] to the middle of the screen, clear of the floating
/// bottom bar that would otherwise take the tap.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/deep_link_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/dashboard/bindings/dashboard_binding.dart';
import 'package:parktag_app/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:parktag_app/modules/dashboard/controllers/home_tab_controller.dart';
import 'package:parktag_app/modules/dashboard/controllers/inbox_controller.dart';
import 'package:parktag_app/modules/dashboard/controllers/profile_controller.dart';
import 'package:parktag_app/modules/dashboard/views/dashboard_view.dart';
import 'package:parktag_app/modules/dashboard/widgets/dashboard_bottom_nav.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_conversation_service.dart';
import 'support/fake_deep_link_service.dart';
import 'support/fake_push_notification_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeConversationService fakeConversations;

  setUp(() async {
    Get.reset();
    final fakeAuth = FakeAuthService();
    fakeAuth.signInAs(uid: 'resident-1', phone: '+923001234567');
    Get.put<AuthService>(fakeAuth);
    final fakeVehicles = FakeVehicleService();
    Get.put<VehicleService>(fakeVehicles);
    Get.put<PushNotificationService>(FakePushNotificationService());
    Get.put<DeepLinkService>(FakeDeepLinkService());
    await fakeVehicles.saveVehicle(
      uid: 'resident-1',
      ownerName: 'Ayesha Khan',
      nickname: 'White Corolla',
      make: 'Toyota',
      model: 'Corolla Altis',
      plateNumber: 'LEA-2231',
      colorName: 'White',
      dateOfRegistration: '',
      engineNumber: '',
      chassisNumber: '',
      address: '',
      localPhotoPaths: const [],
    );
    fakeConversations = FakeConversationService();
    Get.put<ConversationService>(fakeConversations);
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'demo-white-corolla_scanner-1',
        vehicleId: 'demo-white-corolla',
        ownerUid: 'resident-1',
        scannerName: 'Anonymous',
        plateNumber: 'LEA-2231',
        colorName: 'White',
        resolved: false,
        unreadForOwner: true,
        lastMessagePreview: 'Please move your car',
        lastMessageAt: null,
      ),
      const [ConversationMessage(sender: MessageSender.scanner, text: 'Please move your car', createdAt: null)],
    );
  });

  testWidgets('Dashboard shows the Home tab with vehicle cards, an Add Vehicle button and a QR scan icon', (
    tester,
  ) async {
    DashboardBinding().dependencies();

    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pump();

    expect(find.text('White Corolla'), findsOneWidget);
    expect(find.text('Your vehicles'), findsOneWidget);
    // Two distinct scanners, two distinct icons: the bottom FAB starts the
    // Add Vehicle (RC card OCR) flow — never a QR icon, so it's never
    // mistaken for the QR-to-chat scanner up in the Home tab's app bar.
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    // Messages lives in the bottom bar; the Home header's other action is
    // the profile avatar.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Tapping Messages switches the visible tab to the Inbox', (tester) async {
    DashboardBinding().dependencies();

    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pump();

    await tester.tap(find.text('Messages'));
    await tester.pump();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Please move your car'), findsOneWidget);
    expect(find.text('Your vehicles'), findsNothing);
  });

  testWidgets('Tapping a thread opens the chat and back returns to the Inbox', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.dashboard,
        getPages: AppPages.routes,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Messages'));
    await tester.pump();

    await tester.tap(find.text('Please move your car'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Has this issue been resolved?'), findsOneWidget);
    expect(find.text('Please move your car'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('Entering the full OTP and verifying lands on Dashboard', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.otp,
        getPages: AppPages.routes,
      ),
    );
    await tester.pump();

    final digitFields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(digitFields.at(i), '1');
    }
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Your vehicles'), findsOneWidget);
  });

  testWidgets(
    'Dashboard survives a repaint after its controllers are deleted (logout race)',
    (tester) async {
      DashboardBinding().dependencies();
      await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
      await tester.pump();

      // Hold the instance the way the still-mounted widget tree does.
      final dashboard = Get.find<DashboardController>();

      // What Get.offAllNamed does on logout: the outgoing route's bindings
      // are deleted while that route is still mounted and animating out.
      Get.delete<DashboardController>();
      Get.delete<HomeTabController>();
      Get.delete<InboxController>();
      Get.delete<ProfileController>();

      // An observable firing in that window rebuilds the Obx, which used to
      // re-run Get.find against an empty registry and throw
      // '"DashboardController" not found'.
      dashboard.changeTab(1);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('The Messages tab shows an unread message count badge', (tester) async {
    DashboardBinding().dependencies();
    await tester.pumpWidget(const GetMaterialApp(home: DashboardView()));
    await tester.pump();

    final inbox = Get.find<InboxController>();
    // This suite's setUp already seeds conversations, so start from
    // whatever is unread rather than assuming zero.
    final baseline = inbox.unreadMessageCount;

    for (final text in ['Please move', 'Still blocked']) {
      await fakeConversations.simulateScannerMessage(
        vehicleId: 'v-nav',
        scannerId: 's-nav',
        ownerUid: 'resident-1',
        plateNumber: 'LEH-5150',
        colorName: 'Black',
        scannerName: 'Nadia',
        text: text,
      );
    }
    await tester.pump();

    // Two messages in one new conversation.
    expect(inbox.unreadMessageCount, baseline + 2);
    expect(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('${baseline + 2}'),
      ),
      findsOneWidget,
    );

    // Reading that thread drops the count by exactly its two messages.
    await fakeConversations.markReadByOwner('v-nav_s-nav');
    await tester.pump();

    expect(inbox.unreadMessageCount, baseline);
    expect(
      find.descendant(
        of: find.byType(DashboardBottomNav),
        matching: find.text('${baseline + 2}'),
      ),
      findsNothing,
    );
  });

  testWidgets('The nav bar renders without the Inbox controller', (tester) async {
    // The badge must not be able to break the bar — including during the
    // logout teardown, when the bindings are already gone.
    Get.put(DashboardController());
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          bottomNavigationBar: Obx(
            () => DashboardBottomNav(
              selectedIndex: Get.find<DashboardController>().tabIndex.value,
              unreadCount: Get.find<DashboardController>().hasUnreadSource
                  ? Get.find<DashboardController>().unreadMessageCount
                  : 0,
              onTap: (_) {},
              onAddVehicle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Messages'), findsOneWidget);
  });
}

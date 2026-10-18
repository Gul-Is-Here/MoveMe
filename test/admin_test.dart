import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/admin_service.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/deep_link_service.dart';
import 'package:parktag_app/app/services/onboarding_service.dart';
import 'package:parktag_app/app/services/order_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/app/theme/app_colors.dart';
import 'package:parktag_app/app/theme/theme_controller.dart';
import 'package:parktag_app/modules/admin/widgets/admin_theme_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_admin_service.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_conversation_service.dart';
import 'support/fake_deep_link_service.dart';
import 'support/fake_onboarding_service.dart';
import 'support/fake_order_service.dart';
import 'support/fake_push_notification_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  late FakeAuthService auth;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Get.reset();
    auth = FakeAuthService()..registerAllByDefault = false;
    Get.put<AuthService>(auth);
    Get.put<PushNotificationService>(FakePushNotificationService());
    Get.put<AdminService>(FakeAdminService());
    Get.put<ConversationService>(FakeConversationService());
    Get.put<DeepLinkService>(FakeDeepLinkService());
    Get.put<VehicleService>(FakeVehicleService());
    Get.put<OnboardingService>(FakeOnboardingService());
    Get.put<OrderService>(FakeOrderService());
  });

  Future<void> pumpAt(WidgetTester tester, String route) async {
    await tester.pumpWidget(GetMaterialApp(initialRoute: route, getPages: AppPages.routes));
    await tester.pump();
  }

  Future<void> enterCodeAndVerify(WidgetTester tester) async {
    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
    }
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
  }

  testWidgets('The admin number logs in without an account and lands on the admin side', (tester) async {
    await pumpAt(tester, AppRoutes.login);

    await tester.enterText(find.byType(TextField).last, '3079618674');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your number'), findsOneWidget);

    await enterCodeAndVerify(tester);

    expect(auth.adminClaimed, isTrue);
    expect(Get.currentRoute, AppRoutes.admin);
    expect(find.text('Check payments, then print and ship stickers.'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    // No Add-vehicle button on the admin side.
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
  });

  testWidgets('Any other unregistered number is still told to sign up', (tester) async {
    await pumpAt(tester, AppRoutes.login);

    await tester.enterText(find.byType(TextField).last, '3001234567');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(find.text('No account found'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.login);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Sign up refuses the admin number', (tester) async {
    await pumpAt(tester, AppRoutes.signUp);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Admin Person');
    await tester.enterText(fields.at(1), '3079618674');
    await tester.enterText(fields.at(2), '42101-1234567-1');
    await tester.ensureVisible(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send OTP'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('This is the admin number'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.signUp);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('A signed-in admin reopening the app goes straight to the admin side', (tester) async {
    auth
      ..signInAs(uid: 'admin-uid', phone: '+923079618674')
      ..adminClaimed = true;

    await pumpAt(tester, AppRoutes.splash);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.admin);
  });

  testWidgets('Signing out of the admin side returns to login', (tester) async {
    auth
      ..signInAs(uid: 'admin-uid', phone: '+923079618674')
      ..adminClaimed = true;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await pumpAt(tester, AppRoutes.admin);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('+923079618674'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(Get.currentRoute, AppRoutes.login);
    // Let the "Signed out" snackbar finish showing and animate away.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('The admin can switch between the light and dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = Get.put(ThemeController());
    auth
      ..signInAs(uid: 'admin-uid', phone: '+923079618674')
      ..adminClaimed = true;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await pumpAt(tester, AppRoutes.admin);
    await tester.pumpAndSettle();

    // setMode saves to prefs, then repaints the whole app; let both finish
    // before the next tap.
    Future<void> settleTheme() async {
      await tester.pumpAndSettle();
      await tester.runAsync(() => SharedPreferences.getInstance());
      await tester.pumpAndSettle();
    }

    // Dark is the default; the header button flips it.
    expect(AppColors.isLight, isFalse);
    // One per tab; the Orders tab's is the one showing.
    await tester.tap(find.byType(AdminThemeToggle).first);
    await settleTheme();
    expect(theme.mode.value, AppThemeMode.light);
    expect(AppColors.isLight, isTrue);
    expect((await SharedPreferences.getInstance()).getString('themeMode'), 'light');

    // The Appearance picker on Profile sets it too.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dark'), 200, scrollable: find.byType(Scrollable).last);
    await Scrollable.ensureVisible(tester.element(find.text('Dark')), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await settleTheme();
    expect(theme.mode.value, AppThemeMode.dark);

    await tester.tap(find.text('Auto'));
    await settleTheme();
    expect(theme.mode.value, AppThemeMode.system);
  });
}

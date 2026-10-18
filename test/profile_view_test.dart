import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/routes/app_routes.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/dashboard/controllers/profile_controller.dart';
import 'package:parktag_app/modules/dashboard/views/profile_view.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_conversation_service.dart';
import 'support/fake_push_notification_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Get.testMode = true;
  });

  setUp(() {
    Get.reset();
    Get.put<ConversationService>(FakeConversationService());
    Get.put<VehicleService>(FakeVehicleService());
    Get.put<PushNotificationService>(FakePushNotificationService());
  });

  FakeAuthService signedInFakeAuth() {
    final fakeAuth = FakeAuthService();
    fakeAuth.signInAs(
      uid: 'resident-1',
      phone: '+92 300 1234567',
      profile: {'name': 'Turab Raza', 'cnic': '35202-1234567-1'},
    );
    return fakeAuth;
  }

  testWidgets('Profile lets the resident change how they are reached', (tester) async {
    final auth = signedInFakeAuth();
    auth.profiles['resident-1'] = {...?auth.profiles['resident-1'], 'communicationPreference': 'app'};
    Get.put<AuthService>(auth);
    final controller = Get.put(ProfileController());

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: ProfileView())));
    await tester.pump();
    await tester.pump();
    expect(controller.communicationPreference.value, 'app');

    await tester.dragUntilVisible(find.text('On the web link'), find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(find.text('On the web link'));
    await tester.pumpAndSettle();
    // Bring it to mid-screen, clear of the card's rise-in offset.
    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On the web link'));
    await tester.pumpAndSettle();

    expect(controller.communicationPreference.value, 'web');
    expect(auth.communicationPreferences['resident-1'], 'web');
  });

  testWidgets('Profile loads and renders the signed-in resident, verified phone and CNIC', (tester) async {
    Get.put<AuthService>(signedInFakeAuth());
    Get.put(ProfileController());

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: ProfileView())));
    await tester.pump();
    await tester.pump();

    expect(find.text('Turab Raza'), findsWidgets);
    expect(find.text('Verified Resident'), findsOneWidget);
    expect(find.text('+92 300 1234567'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text("Can't be changed without re-verification"), findsOneWidget);
    expect(find.text('35202-1234567-1'), findsOneWidget);
    expect(find.text('Used for identity verification only'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Delete Account'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('Saving changes persists the edited name', (tester) async {
    final fakeAuth = signedInFakeAuth();
    Get.put<AuthService>(fakeAuth);
    Get.put(ProfileController());

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: ProfileView())));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Turab Raza'), 'Ayesha Khan');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(fakeAuth.profiles['resident-1']?['name'], 'Ayesha Khan');
  });

  testWidgets('Logging out clears the session and returns to Login', (tester) async {
    Get.put<AuthService>(signedInFakeAuth());

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.dashboard,
        getPages: AppPages.routes,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(find.byType(ProfileView), findsOneWidget);

    final profileList = find.descendant(of: find.byType(ProfileView), matching: find.byType(ListView));
    await tester.dragUntilVisible(
      find.text('Log Out'),
      profileList,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.tap(find.text('Log Out'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Confirming account deletion returns to Login', (tester) async {
    Get.put<AuthService>(signedInFakeAuth());

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.dashboard,
        getPages: AppPages.routes,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Profile'));
    await tester.pump();

    final profileList = find.descendant(of: find.byType(ProfileView), matching: find.byType(ListView));
    await tester.dragUntilVisible(
      find.text('Delete Account'),
      profileList,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.tap(find.text('Delete Account'));
    await tester.pump();

    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Shows a banner when notifications are denied, and hides it once granted', (
    tester,
  ) async {
    final fakeAuth = signedInFakeAuth();
    Get.put<AuthService>(fakeAuth);
    final fakePush = Get.find<PushNotificationService>() as FakePushNotificationService;
    fakePush.permissionGranted = false;

    Get.put(ProfileController());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: ProfileView())));
    await tester.pump();
    await tester.pump();

    expect(find.text('Notifications are turned off'), findsOneWidget);

    fakePush.permissionGranted = true;
    await tester.tap(find.text("I've enabled it — check again"));
    await tester.pump();

    expect(find.text('Notifications are turned off'), findsNothing);
  });

  testWidgets('No banner at all when notifications are already permitted', (tester) async {
    final fakeAuth = signedInFakeAuth();
    Get.put<AuthService>(fakeAuth);
    (Get.find<PushNotificationService>() as FakePushNotificationService).permissionGranted = true;

    Get.put(ProfileController());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: ProfileView())));
    await tester.pump();
    await tester.pump();

    expect(find.text('Notifications are turned off'), findsNothing);
  });
}

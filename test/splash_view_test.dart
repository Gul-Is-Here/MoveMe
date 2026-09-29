import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/routes/app_pages.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/deep_link_service.dart';
import 'package:parktag_app/app/services/onboarding_service.dart';
import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/dashboard/models/message_thread_model.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_conversation_service.dart';
import 'support/fake_deep_link_service.dart';
import 'support/fake_onboarding_service.dart';
import 'support/fake_push_notification_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    Get.reset();
    Get.put<ConversationService>(FakeConversationService());
    Get.put<VehicleService>(FakeVehicleService());
    Get.put<PushNotificationService>(FakePushNotificationService());
    Get.put<DeepLinkService>(FakeDeepLinkService());
  });

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
    await tester.pump();
  }

  testWidgets('Splash screen renders wordmark', (tester) async {
    Get.put<AuthService>(FakeAuthService());
    Get.put<OnboardingService>(FakeOnboardingService());

    await pumpSplash(tester);

    // The wordmark and tagline animate in letter by letter / word by word,
    // so they're asserted by their accessible labels rather than one Text.
    expect(find.bySemanticsLabel('MoveMe'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan. Message. Move on.'), findsOneWidget);
    expect(find.text('GETTING THINGS READY'), findsOneWidget);

    // Flush the SplashController's pending navigation timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('First-ever open (onboarding not seen, not signed in) shows Onboarding', (tester) async {
    Get.put<AuthService>(FakeAuthService());
    Get.put<OnboardingService>(FakeOnboardingService()..seen = false);

    await pumpSplash(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Put a tag on\nyour car'), findsOneWidget);
  });

  testWidgets('Returning, signed-out resident (onboarding already seen) goes to Login', (tester) async {
    Get.put<AuthService>(FakeAuthService());
    Get.put<OnboardingService>(FakeOnboardingService()..seen = true);

    await pumpSplash(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Signed-in resident skips Onboarding/Login and lands on Dashboard', (tester) async {
    final fakeAuth = FakeAuthService();
    await fakeAuth.confirmOtp(verificationId: 'v', smsCode: '123456');
    Get.put<AuthService>(fakeAuth);
    // Onboarding not seen — signed-in status should still win.
    Get.put<OnboardingService>(FakeOnboardingService()..seen = false);

    await pumpSplash(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Your vehicles'), findsOneWidget);
  });

  testWidgets('A chat notification tapped while the app was closed opens straight into that thread', (
    tester,
  ) async {
    final fakeAuth = FakeAuthService();
    await fakeAuth.confirmOtp(verificationId: 'v', smsCode: '123456');
    Get.put<AuthService>(fakeAuth);
    Get.put<OnboardingService>(FakeOnboardingService()..seen = true);

    // setUp already registered a default FakePushNotificationService — replace
    // it (Get.put never overwrites an already-registered instance) with one
    // seeded with a pending thread.
    Get.delete<PushNotificationService>(force: true);
    final fakePush = FakePushNotificationService()
      ..pendingThread = const MessageThreadModel(
        conversationId: 'v1_scanner-1',
        scannerName: 'Bilal Ahmed',
        plateNumber: 'LEB-4470',
        vehicleColor: Color(0xFF2B2B2B),
        lastMessagePreview: 'Please move your car',
        timeLabel: 'Just now',
        unreadCount: 1,
      );
    Get.put<PushNotificationService>(fakePush);

    await pumpSplash(tester);
    await tester.pump(const Duration(seconds: 3));
    // Two navigations fire back to back here (Dashboard, then Chat Thread
    // pushed on top) — give both transitions time to finish.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Lands on the chat thread — not just the Dashboard behind it.
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('LEB-4470'), findsOneWidget);
    expect(fakePush.syncTokenCallCount, 1);
    expect(fakePush.consumePendingChatThread(), isNull, reason: 'consumed exactly once');
  });
}

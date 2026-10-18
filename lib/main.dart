import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/services/admin_service.dart';
import 'app/services/auth_service.dart';
import 'app/services/conversation_service.dart';
import 'app/services/deep_link_service.dart';
import 'app/services/onboarding_service.dart';
import 'app/services/order_service.dart';
import 'app/services/push_notification_service.dart';
import 'app/services/rc_ocr_service.dart';
import 'app/services/session_watcher.dart';
import 'app/services/vehicle_service.dart';
import 'app/theme/theme_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On web, drop the `#` from URLs so a shared `/scan/{vehicleId}` link
  // (FR-04) works without it — a no-op on mobile.
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
    // Score-based reCAPTCHA Enterprise key, scoped to moveme-da262.web.app
    // and moveme-da262.firebaseapp.com (gcloud recaptcha keys create).
    providerWeb: ReCaptchaEnterpriseProvider('6LfuE9YtAAAAAGWxLdUwkhiXK0at9Il78idiNALn'),
  );

  // Must be registered before runApp so FCM can hand it background/
  // terminated-app messages. Web push needs its own service worker this
  // project doesn't have yet, so this is mobile-only (see
  // PushNotificationService.init).
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Without this Firebase sends a null X-Firebase-Locale header and logs a
  // warning; it also decides what language the OTP SMS is written in.
  await FirebaseAuth.instance.setLanguageCode('en');

  // Opt-in only (`--dart-define=FAKE_PHONE_AUTH=true`): with app
  // verification disabled, Firebase accepts ONLY the fictional test numbers
  // from Firebase Console > Authentication > Phone. Real numbers then fail
  // on iOS with "request does not contain a client identifier".
  if (kDebugMode && const bool.fromEnvironment('FAKE_PHONE_AUTH')) {
    debugPrint(
      '[PhoneAuth] FAKE_PHONE_AUTH is ON — app verification disabled. Only '
      'Firebase test numbers will work; real numbers fail with '
      '"missing-client-identifier". Run without --dart-define=FAKE_PHONE_AUTH=true '
      'to use real numbers.',
    );
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }

  Get.put(ThemeController(), permanent: true);
  // Firebase's native Phone Auth (real SMS via Firebase); FAKE_PHONE_AUTH
  // additionally disables app verification so Console test numbers work.
  Get.put<AuthService>(FirebaseAuthService(), permanent: true);
  Get.put<OnboardingService>(SharedPrefsOnboardingService(), permanent: true);
  Get.put<VehicleService>(FirebaseVehicleService(), permanent: true);
  Get.put<ConversationService>(FirebaseConversationService(), permanent: true);
  Get.put<RcOcrService>(OpenAiRcOcrService(), permanent: true);
  Get.put<OrderService>(FirebaseOrderService(), permanent: true);
  Get.put<AdminService>(FirebaseAdminService(), permanent: true);
  final pushService = Get.put<PushNotificationService>(
    FirebasePushNotificationService(),
    permanent: true,
  );
  await pushService.init();
  final deepLinkService = Get.put<DeepLinkService>(
    AppLinksDeepLinkService(),
    permanent: true,
  );
  await deepLinkService.init();
  watchForcedSignOuts(Get.find<AuthService>());
  runApp(const MyApp());
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../firebase_options.dart';
import '../../modules/dashboard/models/message_thread_model.dart';
import '../routes/app_routes.dart';
import '../utils/vehicle_color.dart';
import 'auth_service.dart';
import '../widgets/app_snackbar.dart';

/// Runs in a separate isolate for background/terminated-app messages, so it
/// must be a top-level (or static) function, and re-initializes Firebase
/// itself since nothing else in this isolate has done so.
///
/// FCM already renders the notification tray entry from the payload's
/// `notification` block without any help from here — this handler exists so
/// a background data-only message wouldn't be silently dropped if one is
/// ever sent, and so the framework doesn't warn about a missing handler.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Wraps Firebase Cloud Messaging: registers this device for chat push
/// notifications (FR-05/FR-06 — a resident gets notified when someone
/// messages them about a scanned vehicle) and routes a notification tap to
/// the right Chat thread.
abstract class PushNotificationService {
  Future<void> init();

  /// Whether the resident has actually granted notification permission.
  ///
  /// Worth surfacing because a denial is invisible from the server side:
  /// FCM still reports a push as successfully delivered to the device, and
  /// Android simply never displays it. Without this, "no notifications"
  /// looks identical to a broken token.
  Future<bool> hasPermission();

  /// Fetches this device's current FCM token and saves it to the signed-in
  /// resident's profile. Call after sign-in/sign-up, and again on app start
  /// for an already-signed-in resident — a token can be issued before the
  /// resident is signed in, or can rotate between sessions.
  Future<void> syncToken();

  /// Call before signing out so this device stops receiving another
  /// resident's notifications if someone else signs in on it.
  Future<void> unregisterToken();

  /// A chat thread to open because the resident tapped a notification while
  /// the app was fully closed — captured before `GetMaterialApp` existed to
  /// navigate anywhere, so `SplashController` picks it up once routing is
  /// ready and consumes it (returns null every time after the first read).
  MessageThreadModel? consumePendingChatThread();

  /// An order notification tapped while the app was closed, picked up by
  /// Splash once routing is ready.
  PendingOrderOpen? consumePendingOrder();
}

/// Which order a tapped notification is about, and whose side opens it.
class PendingOrderOpen {
  const PendingOrderOpen({required this.number, required this.forAdmin});

  final String number;
  final bool forAdmin;

  String get route => forAdmin ? AppRoutes.adminOrder : AppRoutes.orderDetails;

  static PendingOrderOpen? fromData(Map<String, dynamic> data) {
    final number = data['orderId'] as String?;
    if (data['type'] != 'order' || number == null || number.isEmpty) return null;
    return PendingOrderOpen(number: number, forAdmin: data['audience'] == 'admin');
  }
}

class FirebasePushNotificationService implements PushNotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _authService = Get.find<AuthService>();

  String? _currentToken;
  MessageThreadModel? _pendingThread;
  PendingOrderOpen? _pendingOrder;

  @override
  Future<void> init() async {
    // Web push needs its own VAPID key + service worker setup that hasn't
    // been done for this project, and the public Scan Contact Page is
    // anonymous anyway (nothing to notify) — mobile only, for now.
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // Android 13+ and iOS both require the resident to accept this prompt.
    // If they decline, every push still leaves the server "successfully
    // delivered" and is then dropped by the OS, so log it plainly rather
    // than letting it look like a backend problem.
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint(
        'PushNotificationService: notifications NOT permitted '
        '(${settings.authorizationStatus.name}). Pushes will be delivered to '
        'the device and silently discarded until this is granted in system '
        'settings.',
      );
    }

    _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      final uid = _authService.currentUid;
      if (uid != null) _authService.saveFcmToken(uid: uid, token: token);
    });

    // App open (foreground): surface it ourselves since the OS won't.
    FirebaseMessaging.onMessage.listen(_showForegroundBanner);

    // App backgrounded, resident tapped the tray notification: GetMaterialApp
    // is already alive, so navigate right away.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // App was fully closed and opened via the tray notification: routing
    // isn't ready yet, so stash it for SplashController to pick up.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingThread = _threadFromMessage(initialMessage);
      _pendingOrder = PendingOrderOpen.fromData(initialMessage.data);
    }
  }

  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> syncToken() async {
    if (kIsWeb) return;
    final uid = _authService.currentUid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token == null) {
      debugPrint('PushNotificationService: getToken() returned null — no token to save.');
      return;
    }
    _currentToken = token;
    await _authService.saveFcmToken(uid: uid, token: token);
    debugPrint('PushNotificationService: saved FCM token for $uid (…${token.substring(token.length - 8)}).');
  }

  @override
  Future<void> unregisterToken() async {
    if (kIsWeb) return;
    final uid = _authService.currentUid;
    final token = _currentToken ?? await _messaging.getToken();
    if (uid == null || token == null) return;
    await _authService.removeFcmToken(uid: uid, token: token);
  }

  @override
  MessageThreadModel? consumePendingChatThread() {
    final thread = _pendingThread;
    _pendingThread = null;
    return thread;
  }

  @override
  PendingOrderOpen? consumePendingOrder() {
    final order = _pendingOrder;
    _pendingOrder = null;
    return order;
  }

  void _showForegroundBanner(RemoteMessage message) {
    final order = PendingOrderOpen.fromData(message.data);
    if (order != null) {
      AppSnackbar.show(
        message.notification?.title ?? 'Order update',
        message.notification?.body ?? '',
        position: SnackPosition.TOP,
        onTap: (_) => Get.toNamed(order.route, arguments: order.number),
      );
      return;
    }
    final thread = _threadFromMessage(message);
    if (thread == null) return;
    // Colours come from AppSnackbar now — every snackbar in the app is
    // brand yellow with black text. Only the tap behaviour is per-call.
    // Shown at the TOP: this is an incoming-message alert, not feedback on
    // something the resident just did on screen (which is what the bottom
    // position is for) — it needs to read like a notification, not get
    // lost near whatever they're doing at the bottom of the screen (e.g.
    // typing in another chat's composer).
    AppSnackbar.show(
      message.notification?.title ?? 'New message',
      message.notification?.body ?? thread.lastMessagePreview,
      position: SnackPosition.TOP,
      onTap: (_) => Get.toNamed(AppRoutes.chatThread, arguments: thread),
    );
  }

  void _handleMessageNavigation(RemoteMessage message) {
    final order = PendingOrderOpen.fromData(message.data);
    if (order != null) {
      Get.toNamed(order.route, arguments: order.number);
      return;
    }
    final thread = _threadFromMessage(message);
    if (thread == null) return;
    Get.toNamed(AppRoutes.chatThread, arguments: thread);
  }

  /// The Cloud Function that sends these (`functions/index.js`) always
  /// includes `conversationId` in the data payload — anything else missing
  /// just means a slightly less complete header on the Chat screen, since
  /// its real data streams in live from Firestore once opened.
  MessageThreadModel? _threadFromMessage(RemoteMessage message) {
    final conversationId = message.data['conversationId'] as String?;
    if (conversationId == null || conversationId.isEmpty) return null;

    final colorName = message.data['colorName'] as String? ?? '';
    return MessageThreadModel(
      conversationId: conversationId,
      scannerName: message.data['scannerName'] as String? ?? 'Anonymous',
      plateNumber: message.data['plateNumber'] as String? ?? '',
      vehicleColor: vehicleColorForName(colorName),
      lastMessagePreview: message.notification?.body ?? '',
      timeLabel: 'Just now',
      unreadCount: 1,
    );
  }
}

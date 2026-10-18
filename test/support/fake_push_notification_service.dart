import 'package:parktag_app/app/services/push_notification_service.dart';
import 'package:parktag_app/modules/dashboard/models/message_thread_model.dart';

/// In-memory stand-in for [PushNotificationService] so widget tests never
/// touch FCM. [pendingThread] lets a test simulate "the resident tapped a
/// chat notification while the app was fully closed" by seeding it before
/// pumping Splash.
class FakePushNotificationService implements PushNotificationService {
  MessageThreadModel? pendingThread;

  int syncTokenCallCount = 0;
  int unregisterCallCount = 0;
  bool permissionGranted = true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> syncToken() async {
    syncTokenCallCount++;
  }

  @override
  Future<void> unregisterToken() async {
    unregisterCallCount++;
  }

  @override
  MessageThreadModel? consumePendingChatThread() {
    final thread = pendingThread;
    pendingThread = null;
    return thread;
  }

  PendingOrderOpen? pendingOrder;

  @override
  PendingOrderOpen? consumePendingOrder() {
    final order = pendingOrder;
    pendingOrder = null;
    return order;
  }
}

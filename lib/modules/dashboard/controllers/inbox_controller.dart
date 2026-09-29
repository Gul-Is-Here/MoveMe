import 'dart:async';

import 'package:get/get.dart';

import '../../../app/services/auth_service.dart';
import '../../../app/services/conversation_service.dart';
import '../../../app/utils/vehicle_color.dart';
import '../models/message_thread_model.dart';

/// Which slice of the Inbox is on screen. Deliberately limited to filters
/// the Firestore documents can actually answer (`unreadForOwner`,
/// `resolved`) — there is no mute/archive/pin field to filter on.
enum InboxFilter { all, unread, resolved }

class InboxController extends GetxController {
  final _conversationService = Get.find<ConversationService>();
  final _authService = Get.find<AuthService>();

  /// Every conversation on a vehicle this resident owns, newest first
  /// (the ordering comes from the Firestore query, not from here).
  final threads = <MessageThreadModel>[].obs;

  /// FR-09: conversations this resident started as an anonymous scanner
  /// (messaging someone else's car) before/without owning the vehicle,
  /// once linked via [ConversationService.linkScannerIdentity].
  final sentThreads = <MessageThreadModel>[].obs;

  /// True until the first snapshot lands, so the view can show skeleton
  /// cards instead of flashing the "no messages yet" empty state at
  /// someone who actually has messages.
  final isLoading = true.obs;

  /// Set if the conversations stream errors (offline, permission denied).
  /// The view turns this into a retry affordance rather than a blank tab.
  final hasError = false.obs;

  /// Vehicle ids with at least one unread conversation, for the Home tab's
  /// per-vehicle dot. Derived from the summaries this controller already
  /// listens to — the Home tab does NOT open a second listener for it.
  final unreadVehicleIds = <String>{}.obs;

  final query = ''.obs;
  final filter = InboxFilter.all.obs;
  final isSearching = false.obs;

  StreamSubscription<List<ConversationSummary>>? _sub;
  StreamSubscription<List<ConversationSummary>>? _sentSub;

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  void _listen() {
    final uid = _authService.currentUid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }

    hasError.value = false;
    isLoading.value = true;

    _sub?.cancel();
    _sentSub?.cancel();

    _sub = _conversationService.watchOwnerConversations(uid).listen(
      (summaries) {
        threads.assignAll(summaries.map(_toOwnerThread));
        unreadVehicleIds.assignAll(
          summaries.where((s) => s.unreadForOwner).map((s) => s.vehicleId),
        );
        isLoading.value = false;
        hasError.value = false;
      },
      onError: (_) {
        isLoading.value = false;
        hasError.value = true;
      },
    );
    _sentSub = _conversationService.watchScannerConversations(uid).listen(
      (summaries) => sentThreads.assignAll(summaries.map(_toScannerThread)),
      onError: (_) {},
    );
  }

  /// Retry after [hasError] — re-subscribes rather than reloading the app.
  void retry() => _listen();

  /// Number of conversations with anything unread.
  int get unreadThreadCount =>
      threads.where((t) => t.unreadCount > 0).length +
      sentThreads.where((t) => t.unreadCount > 0).length;

  /// Total unread *messages* across every conversation — what the Home
  /// tab's Messages badge shows.
  int get unreadMessageCount =>
      threads.fold<int>(0, (sum, t) => sum + t.unreadCount) +
      sentThreads.fold<int>(0, (sum, t) => sum + t.unreadCount);

  /// Search runs over the summaries already held in memory. The Inbox is
  /// one Firestore listener's worth of documents, so matching locally is
  /// both instant and free — no per-keystroke query, and nothing to
  /// debounce.
  List<MessageThreadModel> get visibleThreads => _apply(threads);
  List<MessageThreadModel> get visibleSentThreads => _apply(sentThreads);

  List<MessageThreadModel> _apply(List<MessageThreadModel> source) {
    final q = query.value.trim().toLowerCase();
    return source.where((t) {
      switch (filter.value) {
        case InboxFilter.unread:
          if (t.unreadCount == 0) return false;
        case InboxFilter.resolved:
          if (!t.isResolved) return false;
        case InboxFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return t.scannerName.toLowerCase().contains(q) ||
          t.ownerName.toLowerCase().contains(q) ||
          t.plateNumber.toLowerCase().contains(q) ||
          t.lastMessagePreview.toLowerCase().contains(q);
    }).toList();
  }

  void setQuery(String value) => query.value = value;

  void setFilter(InboxFilter value) => filter.value = value;

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) query.value = '';
  }

  void markAllRead() {
    for (final thread in threads.where((t) => t.unreadCount > 0)) {
      _conversationService.markReadByOwner(thread.conversationId);
    }
    for (final thread in sentThreads.where((t) => t.unreadCount > 0)) {
      _conversationService.markReadByScanner(thread.conversationId);
    }
  }

  /// Marks one conversation read from whichever side this resident is on
  /// in it — the swipe action on an Inbox row.
  void markThreadRead(MessageThreadModel thread) {
    if (thread.unreadCount == 0) return;
    if (thread.viewerRole == ThreadViewerRole.owner) {
      _conversationService.markReadByOwner(thread.conversationId);
    } else {
      _conversationService.markReadByScanner(thread.conversationId);
    }
  }

  MessageThreadModel _toOwnerThread(ConversationSummary summary) => MessageThreadModel(
    conversationId: summary.conversationId,
    scannerName: summary.scannerName,
    plateNumber: summary.plateNumber,
    vehicleColor: vehicleColorForName(summary.colorName),
    lastMessagePreview: summary.lastMessagePreview,
    timeLabel: formatThreadTime(summary.lastMessageAt),
    unreadCount: summary.unreadCountForOwner,
    isResolved: summary.resolved,
    viewerRole: ThreadViewerRole.owner,
  );

  /// The "Sent" section — this resident is the *scanner* here, so the
  /// badge comes from `unreadForScanner` (the owner's replies), not
  /// `unreadForOwner`, and the counterpart shown is the vehicle's owner,
  /// not [summary.scannerName] (which would just be this resident's own
  /// name).
  MessageThreadModel _toScannerThread(ConversationSummary summary) => MessageThreadModel(
    conversationId: summary.conversationId,
    scannerName: summary.scannerName,
    ownerName: summary.ownerName,
    plateNumber: summary.plateNumber,
    vehicleColor: vehicleColorForName(summary.colorName),
    lastMessagePreview: summary.lastMessagePreview,
    timeLabel: formatThreadTime(summary.lastMessageAt),
    unreadCount: summary.unreadCountForScanner,
    isResolved: summary.resolved,
    viewerRole: ThreadViewerRole.scanner,
  );

  @override
  void onClose() {
    _sub?.cancel();
    _sentSub?.cancel();
    super.onClose();
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Contextual conversation-list timestamp: clock time for today,
/// "Yesterday", weekday within the last week, then a date — and the year
/// too once the message is from a previous one.
String formatThreadTime(DateTime? at) {
  if (at == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(at.year, at.month, at.day);
  final daysApart = today.difference(thatDay).inDays;

  if (daysApart == 0) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$hour:${at.minute.toString().padLeft(2, '0')} ${at.hour >= 12 ? 'PM' : 'AM'}';
  }
  if (daysApart == 1) return 'Yesterday';
  if (daysApart < 7) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[at.weekday - 1];
  }
  if (at.year == now.year) return '${_months[at.month - 1]} ${at.day}';
  return '${_months[at.month - 1]} ${at.day}, ${at.year}';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/modules/dashboard/controllers/inbox_controller.dart';
import 'package:parktag_app/modules/dashboard/views/inbox_view.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_conversation_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeConversationService fakeConversations;

  setUp(() {
    Get.reset();
    final fakeAuth = FakeAuthService();
    fakeAuth.signInAs(uid: 'resident-1', phone: '+923001234567');
    Get.put<AuthService>(fakeAuth);
    fakeConversations = FakeConversationService();
    Get.put<ConversationService>(fakeConversations);
  });

  void seedThreeThreads() {
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v1_scanner-1',
        vehicleId: 'v1',
        ownerUid: 'resident-1',
        scannerName: 'Anonymous',
        plateNumber: 'LEA-2231',
        colorName: 'White',
        resolved: false,
        unreadForOwner: true,
        lastMessagePreview: 'Please move your car',
        lastMessageAt: null,
      ),
    );
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v2_scanner-2',
        vehicleId: 'v2',
        ownerUid: 'resident-1',
        scannerName: 'Bilal Ahmed',
        plateNumber: 'LEB-4470',
        colorName: 'Black',
        resolved: false,
        unreadForOwner: true,
        lastMessagePreview: 'Voice note',
        lastMessageAt: null,
      ),
    );
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v3_scanner-3',
        vehicleId: 'v3',
        ownerUid: 'resident-1',
        scannerName: 'Sana Malik',
        plateNumber: 'LEC-9102',
        colorName: 'Silver',
        resolved: true,
        unreadForOwner: false,
        lastMessagePreview: 'Thanks, moved it now!',
        lastMessageAt: null,
      ),
    );
  }

  testWidgets('Inbox shows threads with unread and resolved states', (tester) async {
    Get.put(InboxController());
    seedThreeThreads();

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    expect(find.text('Inbox'), findsOneWidget);
    // Two unread conversations, one message each, on two distinct
    // vehicles — the third vehicle has nothing waiting on it and is no
    // longer counted.
    expect(find.text('2 unread messages across 2 vehicles'), findsOneWidget);
    expect(find.text('Anonymous'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('RESOLVED'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('Mark all read clears every unread badge and the summary', (tester) async {
    final controller = Get.put(InboxController());
    seedThreeThreads();

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    await tester.tap(find.text('Mark all read'));
    await tester.pump();

    expect(controller.unreadThreadCount, 0);
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('Searching filters threads by name, plate and message text', (tester) async {
    final controller = Get.put(InboxController());
    seedThreeThreads();

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    controller.setQuery('bilal');
    await tester.pump();
    expect(controller.visibleThreads.map((t) => t.scannerName), ['Bilal Ahmed']);

    controller.setQuery('LEC-9102');
    await tester.pump();
    expect(controller.visibleThreads.map((t) => t.scannerName), ['Sana Malik']);

    controller.setQuery('moved it');
    await tester.pump();
    expect(controller.visibleThreads.map((t) => t.scannerName), ['Sana Malik']);

    controller.setQuery('nothing matches this');
    await tester.pump();
    expect(controller.visibleThreads, isEmpty);
    expect(find.text('No conversations match'), findsOneWidget);
  });

  testWidgets('Unread and Resolved filters narrow the list', (tester) async {
    final controller = Get.put(InboxController());
    seedThreeThreads();

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    controller.setFilter(InboxFilter.unread);
    await tester.pump();
    expect(controller.visibleThreads.length, 2);
    expect(controller.visibleThreads.every((t) => t.unreadCount > 0), isTrue);

    controller.setFilter(InboxFilter.resolved);
    await tester.pump();
    expect(controller.visibleThreads.map((t) => t.scannerName), ['Sana Malik']);

    controller.setFilter(InboxFilter.all);
    await tester.pump();
    expect(controller.visibleThreads.length, 3);
  });

  test('Thread timestamps use contextual conversation-list formatting', () {
    final now = DateTime.now();
    final todayAt = DateTime(now.year, now.month, now.day, 22, 42);

    expect(formatThreadTime(null), '');
    expect(formatThreadTime(todayAt), '10:42 PM');
    expect(formatThreadTime(todayAt.subtract(const Duration(days: 1))), 'Yesterday');
    // Older than a week but this year -> "Mon D"; previous years carry the year.
    final old = DateTime(now.year - 1, 3, 7, 9, 5);
    expect(formatThreadTime(old), 'Mar 7, ${now.year - 1}');
  });

  testWidgets("An owner's reply is unread for the scanner until they open it", (tester) async {
    final controller = Get.put(InboxController());

    // A conversation this resident started by scanning someone else's car.
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v9_resident-1',
        vehicleId: 'v9',
        ownerUid: 'other-resident',
        ownerName: 'Imran Shah',
        scannerUid: 'resident-1',
        scannerName: 'Me',
        plateNumber: 'LED-3311',
        colorName: 'Blue',
        resolved: false,
        unreadForOwner: false,
        lastMessagePreview: 'Sorry, moving now',
        lastMessageAt: null,
      ),
    );

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    expect(controller.sentThreads.single.unreadCount, 0);

    // The car's owner replies. That must land as unread for the scanner —
    // previously there was no scanner-side flag at all, so their replies
    // were silently counted as already read.
    await fakeConversations.sendOwnerReply(
      conversationId: 'v9_resident-1',
      text: 'On my way down',
    );
    await tester.pump();

    expect(controller.sentThreads.single.unreadCount, 1);
    expect(controller.unreadThreadCount, 1);

    // Reading it clears only the scanner's flag.
    await fakeConversations.markReadByScanner('v9_resident-1');
    await tester.pump();

    expect(controller.sentThreads.single.unreadCount, 0);
    expect(controller.unreadThreadCount, 0);
  });

  testWidgets('The owner reading a thread does not clear it for the scanner', (tester) async {
    Get.put(InboxController());
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v8_s8',
        vehicleId: 'v8',
        ownerUid: 'resident-1',
        scannerName: 'Zara',
        plateNumber: 'LEF-1000',
        colorName: 'Red',
        resolved: false,
        unreadForOwner: true,
        unreadForScanner: true,
        lastMessagePreview: 'Hello',
        lastMessageAt: null,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    await fakeConversations.markReadByOwner('v8_s8');
    await tester.pump();

    final summary = fakeConversations.summaryFor('v8_s8')!;
    expect(summary.unreadForOwner, isFalse);
    expect(summary.unreadForScanner, isTrue, reason: 'the two sides are tracked separately');
  });

  testWidgets('The badge counts unread messages, not just "has unread"', (tester) async {
    final controller = Get.put(InboxController());
    fakeConversations.seed(
      const ConversationSummary(
        conversationId: 'v7_s7',
        vehicleId: 'v7',
        ownerUid: 'resident-1',
        scannerName: 'Hamza',
        plateNumber: 'LEG-7777',
        colorName: 'Grey',
        resolved: false,
        unreadForOwner: false,
        lastMessagePreview: '',
        lastMessageAt: null,
      ),
    );

    await tester.pumpWidget(const GetMaterialApp(home: InboxView()));
    await tester.pump();

    for (final text in ['Hello', 'Are you there', 'Please move']) {
      await fakeConversations.simulateScannerMessage(
        vehicleId: 'v7',
        scannerId: 's7',
        ownerUid: 'resident-1',
        plateNumber: 'LEG-7777',
        colorName: 'Grey',
        scannerName: 'Hamza',
        text: text,
      );
    }
    await tester.pump();

    // Three messages in one conversation: one unread thread, three unread
    // messages. The badge shows the message count.
    expect(controller.threads.single.unreadCount, 3);
    expect(controller.unreadThreadCount, 1);
    expect(controller.unreadMessageCount, 3);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('3 unread messages across 1 vehicle'), findsOneWidget);

    // Opening the thread clears the whole count, not one message.
    await fakeConversations.markReadByOwner('v7_s7');
    await tester.pump();

    expect(controller.threads.single.unreadCount, 0);
    expect(controller.unreadMessageCount, 0);
    expect(find.text('3'), findsNothing);
  });

  test('A conversation predating the counters falls back to its boolean flag', () {
    // Documents written before unreadCountFor* existed carry only the
    // flags; they must still show a badge rather than losing it.
    const legacy = ConversationSummary(
      conversationId: 'old_1',
      vehicleId: 'old',
      ownerUid: 'resident-1',
      scannerName: 'Someone',
      plateNumber: 'OLD-1',
      colorName: 'White',
      resolved: false,
      unreadForOwner: true,
      lastMessagePreview: 'hi',
      lastMessageAt: null,
    );
    fakeConversations.seed(legacy);
    expect(fakeConversations.summaryFor('old_1')!.unreadCountForOwner, 1);
  });
}

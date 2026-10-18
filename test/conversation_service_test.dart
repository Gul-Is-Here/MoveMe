import 'package:flutter_test/flutter_test.dart';
import 'package:parktag_app/app/services/conversation_service.dart';

import 'support/fake_conversation_service.dart';

void main() {
  test('conversationIdFor scopes a thread to one vehicle and one scanner', () {
    expect(conversationIdFor('v1', 'scanner-A'), 'v1_scanner-A');
    expect(conversationIdFor('v1', 'scanner-A'), isNot(conversationIdFor('v1', 'scanner-B')));
    expect(conversationIdFor('v1', 'scanner-A'), isNot(conversationIdFor('v2', 'scanner-A')));
  });

  test(
    'Two different scanners of the same vehicle land in two separate conversations, '
    'neither seeing the other\'s messages',
    () async {
      final service = FakeConversationService();

      await service.simulateScannerMessage(
        vehicleId: 'v1',
        scannerId: 'scanner-A',
        ownerUid: 'resident-1',
        plateNumber: 'LEA-2231',
        colorName: 'White',
        scannerName: 'Ali',
        text: 'Please move your car',
      );
      await service.simulateScannerMessage(
        vehicleId: 'v1',
        scannerId: 'scanner-B',
        ownerUid: 'resident-1',
        plateNumber: 'LEA-2231',
        colorName: 'White',
        scannerName: 'Sara',
        text: 'You are blocking the exit',
      );

      // The owner's Inbox sees both as distinct threads for the same vehicle.
      final threads = await service.watchOwnerConversations('resident-1').first;
      expect(threads, hasLength(2));
      expect(threads.map((t) => t.scannerName).toSet(), {'Ali', 'Sara'});
      expect(threads.map((t) => t.vehicleId).toSet(), {'v1'});

      // Each scanner's own thread only ever contains their own message.
      final messagesA = await service.watchMessages(conversationIdFor('v1', 'scanner-A')).first;
      final messagesB = await service.watchMessages(conversationIdFor('v1', 'scanner-B')).first;
      expect(messagesA.map((m) => m.text), ['Please move your car']);
      expect(messagesB.map((m) => m.text), ['You are blocking the exit']);

      // Resolving one scanner's thread never touches the other's.
      await service.setResolved(conversationId: conversationIdFor('v1', 'scanner-A'), resolved: true);
      final refreshed = await service.watchOwnerConversations('resident-1').first;
      final threadA = refreshed.firstWhere((t) => t.scannerName == 'Ali');
      final threadB = refreshed.firstWhere((t) => t.scannerName == 'Sara');
      expect(threadA.resolved, isTrue);
      expect(threadB.resolved, isFalse);
    },
  );

  test('Reopening the same conversationId (the same scanner returning) continues the existing thread', () async {
    final service = FakeConversationService();

    await service.simulateScannerMessage(
      vehicleId: 'v1',
      scannerId: 'scanner-A',
      ownerUid: 'resident-1',
      plateNumber: 'LEA-2231',
      colorName: 'White',
      scannerName: 'Ali',
      text: 'First message',
    );
    await service.simulateScannerMessage(
      vehicleId: 'v1',
      scannerId: 'scanner-A',
      ownerUid: 'resident-1',
      plateNumber: 'LEA-2231',
      colorName: 'White',
      scannerName: 'Ali',
      text: 'Second message, same scanner',
    );

    final threads = await service.watchOwnerConversations('resident-1').first;
    expect(threads, hasLength(1));

    final messages = await service.watchMessages(conversationIdFor('v1', 'scanner-A')).first;
    expect(messages.map((m) => m.text), ['First message', 'Second message, same scanner']);
  });

  group('resolveVehicleAndOpenChat (authenticated in-app QR scan / deep link)', () {
    test('a valid vehicle resolves to a deterministic conversationId and creates the room once', () async {
      final service = FakeConversationService();
      service.callerUid = 'resident-2';
      service.vehicles['v1'] = (
        ownerUid: 'resident-1',
        ownerName: 'Ayesha Khan',
        plateNumber: 'LEA-2231',
        colorName: 'White',
      );

      final result = await service.resolveVehicleAndOpenChat(vehicleId: 'v1');

      expect(result.conversationId, conversationIdFor('v1', 'resident-2'));
      expect(result.ownerName, 'Ayesha Khan');
      expect(result.plateNumber, 'LEA-2231');
      expect(service.resolvedNewChats, ['v1']);
    });

    test('scanning the same vehicle twice never creates a duplicate room', () async {
      final service = FakeConversationService();
      service.callerUid = 'resident-2';
      service.vehicles['v1'] = (
        ownerUid: 'resident-1',
        ownerName: 'Ayesha Khan',
        plateNumber: 'LEA-2231',
        colorName: 'White',
      );

      final first = await service.resolveVehicleAndOpenChat(vehicleId: 'v1');
      final second = await service.resolveVehicleAndOpenChat(vehicleId: 'v1');

      expect(first.conversationId, second.conversationId);
      // Only counted as a new room once — the second call just returned it.
      expect(service.resolvedNewChats, ['v1']);
    });

    test('an unknown vehicle id throws instead of creating a room', () async {
      final service = FakeConversationService();
      service.callerUid = 'resident-2';

      expect(
        () => service.resolveVehicleAndOpenChat(vehicleId: 'not-a-real-vehicle'),
        throwsA(isA<ResolveVehicleException>()),
      );
    });

    test("scanning your own vehicle's QR is rejected", () async {
      final service = FakeConversationService();
      service.callerUid = 'resident-1';
      service.vehicles['v1'] = (
        ownerUid: 'resident-1',
        ownerName: 'Ayesha Khan',
        plateNumber: 'LEA-2231',
        colorName: 'White',
      );

      expect(
        () => service.resolveVehicleAndOpenChat(vehicleId: 'v1'),
        throwsA(isA<ResolveVehicleException>()),
      );
    });
  });
}

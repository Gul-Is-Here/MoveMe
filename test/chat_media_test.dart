import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/deep_link_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/chat/widgets/chat_bubble.dart';
import 'package:parktag_app/modules/dashboard/models/chat_message_model.dart';
import 'package:parktag_app/modules/scan/bindings/scan_contact_binding.dart';
import 'package:parktag_app/modules/scan/controllers/scan_contact_controller.dart';
import 'package:parktag_app/modules/scan/views/scan_contact_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_conversation_service.dart';
import 'support/fake_deep_link_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  late FakeVehicleService vehicles;
  late FakeConversationService conversations;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    vehicles = FakeVehicleService();
    conversations = FakeConversationService(publicVehicleLookup: vehicles.fetchPublicVehicle);
    Get.put<VehicleService>(vehicles);
    Get.put<ConversationService>(conversations);
    Get.put<DeepLinkService>(FakeDeepLinkService());
    await vehicles.saveVehicle(
      uid: 'resident-1',
      ownerName: 'Ayesha Khan',
      nickname: 'White Corolla',
      make: 'Toyota',
      model: 'Corolla',
      plateNumber: 'LEA-2231',
      colorName: 'White',
      dateOfRegistration: '',
      engineNumber: '',
      chassisNumber: '',
      address: '',
      localPhotoPaths: const [],
    );
  });

  Future<ScanContactController> pumpScanPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    Get.parameters['vehicleId'] = 'fake-vehicle-0';
    ScanContactBinding().dependencies();
    await tester.pumpWidget(const GetMaterialApp(home: ScanContactView()));
    await tester.pump();
    await tester.pump();
    return Get.find<ScanContactController>();
  }

  ScannerDraftAttachment photo() =>
      ScannerDraftAttachment(kind: MessageKind.image, bytes: Uint8List.fromList(_png), contentType: 'image/png');
  ScannerDraftAttachment voice() => ScannerDraftAttachment(
        kind: MessageKind.voice,
        bytes: Uint8List(8),
        contentType: 'audio/webm',
        durationSeconds: 5,
      );

  testWidgets('The scan page sends text, a photo and a voice note in one go', (tester) async {
    final controller = await pumpScanPage(tester);

    controller.attachments.addAll([photo(), voice()]);
    await tester.pump();
    expect(find.byTooltip('Remove Photo'), findsOneWidget);
    expect(find.text('Voice 0:05'), findsOneWidget);

    controller.messageController.text = 'Blocking my gate';
    await controller.sendMessage();
    await tester.pump();

    expect(conversations.uploadedScannerPaths, hasLength(2));
    final messages = await conversations.watchMessages(controller.conversationId).first;
    expect(messages.map((m) => m.kind), [MessageKind.text, MessageKind.image, MessageKind.voice]);
    expect(messages.first.text, 'Blocking my gate');
    expect(controller.attachments, isEmpty);
    expect(controller.messageController.text, isEmpty);
  });

  testWidgets('A failed upload stays queued and is retried on the next Send', (tester) async {
    final controller = await pumpScanPage(tester);
    controller.attachments.add(photo());
    controller.messageController.text = 'Please move';

    conversations.failUploads = true;
    await controller.sendMessage();
    await tester.pump();
    expect(controller.attachments.single.failed.value, isTrue);
    expect(controller.messageController.text, 'Please move');
    expect(await conversations.watchMessages(controller.conversationId).first, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    conversations.failUploads = false;
    await controller.sendMessage();
    await tester.pump();
    expect(controller.attachments, isEmpty);
    final messages = await conversations.watchMessages(controller.conversationId).first;
    expect(messages.map((m) => m.kind), [MessageKind.text, MessageKind.image]);
  });

  testWidgets('Opening the scan page records the visit in the safety log', (tester) async {
    await pumpScanPage(tester);
    await tester.pump();
    expect(conversations.loggedVisits, ['fake-vehicle-0']);
  });

  testWidgets('Removing an attachment drops it before sending', (tester) async {
    final controller = await pumpScanPage(tester);
    controller.attachments.add(photo());
    await tester.pump();

    await tester.tap(find.byTooltip('Remove Photo'));
    await tester.pump();
    expect(controller.attachments, isEmpty);
  });

  testWidgets('Photo and video bubbles show a progress ring while uploading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatBubble(
                message: ChatMessageModel(
                  sender: ChatSender.owner,
                  kind: ChatMessageKind.video,
                  timeLabel: '3:40 PM',
                  uploadProgress: 0.4,
                  status: ChatMessageStatus.sending,
                ),
                isOutgoing: true,
              ),
              ChatBubble(
                message: ChatMessageModel(
                  sender: ChatSender.scanner,
                  kind: ChatMessageKind.video,
                  timeLabel: '3:41 PM',
                  mediaUrl: 'https://example.com/v.mp4',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate((w) => w is CircularProgressIndicator && w.value == 0.4),
      findsOneWidget,
    );
    // The uploaded video offers play.
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
  });
}

/// A 1×1 transparent PNG.
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

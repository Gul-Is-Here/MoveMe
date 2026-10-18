import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/services/conversation_service.dart';
import 'package:parktag_app/app/services/deep_link_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/scan/bindings/scan_contact_binding.dart';
import 'package:parktag_app/modules/scan/views/scan_contact_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_conversation_service.dart';
import 'support/fake_deep_link_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Get.testMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late FakeVehicleService fakeVehicles;

  setUp(() async {
    Get.reset();
    fakeVehicles = FakeVehicleService();
    Get.put<VehicleService>(fakeVehicles);
    Get.put<ConversationService>(FakeConversationService(publicVehicleLookup: fakeVehicles.fetchPublicVehicle));
    Get.put<DeepLinkService>(FakeDeepLinkService());
    await fakeVehicles.saveVehicle(
      uid: 'resident-1',
      ownerName: 'Ayesha Khan',
      nickname: 'White Corolla',
      make: 'Toyota',
      model: 'Corolla Altis',
      plateNumber: 'LEA-2231',
      colorName: 'White',
      dateOfRegistration: '',
      engineNumber: '',
      chassisNumber: '',
      address: '',
      localPhotoPaths: const [],
    );
  });

  testWidgets('Scan Contact Page renders the vehicle and owner for a known vehicle id', (tester) async {
    Get.parameters['vehicleId'] = 'fake-vehicle-0';
    ScanContactBinding().dependencies();

    await tester.pumpWidget(const GetMaterialApp(home: ScanContactView()));
    await tester.pump();
    await tester.pump();

    expect(find.text('White Corolla'), findsOneWidget);
    expect(find.text('LEA-2231'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Send message'), findsOneWidget);
  });

  testWidgets('Sending a message from the scan page creates the conversation', (tester) async {
    Get.parameters['vehicleId'] = 'fake-vehicle-0';
    ScanContactBinding().dependencies();

    await tester.pumpWidget(const GetMaterialApp(home: ScanContactView()));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, 'Please move your car');
    // The page now opens with the "Open in App / Continue on Web" handoff
    // banner above the vehicle card, which pushes the composer past the
    // bottom of the test viewport — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Send message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send message'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Please move your car'), findsWidgets);
    expect(find.text('Has this issue been resolved?'), findsOneWidget);
  });

  testWidgets('Unknown vehicle id shows the not-found state', (tester) async {
    Get.parameters['vehicleId'] = 'does-not-exist';
    ScanContactBinding().dependencies();

    await tester.pumpWidget(const GetMaterialApp(home: ScanContactView()));
    await tester.pump();
    await tester.pump();

    expect(find.text("This QR code doesn't match a MoveMe vehicle"), findsOneWidget);
  });
}

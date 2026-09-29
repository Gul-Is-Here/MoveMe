import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/app/widgets/shimmer.dart';
import 'package:parktag_app/modules/dashboard/controllers/home_tab_controller.dart';
import 'package:parktag_app/modules/dashboard/views/home_tab_view.dart';
import 'package:parktag_app/modules/dashboard/widgets/vehicle_card.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_vehicle_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeVehicleService fakeVehicles;

  setUp(() {
    Get.reset();
    final fakeAuth = FakeAuthService();
    fakeAuth.signInAs(uid: 'resident-1', phone: '+923001234567');
    Get.put<AuthService>(fakeAuth);
    fakeVehicles = FakeVehicleService();
    Get.put<VehicleService>(fakeVehicles);
  });

  Future<void> addCorolla() => fakeVehicles.saveVehicle(
    uid: 'resident-1',
    ownerName: 'Ayesha Khan',
    nickname: 'White Corolla',
    make: 'Toyota',
    model: 'Corolla',
    plateNumber: 'LEA-2231',
    colorName: 'White',
    dateOfRegistration: '2021-04-02',
    engineNumber: 'ENG-1',
    chassisNumber: 'CHS-1',
    address: 'Block C',
    localPhotoPaths: const [],
  );

  testWidgets('Shows a shimmer skeleton before the first snapshot, not an empty state', (
    tester,
  ) async {
    final controller = Get.put(HomeTabController());

    // A fresh controller starts in the loading state. Without this flag the
    // view had nothing to distinguish "not loaded yet" from "no vehicles",
    // so "No vehicles yet" flashed on every launch before Firestore
    // answered. (The fake service then resolves immediately, which is why
    // the flag is asserted here rather than after a pump.)
    expect(controller.isLoading.value, isTrue);

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: HomeTabView())));
    await tester.pump();

    // And while it is loading, the view shows the skeleton, not the empty
    // state.
    controller.isLoading.value = true;
    await tester.pump();

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.text('No vehicles yet'), findsNothing);
  });

  testWidgets('Swaps the skeleton for real vehicle cards once data arrives', (tester) async {
    Get.put(HomeTabController());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: HomeTabView())));
    await tester.pump();

    await addCorolla();
    await tester.pump();
    await tester.pump();

    expect(find.byType(Shimmer), findsNothing);
    expect(find.byType(VehicleCard), findsOneWidget);
    expect(find.text('White Corolla'), findsOneWidget);
    expect(find.text('1 vehicle · tap one for its QR code'), findsOneWidget);
  });

  testWidgets('Shows the empty state only after loading resolves with no vehicles', (
    tester,
  ) async {
    final controller = Get.put(HomeTabController());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: HomeTabView())));
    await tester.pump();

    controller.isLoading.value = false;
    await tester.pump();

    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('No vehicles yet'), findsOneWidget);
  });

  testWidgets('Shows an error state with a retry action', (tester) async {
    final controller = Get.put(HomeTabController());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: HomeTabView())));
    await tester.pump();

    controller.isLoading.value = false;
    controller.hasError.value = true;
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // Home's hero and stats push the error block below the test viewport.
    await tester.ensureVisible(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pump();

    // Retry re-subscribes, which puts the screen back into loading.
    expect(controller.hasError.value, isFalse);
  });

  test('Greeting follows the time of day instead of being hard-coded', () {
    final controller = HomeTabController();
    final hour = DateTime.now().hour;
    final expected = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    expect(controller.greeting, expected);
  });

  test('Unread helpers are safe when the Inbox controller is absent', () {
    final controller = HomeTabController();
    // Home is rendered standalone here; it must not require the Inbox tab.
    expect(controller.unreadCount, 0);
    expect(controller.hasUnreadFor('anything'), isFalse);
  });
}

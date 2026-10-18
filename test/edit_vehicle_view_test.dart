import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parktag_app/app/services/auth_service.dart';
import 'package:parktag_app/app/services/vehicle_service.dart';
import 'package:parktag_app/modules/dashboard/controllers/home_tab_controller.dart';
import 'package:parktag_app/modules/dashboard/models/vehicle_model.dart';
import 'package:parktag_app/modules/vehicle_details/controllers/edit_vehicle_controller.dart';
import 'package:parktag_app/modules/vehicle_details/views/edit_vehicle_view.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_vehicle_service.dart';
import 'package:parktag_app/app/utils/vehicle_input.dart';

const _vehicle = VehicleModel(
  nickname: 'White Corolla',
  makeModel: 'Toyota Corolla Altis',
  plateNumber: 'LEA-2231',
  color: Color(0xFFF5F1E8),
  colorName: 'White',
  dateOfRegistration: '02 Apr 2021',
  engineNumber: '2ZR-4498231',
  chassisNumber: 'MR053CE3204119876',
  address: '123-B, Model Town, Lahore',
  photoPaths: ['/tmp/front.jpg', '/tmp/back.jpg'],
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Get.testMode = true;
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(FakeAuthService());
    Get.put<VehicleService>(FakeVehicleService());
  });

  testWidgets('Edit screen pre-fills fields from the saved vehicle', (tester) async {
    final controller = Get.put(EditVehicleController(vehicle: _vehicle));

    expect(controller.make.text, 'Toyota');
    expect(controller.model.text, 'Corolla Altis');
    expect(controller.plateNumber.text, 'LEA-2231');
    expect(controller.vehiclePhotos, ['/tmp/front.jpg', '/tmp/back.jpg']);
    expect(controller.canSave, isTrue);
  });

  testWidgets('Removing a photo blocks save until 2 photos are present again', (tester) async {
    final controller = Get.put(EditVehicleController(vehicle: _vehicle));

    controller.removeVehiclePhoto(0);
    expect(controller.canSave, isFalse);

    controller.vehiclePhotos.add('/tmp/new-front.jpg');
    expect(controller.canSave, isTrue);
  });

  testWidgets('The nickname field is gone from the form', (tester) async {
    Get.put(EditVehicleController(vehicle: _vehicle));

    await tester.pumpWidget(const GetMaterialApp(home: EditVehicleView()));
    await tester.pump();

    expect(find.text('VEHICLE NICKNAME'), findsNothing);
    expect(find.text('e.g. White Corolla'), findsNothing);
  });

  testWidgets('Tapping the date field opens a picker that stops at today', (tester) async {
    final controller = Get.put(EditVehicleController(vehicle: _vehicle));

    await tester.pumpWidget(const GetMaterialApp(home: EditVehicleView()));
    await tester.pump();

    // The live preview card pushes this field below the test viewport.
    await tester.ensureVisible(find.widgetWithText(TextField, '02 Apr 2021'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, '02 Apr 2021'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    final now = DateTime.now();
    // A registration date can never be in the future, so the picker itself
    // refuses to offer one rather than validating after the fact.
    expect(dialog.lastDate, DateTime(now.year, now.month, now.day));
    expect(dialog.initialDate, DateTime(2021, 4, 2));

    // Typing into the field directly is not possible — it is picker-backed.
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, '02 Apr 2021'),
    );
    expect(field.readOnly, isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.dateOfRegistration.text, '02 Apr 2021');
  });

  testWidgets('Edit screen renders the form and photo section', (tester) async {
    Get.put(EditVehicleController(vehicle: _vehicle));

    await tester.pumpWidget(const GetMaterialApp(home: EditVehicleView()));
    await tester.pump();

    expect(find.text('Edit Vehicle'), findsOneWidget);
    expect(find.text('2 of 2 added'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  /// Signs a resident in and stores [_vehicle] as theirs, returning the
  /// saved copy (with the id the fake assigned).
  Future<VehicleModel> seedSavedVehicle() async {
    (Get.find<AuthService>() as FakeAuthService).signInAs(uid: 'owner-1', phone: '+923001234567');
    final id = await Get.find<VehicleService>().saveVehicle(
      uid: 'owner-1',
      ownerName: 'Ali',
      nickname: _vehicle.nickname,
      make: 'Toyota',
      model: 'Corolla Altis',
      plateNumber: _vehicle.plateNumber,
      colorName: _vehicle.colorName,
      dateOfRegistration: _vehicle.dateOfRegistration,
      engineNumber: _vehicle.engineNumber,
      chassisNumber: _vehicle.chassisNumber,
      address: _vehicle.address,
      localPhotoPaths: _vehicle.photoPaths,
    );
    return VehicleModel(
      id: id,
      nickname: _vehicle.nickname,
      makeModel: _vehicle.makeModel,
      plateNumber: _vehicle.plateNumber,
      color: _vehicle.color,
      colorName: _vehicle.colorName,
      dateOfRegistration: _vehicle.dateOfRegistration,
      engineNumber: _vehicle.engineNumber,
      chassisNumber: _vehicle.chassisNumber,
      address: _vehicle.address,
      photoPaths: _vehicle.photoPaths,
    );
  }

  Future<void> pumpRoutes(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/start',
        getPages: [
          GetPage(name: '/start', page: () => const SizedBox()),
          GetPage(name: '/vehicle-details', page: () => const SizedBox()),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('Saving writes the edit to the database and Home picks it up', (tester) async {
    final saved = await seedSavedVehicle();
    final home = Get.put(HomeTabController());
    await pumpRoutes(tester);

    final controller = Get.put(EditVehicleController(vehicle: saved));
    controller.plateNumber.text = 'LEB-5566';
    controller.color.text = 'Red';

    await controller.save();
    await tester.pump(const Duration(seconds: 4));

    final record = (Get.find<VehicleService>() as FakeVehicleService).saved.single;
    expect(record['plateNumber'], 'LEB-5566');
    expect(record['colorName'], 'Red');
    // Removing the nickname field must not wipe the stored nickname — the
    // Home card, the remove dialog and the public scan page all show it.
    expect(record['nickname'], _vehicle.nickname);

    expect(home.vehicles.single.plateNumber, 'LEB-5566');
    expect(controller.isSaving.value, isFalse);
  });

  testWidgets('A failed save keeps the screen open and the edit unsaved', (tester) async {
    final saved = await seedSavedVehicle();
    final vehicles = Get.find<VehicleService>() as FakeVehicleService..throwOnUpdate = true;
    await pumpRoutes(tester);

    final controller = Get.put(EditVehicleController(vehicle: saved));
    controller.plateNumber.text = 'LEB-5566';

    await controller.save();
    await tester.pump(const Duration(seconds: 4));

    expect(vehicles.saved.single['plateNumber'], 'LEA-2231');
    expect(controller.isSaving.value, isFalse);
    expect(controller.plateNumber.text, 'LEB-5566');
  });

  test('Identifier fields reject special characters but keep hyphens and spaces', () {
    // Real plate, engine and chassis numbers contain hyphens, and the
    // form's own hints are LEA-2231 / 2ZR-4498231, so those must survive.
    String filter(String input) => vehicleIdentifierFormatter
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input))
        .text;

    expect(filter('LEA-2231'), 'LEA-2231');
    expect(filter('MR053CE3204119876'), 'MR053CE3204119876');
    expect(filter('ABC 123'), 'ABC 123');
    expect(filter(r'LEA@#2231!'), 'LEA2231');
    expect(filter('AB/CD*12'), 'ABCD12');
  });

  test('Name-like fields (make, model, address, nickname) keep the hyphen, reject other symbols', () {
    // Same allowed set as vehicleIdentifierFormatter: letters, digits,
    // spaces and the hyphen (addresses like "123-B Model Town" need it) —
    // only other punctuation/symbols are rejected.
    String filter(String input) => vehicleNameFormatter
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input))
        .text;

    expect(filter('Toyota'), 'Toyota');
    expect(filter('Corolla Altis'), 'Corolla Altis');
    expect(filter('123 B Model Town Lahore'), '123 B Model Town Lahore');
    expect(filter('White Corolla'), 'White Corolla');
    expect(filter('123-B, Model Town, Lahore'), '123-B Model Town Lahore');
    expect(filter(r'Toyota@#!'), 'Toyota');
  });

  group('Registration date', () {
    test('Parses the formats already stored, and rejects impossible ones', () {
      expect(parseRegistrationDate('2021-04-02'), DateTime(2021, 4, 2));
      expect(parseRegistrationDate('14 Mar 2022'), DateTime(2022, 3, 14));
      expect(parseRegistrationDate('14/03/2022'), DateTime(2022, 3, 14));
      expect(parseRegistrationDate('14-03-2022'), DateTime(2022, 3, 14));
      expect(parseRegistrationDate(''), isNull);
      expect(parseRegistrationDate('not a date'), isNull);
      // 31 February does not exist.
      expect(parseRegistrationDate('31/02/2022'), isNull);
    });

    test('Refuses a future date, which a registration date can never be', () {
      final nextYear = DateTime.now().year + 1;
      expect(parseRegistrationDate('14 Mar $nextYear'), isNull);
      expect(parseRegistrationDate('$nextYear-03-14'), isNull);
    });

    test('Writes back one consistent format', () {
      expect(formatRegistrationDate(DateTime(2022, 3, 14)), '14 Mar 2022');
      expect(formatRegistrationDate(DateTime(2005, 12, 1)), '01 Dec 2005');
    });
  });
}

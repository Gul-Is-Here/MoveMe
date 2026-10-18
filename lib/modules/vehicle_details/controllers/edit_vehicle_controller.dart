import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/services/auth_service.dart';
import '../../../app/services/vehicle_service.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/utils/vehicle_color.dart';
import '../../../app/utils/vehicle_input.dart';
import '../../dashboard/models/vehicle_model.dart';
import '../../../app/widgets/app_snackbar.dart';

class EditVehicleController extends GetxController {
  EditVehicleController({required this.vehicle});

  static const requiredVehiclePhotos = 2;

  final VehicleModel vehicle;
  final _vehicleService = Get.find<VehicleService>();
  final _authService = Get.find<AuthService>();

  late final make = TextEditingController(text: _splitMakeModel(vehicle.makeModel).$1);
  late final model = TextEditingController(text: _splitMakeModel(vehicle.makeModel).$2);
  late final plateNumber = TextEditingController(text: vehicle.plateNumber);
  late final color = TextEditingController(text: vehicle.colorName);
  late final dateOfRegistration = TextEditingController(text: vehicle.dateOfRegistration);
  late final engineNumber = TextEditingController(text: vehicle.engineNumber);
  late final chassisNumber = TextEditingController(text: vehicle.chassisNumber);
  late final address = TextEditingController(text: vehicle.address);

  late final vehiclePhotos = <String>[...vehicle.photoPaths].obs;
  final isSaving = false.obs;

  final _picker = ImagePicker();

  static (String, String) _splitMakeModel(String makeModel) {
    final trimmed = makeModel.trim();
    final spaceIndex = trimmed.indexOf(' ');
    if (spaceIndex == -1) return (trimmed, '');
    return (trimmed.substring(0, spaceIndex), trimmed.substring(spaceIndex + 1));
  }

  bool get _hasRequiredFields =>
      make.text.trim().isNotEmpty &&
      model.text.trim().isNotEmpty &&
      plateNumber.text.trim().isNotEmpty;

  bool get canSave => _hasRequiredFields && vehiclePhotos.length >= requiredVehiclePhotos;

  /// Opens the date picker for the registration date.
  ///
  /// A registration date can never be in the future, so [lastDate] is today
  /// — the picker simply will not offer a later day, which is a firmer
  /// guarantee than validating after the fact.
  Future<void> pickRegistrationDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = parseRegistrationDate(dateOfRegistration.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(1950),
      lastDate: today,
      helpText: 'Date of registration',
    );
    if (picked == null) return;
    dateOfRegistration.text = formatRegistrationDate(picked);
  }

  Future<void> addVehiclePhoto(ImageSource source) async {
    if (vehiclePhotos.length >= requiredVehiclePhotos) return;
    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return;
    vehiclePhotos.add(photo.path);
  }

  void removeVehiclePhoto(int index) {
    vehiclePhotos.removeAt(index);
  }

  Future<void> save() async {
    if (isSaving.value) return;
    if (!canSave) {
      final missing = <String>[
        if (!_hasRequiredFields) 'make, model and plate number',
        if (vehiclePhotos.length < requiredVehiclePhotos)
          '${requiredVehiclePhotos - vehiclePhotos.length} more vehicle photo(s)',
      ];
      AppSnackbar.show('A few things are missing', 'Please add: ${missing.join(', ')}.');
      return;
    }

    final uid = _authService.currentUid;
    if (uid == null) {
      AppSnackbar.show('Signed out', 'Please sign in again to save your changes.');
      return;
    }

    // The nickname field was removed from this form, so the vehicle keeps
    // the one it already has; vehicles that never had one fall back to the
    // plate number, which the Home card and scan page display.
    final nickname = vehicle.nickname.trim().isEmpty ? plateNumber.text.trim() : vehicle.nickname.trim();

    isSaving.value = true;
    try {
      final photoUrls = await _vehicleService.updateVehicle(
        uid: uid,
        vehicleId: vehicle.id,
        nickname: nickname,
        make: make.text.trim(),
        model: model.text.trim(),
        plateNumber: plateNumber.text.trim(),
        colorName: color.text.trim(),
        dateOfRegistration: dateOfRegistration.text.trim(),
        engineNumber: engineNumber.text.trim(),
        chassisNumber: chassisNumber.text.trim(),
        address: address.text.trim(),
        photos: List.of(vehiclePhotos),
      );

      final updated = VehicleModel(
        id: vehicle.id,
        nickname: nickname,
        makeModel: '${make.text.trim()} ${model.text.trim()}'.trim(),
        plateNumber: plateNumber.text.trim(),
        color: vehicleColorForName(color.text.trim()),
        colorName: color.text.trim(),
        hasUnread: vehicle.hasUnread,
        dateOfRegistration: dateOfRegistration.text.trim(),
        engineNumber: engineNumber.text.trim(),
        chassisNumber: chassisNumber.text.trim(),
        address: address.text.trim(),
        photoPaths: photoUrls,
      );

      // Pop back to the Vehicle Details screen already underneath this one
      // rather than pushing a fresh one — a second copy crashed on the
      // duplicate QR-card GlobalKey.
      Get.back(result: updated);
      AppSnackbar.show('Changes saved', "$nickname's details were updated.");
    } catch (e, stack) {
      AppLogger.error('EditVehicle', e, stack);
      AppSnackbar.show("Couldn't save changes", 'Check your connection and try again.');
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    make.dispose();
    model.dispose();
    plateNumber.dispose();
    color.dispose();
    dateOfRegistration.dispose();
    engineNumber.dispose();
    chassisNumber.dispose();
    address.dispose();
    super.onClose();
  }
}

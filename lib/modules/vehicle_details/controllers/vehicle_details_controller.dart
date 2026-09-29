import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/vehicle_service.dart';
import '../../dashboard/controllers/home_tab_controller.dart';
import '../../dashboard/models/vehicle_model.dart';
import '../widgets/remove_vehicle_dialog.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../../app/utils/app_logger.dart';

class VehicleDetailsController extends GetxController {
  VehicleDetailsController({required VehicleModel vehicle}) : _vehicle = vehicle.obs;

  final Rx<VehicleModel> _vehicle;
  VehicleModel get vehicle => _vehicle.value;

  final _authService = Get.find<AuthService>();
  final _vehicleService = Get.find<VehicleService>();

  /// Wraps the QR card so [shareQrCode] can capture it as an image.
  final qrBoundaryKey = GlobalKey();

  final isSharing = false.obs;

  /// Pushes Edit and waits for it to pop back with the edited vehicle
  /// (rather than pushing a fresh Vehicle Details route on save, which
  /// would stack a second copy of this same screen/controller on top of
  /// this one and crash on the duplicate QR-card GlobalKey).
  Future<void> editVehicle() async {
    final result = await Get.toNamed(AppRoutes.editVehicle, arguments: vehicle);
    if (result is VehicleModel) _vehicle.value = result;
  }

  Future<void> removeVehicle() async {
    final confirmed = await Get.dialog<bool>(
      RemoveVehicleDialog(
        nickname: vehicle.nickname,
        onConfirm: () async {
          final uid = _authService.currentUid;
          if (uid == null) {
            throw StateError('Not signed in');
          }
          await _vehicleService.deleteVehicle(uid: uid, vehicleId: vehicle.id);
        },
      ),
      barrierDismissible: false,
    );
    if (confirmed != true) return;

    if (Get.isRegistered<HomeTabController>()) {
      Get.find<HomeTabController>().vehicles.remove(vehicle);
    }
    Get.back();
    AppSnackbar.show('Vehicle removed', '${vehicle.nickname} was removed from your vehicles.');
  }

  Future<void> shareQrCode() async {
    if (isSharing.value) return;
    isSharing.value = true;
    try {
      final boundary = qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/parktag-${vehicle.plateNumber}-qr.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Scan this to reach me about my ${vehicle.plateNumber} — via MoveMe.',
        ),
      );
    } catch (e, stack) {
      AppLogger.error('VehicleDetails', e, stack);
      AppSnackbar.show('Could not share', 'Something went wrong generating the QR image.');
    } finally {
      isSharing.value = false;
    }
  }
}

import 'dart:async';

import 'package:parktag_app/app/services/vehicle_service.dart';

class FakeVehicleService implements VehicleService {
  final List<Map<String, dynamic>> saved = [];
  final List<String> deletedIds = [];
  final _vehiclesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  int _idSeq = 0;

  /// Set to force [deleteVehicle] to throw, to simulate a failed delete.
  bool throwOnDelete = false;

  @override
  Future<String> saveVehicle({
    required String uid,
    required String ownerName,
    required String nickname,
    required String make,
    required String model,
    required String plateNumber,
    required String colorName,
    required String dateOfRegistration,
    required String engineNumber,
    required String chassisNumber,
    required String address,
    required List<String> localPhotoPaths,
    String? rcCardFrontImagePath,
    String? rcCardBackImagePath,
  }) async {
    final id = 'fake-vehicle-${_idSeq++}';
    saved.add({
      'id': id,
      'uid': uid,
      'ownerName': ownerName,
      'nickname': nickname,
      'make': make,
      'model': model,
      'plateNumber': plateNumber,
      'colorName': colorName,
      'dateOfRegistration': dateOfRegistration,
      'engineNumber': engineNumber,
      'chassisNumber': chassisNumber,
      'address': address,
      'photoPaths': localPhotoPaths,
      'rcCardFrontImagePath': rcCardFrontImagePath,
      'rcCardBackImagePath': rcCardBackImagePath,
    });
    _vehiclesController.add(List.of(saved));
    return id;
  }

  /// Set to force [updateVehicle] to throw, to simulate a failed save.
  bool throwOnUpdate = false;

  @override
  Future<List<String>> updateVehicle({
    required String uid,
    required String vehicleId,
    required String nickname,
    required String make,
    required String model,
    required String plateNumber,
    required String colorName,
    required String dateOfRegistration,
    required String engineNumber,
    required String chassisNumber,
    required String address,
    required List<String> photos,
  }) async {
    if (throwOnUpdate) {
      throw Exception('Simulated update failure');
    }
    final index = saved.indexWhere((v) => v['id'] == vehicleId);
    if (index == -1) throw StateError('No vehicle $vehicleId');
    saved[index] = {
      ...saved[index],
      'nickname': nickname,
      'make': make,
      'model': model,
      'plateNumber': plateNumber,
      'colorName': colorName,
      'dateOfRegistration': dateOfRegistration,
      'engineNumber': engineNumber,
      'chassisNumber': chassisNumber,
      'address': address,
      'photoPaths': photos,
    };
    _vehiclesController.add(List.of(saved));
    return photos;
  }

  @override
  Future<void> deleteVehicle({required String uid, required String vehicleId}) async {
    if (throwOnDelete) {
      throw Exception('Simulated delete failure');
    }
    deletedIds.add(vehicleId);
    saved.removeWhere((v) => v['id'] == vehicleId);
    _vehiclesController.add(List.of(saved));
  }

  @override
  Future<Map<String, dynamic>?> fetchPublicVehicle(String vehicleId) async {
    final match = saved.where((v) => v['id'] == vehicleId);
    if (match.isEmpty) return null;
    final v = match.first;
    return {
      'ownerUid': v['uid'],
      'ownerName': v['ownerName'],
      'nickname': v['nickname'],
      'makeModel': '${v['make']} ${v['model']}',
      'plateNumber': v['plateNumber'],
      'colorName': v['colorName'],
      'photoUrl': (v['photoPaths'] as List).isNotEmpty ? (v['photoPaths'] as List).first : '',
    };
  }

  @override
  Stream<List<Map<String, dynamic>>> watchVehicles(String uid) async* {
    List<Map<String, dynamic>> forUid(List<Map<String, dynamic>> all) =>
        all.where((v) => v['uid'] == uid).map((v) => {...v, 'photoUrls': v['photoPaths']}).toList();

    yield forUid(saved);
    yield* _vehiclesController.stream.map(forUid);
  }
}

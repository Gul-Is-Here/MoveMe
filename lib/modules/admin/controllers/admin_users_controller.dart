import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/services/admin_service.dart';
import '../../../app/utils/app_logger.dart';
import '../admin_navigation.dart';
import 'admin_orders_controller.dart' show normalizePhoneDigits, normalizePlate;

/// A user in the search results, with the plate that matched (if a
/// registration-number search found them).
class UserSearchResult {
  const UserSearchResult({required this.user, required this.vehicleCount, this.matchedVehicle});

  final AdminUser user;
  final int vehicleCount;
  final AdminVehicle? matchedVehicle;
}

class AdminUsersController extends GetxController {
  final _adminService = Get.find<AdminService>();

  final users = <AdminUser>[].obs;
  final vehicles = <AdminVehicle>[].obs;
  final isLoading = true.obs;
  final query = ''.obs;
  final search = TextEditingController();

  final _subs = <StreamSubscription<Object?>>[];

  @override
  void onInit() {
    super.onInit();
    _subs.add(
      _adminService.watchUsers().listen(
        (list) {
          users.assignAll(list);
          isLoading.value = false;
        },
        onError: (Object e, StackTrace s) {
          AppLogger.error('AdminUsers', e, s);
          isLoading.value = false;
        },
      ),
    );
    _subs.add(
      _adminService.watchAllVehicles().listen(
        vehicles.assignAll,
        onError: (Object e, StackTrace s) => AppLogger.error('AdminUsers', e, s),
      ),
    );
    search.addListener(() => query.value = search.text);
  }

  List<UserSearchResult> get results {
    final byOwner = <String, List<AdminVehicle>>{};
    for (final v in vehicles) {
      byOwner.putIfAbsent(v.uid, () => []).add(v);
    }
    final q = query.value.trim();
    final results = <UserSearchResult>[];
    for (final user in users) {
      final owned = byOwner[user.uid] ?? const <AdminVehicle>[];
      if (q.isEmpty) {
        results.add(UserSearchResult(user: user, vehicleCount: owned.length));
        continue;
      }
      if (_matchesPerson(user, q)) {
        results.add(UserSearchResult(user: user, vehicleCount: owned.length));
        continue;
      }
      final plate = normalizePlate(q);
      if (plate.length >= 2) {
        final match = owned.firstWhereOrNull((v) => normalizePlate(v.plateNumber).contains(plate));
        if (match != null) results.add(UserSearchResult(user: user, vehicleCount: owned.length, matchedVehicle: match));
      }
    }
    return results;
  }

  static bool _matchesPerson(AdminUser user, String q) {
    if (user.name.toLowerCase().contains(q.toLowerCase())) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4 && user.cnic.replaceAll(RegExp(r'\D'), '').contains(digits)) return true;
    final phone = normalizePhoneDigits(q);
    return phone.length >= 3 && normalizePhoneDigits(user.phone).contains(phone);
  }

  void open(UserSearchResult result) => AdminNav.openUser(result.user.uid, vehicleId: result.matchedVehicle?.id);

  @override
  void onClose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    search.dispose();
    super.onClose();
  }
}

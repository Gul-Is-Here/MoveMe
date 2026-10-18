import 'dart:async';

import 'package:parktag_app/app/services/admin_service.dart';

class FakeAdminService implements AdminService {
  final List<AdminUser> users = [];
  final List<AdminVehicle> vehicles = [];
  final _changes = StreamController<void>.broadcast();

  void changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<List<AdminUser>> watchUsers() => _watch(() => List.of(users));

  @override
  Stream<List<AdminVehicle>> watchAllVehicles() => _watch(() => List.of(vehicles));

  @override
  Stream<AdminUser?> watchUser(String uid) => _watch(() => users.where((u) => u.uid == uid).firstOrNull);

  @override
  Stream<List<AdminVehicle>> watchUserVehicles(String uid) =>
      _watch(() => vehicles.where((v) => v.uid == uid).toList());

  @override
  Future<void> setUserBlocked(String uid, {required bool blocked}) async {
    final i = users.indexWhere((u) => u.uid == uid);
    final u = users[i];
    users[i] = AdminUser(uid: u.uid, name: u.name, phone: u.phone, cnic: u.cnic, blocked: blocked, createdAt: u.createdAt);
    changed();
  }
}

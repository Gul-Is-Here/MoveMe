import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

class AdminUser {
  const AdminUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.cnic = '',
    this.blocked = false,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String cnic;
  final bool blocked;
  final DateTime? createdAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory AdminUser.fromMap(String uid, Map<String, dynamic> data) => AdminUser(
        uid: uid,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        cnic: data['cnic'] as String? ?? '',
        blocked: data['blocked'] == true,
        createdAt: _time(data['createdAt']),
      );
}

/// A customer's private vehicle record (users/{uid}/vehicles/{id}).
class AdminVehicle {
  const AdminVehicle({
    required this.id,
    required this.uid,
    required this.nickname,
    required this.make,
    required this.model,
    required this.plateNumber,
    this.colorName = '',
    this.dateOfRegistration = '',
    this.engineNumber = '',
    this.chassisNumber = '',
    this.address = '',
    this.photoUrls = const [],
    this.rcCardFrontUrl = '',
    this.rcCardBackUrl = '',
    this.createdAt,
  });

  final String id;
  final String uid;
  final String nickname;
  final String make;
  final String model;
  final String plateNumber;
  final String colorName;
  final String dateOfRegistration;
  final String engineNumber;
  final String chassisNumber;
  final String address;
  final List<String> photoUrls;
  final String rcCardFrontUrl;
  final String rcCardBackUrl;
  final DateTime? createdAt;

  String get makeModel => '$make $model'.trim();

  factory AdminVehicle.fromMap(String id, String uid, Map<String, dynamic> data) => AdminVehicle(
        id: id,
        uid: uid,
        nickname: data['nickname'] as String? ?? '',
        make: data['make'] as String? ?? '',
        model: data['model'] as String? ?? '',
        plateNumber: data['plateNumber'] as String? ?? '',
        colorName: data['colorName'] as String? ?? '',
        dateOfRegistration: data['dateOfRegistration'] as String? ?? '',
        engineNumber: data['engineNumber'] as String? ?? '',
        chassisNumber: data['chassisNumber'] as String? ?? '',
        address: data['address'] as String? ?? '',
        photoUrls: (data['photoUrls'] as List?)?.cast<String>() ?? const [],
        rcCardFrontUrl: data['rcCardFrontUrl'] as String? ?? '',
        rcCardBackUrl: data['rcCardBackUrl'] as String? ?? '',
        createdAt: _time(data['createdAt']),
      );
}

/// The admin's view of customers. Every method is admin only.
abstract class AdminService {
  /// Every customer (accounts with a phone number on their profile).
  Stream<List<AdminUser>> watchUsers();

  /// Every customer's vehicles, across all accounts.
  Stream<List<AdminVehicle>> watchAllVehicles();

  Stream<AdminUser?> watchUser(String uid);

  Stream<List<AdminVehicle>> watchUserVehicles(String uid);

  /// Blocks (or unblocks) the customer's sign-in. Nothing is deleted.
  Future<void> setUserBlocked(String uid, {required bool blocked});
}

class FirebaseAdminService implements AdminService {
  final _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<AdminUser>> watchUsers() => _firestore.collection('users').snapshots().map(
        (snap) => snap.docs
            .map((d) => AdminUser.fromMap(d.id, d.data()))
            .where((u) => u.phone.isNotEmpty)
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))),
      );

  @override
  Stream<List<AdminVehicle>> watchAllVehicles() => _firestore.collectionGroup('vehicles').snapshots().map(
        (snap) => [
          for (final d in snap.docs)
            // Only users/{uid}/vehicles — the top-level `vehicles` are the
            // public scan copies.
            if (d.reference.parent.parent case final owner?) AdminVehicle.fromMap(d.id, owner.id, d.data()),
        ],
      );

  @override
  Stream<AdminUser?> watchUser(String uid) => _firestore.collection('users').doc(uid).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : AdminUser.fromMap(uid, data);
      });

  @override
  Stream<List<AdminVehicle>> watchUserVehicles(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('vehicles')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => AdminVehicle.fromMap(d.id, uid, d.data())).toList());

  @override
  Future<void> setUserBlocked(String uid, {required bool blocked}) async {
    await FirebaseFunctions.instance.httpsCallable('setUserBlocked').call({'uid': uid, 'blocked': blocked});
  }
}

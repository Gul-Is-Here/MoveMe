import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/app_logger.dart';

/// Wraps Firestore/Storage for vehicle records (FR-02) so controllers never
/// touch the Firebase SDKs directly, and can be tested against a fake.
abstract class VehicleService {
  /// Uploads [localPhotoPaths] to Storage, writes the vehicle document under
  /// `users/{uid}/vehicles`, denormalizes a public-readable copy under the
  /// top-level `vehicles` collection for the Scan Contact Page (FR-04), and
  /// returns the new vehicle's id — used to build its QR scan URL
  /// (FR-03: `parktag.app/scan/{vehicleId}`).
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
  });

  /// Saves an edit to both the private and the public vehicle documents.
  /// [photos] mixes already-uploaded download URLs (kept as they are) and
  /// local file paths (uploaded now); photos dropped from the list are
  /// deleted from Storage. Returns the final photo URLs, in order.
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
  });

  /// Deletes the vehicle document (both the private `users/{uid}/vehicles`
  /// copy and the public `vehicles` one the QR sticker points at) along
  /// with its uploaded photos and RC card scans. Storage deletes are
  /// best-effort — a folder that was never populated (or a partial
  /// failure) never blocks removing the record itself.
  Future<void> deleteVehicle({required String uid, required String vehicleId});

  /// Looks up the public-safe fields for a vehicle by its QR-scan id —
  /// backs the public Scan Contact Page, which anyone can open without
  /// signing in. Returns null when no vehicle has this id.
  Future<Map<String, dynamic>?> fetchPublicVehicle(String vehicleId);

  /// Real-time list of a resident's own vehicles (`users/{uid}/vehicles`),
  /// newest first — drives the Home tab so a freshly-saved vehicle (or an
  /// edit) shows up immediately without a manual refresh. Each map includes
  /// its Firestore document id under `id`.
  Stream<List<Map<String, dynamic>>> watchVehicles(String uid);
}

class FirebaseVehicleService implements VehicleService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

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
    final doc = _firestore.collection('users').doc(uid).collection('vehicles').doc();

    final photoUrls = <String>[];
    for (var i = 0; i < localPhotoPaths.length; i++) {
      final ref = _storage.ref('vehicle_photos/$uid/${doc.id}/$i.jpg');
      await ref.putFile(File(localPhotoPaths[i]));
      photoUrls.add(await ref.getDownloadURL());
    }

    // The scanned RC card itself — kept as the source record behind the
    // fields GPT-4o extracted, separate from the vehicle's own photos.
    String? rcCardFrontUrl;
    if (rcCardFrontImagePath != null) {
      final ref = _storage.ref('rc_cards/$uid/${doc.id}/front.jpg');
      await ref.putFile(File(rcCardFrontImagePath));
      rcCardFrontUrl = await ref.getDownloadURL();
    }
    String? rcCardBackUrl;
    if (rcCardBackImagePath != null) {
      final ref = _storage.ref('rc_cards/$uid/${doc.id}/back.jpg');
      await ref.putFile(File(rcCardBackImagePath));
      rcCardBackUrl = await ref.getDownloadURL();
    }

    await doc.set({
      'nickname': nickname,
      'make': make,
      'model': model,
      'plateNumber': plateNumber,
      'colorName': colorName,
      'dateOfRegistration': dateOfRegistration,
      'engineNumber': engineNumber,
      'chassisNumber': chassisNumber,
      'address': address,
      'photoUrls': photoUrls,
      'rcCardFrontUrl': rcCardFrontUrl,
      'rcCardBackUrl': rcCardBackUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('vehicles').doc(doc.id).set({
      'ownerUid': uid,
      'ownerName': ownerName,
      'nickname': nickname,
      'makeModel': '$make $model'.trim(),
      'plateNumber': plateNumber,
      'colorName': colorName,
      'photoUrl': photoUrls.isNotEmpty ? photoUrls.first : '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

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
    final folder = 'vehicle_photos/$uid/$vehicleId';
    // Unique names, so a new photo never overwrites a kept one that has
    // shifted into its old index.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final photoUrls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      if (photo.startsWith('http')) {
        photoUrls.add(photo);
        continue;
      }
      final ref = _storage.ref('$folder/${stamp}_$i.jpg');
      await ref.putFile(File(photo));
      photoUrls.add(await ref.getDownloadURL());
    }

    final batch = _firestore.batch()
      ..update(_firestore.collection('users').doc(uid).collection('vehicles').doc(vehicleId), {
        'nickname': nickname,
        'make': make,
        'model': model,
        'plateNumber': plateNumber,
        'colorName': colorName,
        'dateOfRegistration': dateOfRegistration,
        'engineNumber': engineNumber,
        'chassisNumber': chassisNumber,
        'address': address,
        'photoUrls': photoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_firestore.collection('vehicles').doc(vehicleId), {
        'nickname': nickname,
        'makeModel': '$make $model'.trim(),
        'plateNumber': plateNumber,
        'colorName': colorName,
        'photoUrl': photoUrls.isNotEmpty ? photoUrls.first : '',
      });
    await batch.commit();

    try {
      final kept = photoUrls.map((url) => _storage.refFromURL(url).fullPath).toSet();
      final listing = await _storage.ref(folder).listAll();
      await Future.wait(listing.items.where((ref) => !kept.contains(ref.fullPath)).map((ref) => ref.delete()));
    } catch (e, stack) {
      // Best-effort: a leftover file never undoes a saved edit.
      AppLogger.error('VehicleService', e, stack);
    }

    return photoUrls;
  }

  @override
  Future<void> deleteVehicle({required String uid, required String vehicleId}) async {
    Future<void> deleteFolder(String path) async {
      try {
        final listing = await _storage.ref(path).listAll();
        await Future.wait(listing.items.map((ref) => ref.delete()));
      } catch (e, stack) {
        AppLogger.error('VehicleService', e, stack);
        // Best-effort: a folder nothing was ever uploaded to, or a
        // partial delete, should never block removing the record itself.
      }
    }

    await Future.wait([
      deleteFolder('vehicle_photos/$uid/$vehicleId'),
      deleteFolder('rc_cards/$uid/$vehicleId'),
    ]);

    await _firestore.collection('vehicles').doc(vehicleId).delete();
    await _firestore.collection('users').doc(uid).collection('vehicles').doc(vehicleId).delete();
  }

  @override
  Future<Map<String, dynamic>?> fetchPublicVehicle(String vehicleId) async {
    final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
    return doc.data();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchVehicles(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }
}

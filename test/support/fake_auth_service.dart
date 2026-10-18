import 'dart:async';

import 'package:parktag_app/app/services/auth_service.dart';

/// In-memory stand-in for [AuthService] so widget tests never touch the
/// real Firebase SDK. Defaults permissive (any phone is "registered") so
/// existing flows keep working; tests that specifically exercise the
/// register-before-login gate can flip [registerAllByDefault] off.
class FakeAuthService implements AuthService {
  bool registerAllByDefault = true;
  final Set<String> registeredPhones = {};
  final Map<String, Map<String, dynamic>> profiles = {};
  final Map<String, Set<String>> fcmTokens = {};
  final Map<String, String> communicationPreferences = {};
  int _uidSeq = 0;

  bool _signedIn = false;
  String? _currentUid;
  String? _currentPhone;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get currentUid => _currentUid;

  @override
  String? get currentPhone => _currentPhone;

  /// Test helper: simulate an already-signed-in resident (e.g. across an app
  /// restart) without going through the OTP flow.
  void signInAs({required String uid, required String phone, Map<String, dynamic>? profile}) {
    _signedIn = true;
    _currentUid = uid;
    _currentPhone = phone;
    if (profile != null) profiles[uid] = profile;
  }

  @override
  Future<void> sendOtp({
    required String e164Phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    _pendingPhone = e164Phone;
    onCodeSent('fake-verification-id');
  }

  /// The number the last [sendOtp] went to — becomes [currentPhone] on
  /// [confirmOtp], as Firebase's phone sign-in does.
  String? _pendingPhone;

  @override
  Future<String> confirmOtp({required String verificationId, required String smsCode}) async {
    _signedIn = true;
    _currentUid ??= 'fake-uid-${_uidSeq++}';
    _currentPhone ??= _pendingPhone;
    return _currentUid!;
  }

  /// The number that gets the admin side, like the server's ADMIN_PHONE.
  String adminPhone = '+923079618674';
  bool adminClaimed = false;

  @override
  Future<PhoneLookup> lookupPhone(String e164Phone) async {
    final isAdmin = e164Phone == adminPhone;
    final registered = !isAdmin && (registerAllByDefault || registeredPhones.contains(e164Phone));
    return PhoneLookup(registered: registered, isAdmin: isAdmin, blocked: blockedPhones.contains(e164Phone));
  }

  @override
  Future<void> claimAdminRole() async {
    if (_currentPhone != adminPhone) throw StateError('Not the admin number');
    adminClaimed = true;
  }

  final _forcedSignOuts = StreamController<void>.broadcast();

  @override
  Stream<void> get forcedSignOuts => _forcedSignOuts.stream;

  /// Simulates Firebase signing this device out because the account was
  /// blocked elsewhere.
  void simulateForcedSignOut() {
    _signedIn = false;
    _currentUid = null;
    _currentPhone = null;
    _forcedSignOuts.add(null);
  }

  /// Phones the admin has blocked; [lookupPhone] reports them.
  final Set<String> blockedPhones = {};

  @override
  Future<bool> isAdmin() async => _signedIn && adminClaimed && _currentPhone == adminPhone;

  @override
  Future<void> createResidentProfile({
    required String uid,
    required String name,
    required String phone,
    String? cnic,
  }) async {
    registeredPhones.add(phone);
    _currentPhone = phone;
    profiles[uid] = {'name': name, 'phone': phone, if (cnic != null && cnic.isNotEmpty) 'cnic': cnic};
  }

  @override
  Future<Map<String, dynamic>?> fetchResidentProfile(String uid) async => profiles[uid];

  @override
  Future<void> updateResidentProfile({required String uid, required String name}) async {
    profiles[uid] = {...?profiles[uid], 'name': name};
  }

  @override
  Future<void> deleteResidentAccount(String uid) async {
    profiles.remove(uid);
  }

  @override
  Future<void> saveFcmToken({required String uid, required String token}) async {
    fcmTokens.putIfAbsent(uid, () => {}).add(token);
  }

  @override
  Future<void> removeFcmToken({required String uid, required String token}) async {
    fcmTokens[uid]?.remove(token);
  }

  @override
  Future<void> saveCommunicationPreference({required String uid, required String preference}) async {
    communicationPreferences[uid] = preference;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _currentUid = null;
    _currentPhone = null;
  }
}

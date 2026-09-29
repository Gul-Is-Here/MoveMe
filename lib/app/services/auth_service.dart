import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Wraps Firebase Phone Auth + the Firestore `users` collection so
/// controllers never touch the Firebase SDKs directly (and can be tested
/// against a fake implementation instead).
abstract class AuthService {
  /// Starts Firebase's phone verification for [e164Phone] (e.g. "+923001234567").
  /// Calls [onCodeSent] with the verification id once the SMS goes out, or
  /// [onError] if Firebase rejects the number / send attempt.
  Future<void> sendOtp({
    required String e164Phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  });

  /// Confirms the code the resident typed and signs them in, returning the
  /// Firebase Auth uid.
  Future<String> confirmOtp({required String verificationId, required String smsCode});

  /// Whether a resident already exists for this phone number — used to
  /// route sign-up vs. login: FR-01 expects residents to register once and
  /// log back in afterwards, not re-register every time.
  Future<bool> phoneIsRegistered(String e164Phone);

  /// Creates the resident's Firestore profile after their first successful
  /// sign-up verification. [cnic] is optional — Sign Up may not always
  /// collect it — and is stored as supplied (FR-01.1: identity verification).
  Future<void> createResidentProfile({
    required String uid,
    required String name,
    required String phone,
    String? cnic,
  });

  /// Reads the signed-in resident's Firestore profile (FR-08), or null if
  /// there's no document yet.
  Future<Map<String, dynamic>?> fetchResidentProfile(String uid);

  /// Persists edits made on the Profile screen.
  Future<void> updateResidentProfile({required String uid, required String name});

  /// Registers this device for chat push notifications (FR-05/FR-06) by
  /// adding its FCM token to the resident's profile — a resident may have
  /// more than one device signed in, so tokens accumulate in a set rather
  /// than overwriting a single field.
  Future<void> saveFcmToken({required String uid, required String token});

  /// Called on sign-out so a stale token on a shared/reset device doesn't
  /// keep receiving another resident's notifications.
  Future<void> removeFcmToken({required String uid, required String token});

  /// Saves the choice made on the one-time "app or web?" prompt shown right
  /// after registration (FR-09) — 'app' or 'web'. Drives whether Splash
  /// pushes hard for FCM/push UX or keeps steering the resident back to the
  /// web chat link.
  Future<void> saveCommunicationPreference({required String uid, required String preference});

  /// Permanently removes the resident's Firestore profile and Firebase Auth
  /// account (FR-01.4).
  Future<void> deleteResidentAccount(String uid);

  /// Whether a resident is currently signed in — drives Splash's decision
  /// to skip straight to Dashboard on app restart instead of Onboarding/Login.
  bool get isSignedIn;

  /// The signed-in resident's Firebase Auth uid, or null if signed out.
  String? get currentUid;

  /// The signed-in resident's verified E.164 phone number, or null if signed out.
  String? get currentPhone;

  Future<void> signOut();
}

/// Turns a [FirebaseAuthException] into something a resident (or a developer
/// reading a snackbar) can act on. Firebase's own copy is actively misleading
/// for the region case: a blocked SMS region reports `operation-not-allowed`
/// with a message telling you to enable the Phone provider, even when that
/// provider is already enabled — the real cause is only in the bracketed tail.
String describeAuthFailure(FirebaseAuthException e) {
  final raw = e.message ?? '';

  // Firebase's server-side anti-abuse block (TOO_MANY_ATTEMPTS). Arrives as
  // a generic "internal error" whose only clue is this bracketed code, and
  // typically hits real numbers after heavy testing while test numbers
  // still work. It can last 24h+ and nothing client-side lifts it.
  if (raw.contains('Error code:39') || raw.contains('error-code:-39')) {
    return "We can't send a code to this number right now because of too many "
        'recent attempts. Please try again later.';
  }

  if (raw.contains('region enabled by the app developer')) {
    return 'SMS to this country is blocked for this Firebase project. '
        'Enable it under Authentication > Settings > SMS region policy.';
  }

  switch (e.code) {
    case 'invalid-phone-number':
      return "That phone number doesn't look right. Check it and try again.";
    case 'too-many-requests':
      return 'Too many attempts from this device — Firebase has temporarily '
          'blocked it. Wait a while, or use a Firebase test phone number.';
    case 'quota-exceeded':
      return "This project's SMS quota is used up. Try again later.";
    case 'app-not-authorized':
      return "This app build isn't authorized for phone sign-in. Check the "
          "SHA-1/SHA-256 fingerprints registered in the Firebase console.";
    case 'network-request-failed':
      return 'No connection. Check your internet and try again.';
    case 'operation-not-allowed':
      return 'Phone sign-in is not enabled for this Firebase project.';
    case 'web-context-cancelled':
    case 'web-context-already-presented':
      return 'The verification page was closed before it finished. Please try again.';
    case 'captcha-check-failed':
    case 'invalid-recaptcha-token':
    case 'missing-recaptcha-token':
    case 'invalid-recaptcha-action':
    case 'recaptcha-not-enabled':
      return "Couldn't complete the reCAPTCHA check. Please try again.";
    case 'missing-client-identifier':
    case 'invalid-app-credential':
    case 'missing-app-credential':
      return "This device couldn't be verified by Firebase. Please try again.";
    default:
      return raw.isEmpty ? 'Verification failed. Please try again.' : raw;
  }
}

class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  /// Android's resend token per number, from the last `codeSent`. Without
  /// passing it back as `forceResendingToken`, a repeat request for the
  /// same number inside the timeout window reuses the pending verification
  /// and no new SMS goes out — so "Resend code" silently did nothing.
  final _resendTokens = <String, int>{};

  @override
  Future<void> sendOtp({
    required String e164Phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    final watch = Stopwatch()..start();
    final forced = _resendTokens.containsKey(e164Phone) ? ' (forced resend)' : '';
    AppLogger.debug('PhoneAuth', 'verifyPhoneNumber start for $e164Phone$forced');
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: e164Phone,
        forceResendingToken: _resendTokens[e164Phone],
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          AppLogger.debug('PhoneAuth', 'auto-verified after ${watch.elapsedMilliseconds}ms');
          // Android instant/auto verification — sign in right away; the
          // resident may already have moved on to the OTP screen, which is
          // fine, Get.offAllNamed from there just becomes a no-op re-entry.
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            AppLogger.debug('PhoneAuth', 'auto sign-in failed: $e');
            // Fall through — the resident still completes verification
            // manually on the OTP screen.
          }
        },
        verificationFailed: (e) {
          _logAuthFailure('verificationFailed', e, watch);
          onError(describeAuthFailure(e));
        },
        codeSent: (verificationId, resendToken) {
          if (resendToken != null) _resendTokens[e164Phone] = resendToken;
          AppLogger.debug('PhoneAuth', 'codeSent after ${watch.elapsedMilliseconds}ms');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (_) {
          AppLogger.debug('PhoneAuth', 'auto-retrieval timed out after ${watch.elapsedMilliseconds}ms');
        },
      );
    } on FirebaseAuthException catch (e) {
      // iOS reports some failures (e.g. reCAPTCHA / app-verification
      // problems) by throwing here rather than through verificationFailed.
      _logAuthFailure('verifyPhoneNumber threw', e, watch);
      onError(describeAuthFailure(e));
    } catch (e, stack) {
      AppLogger.debug('PhoneAuth', 'verifyPhoneNumber threw after ${watch.elapsedMilliseconds}ms: $e\n$stack');
      onError('Verification failed. Please try again.');
    }
  }

  void _logAuthFailure(String where, FirebaseAuthException e, Stopwatch watch) {
    AppLogger.debug(
      'PhoneAuth',
      '$where after ${watch.elapsedMilliseconds}ms\n'
      '  code: ${e.code}\n'
      '  message: ${e.message}\n'
      '  plugin: ${e.plugin}',
    );
  }

  @override
  Future<String> confirmOtp({required String verificationId, required String smsCode}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    final result = await _auth.signInWithCredential(credential);
    final uid = result.user?.uid;
    if (uid == null) throw Exception('Sign-in failed. Please try again.');
    return uid;
  }

  @override
  Future<bool> phoneIsRegistered(String e164Phone) async {
    final watch = Stopwatch()..start();
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: e164Phone)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));
      AppLogger.debug('PhoneAuth', 'phoneIsRegistered lookup took ${watch.elapsedMilliseconds}ms');
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      AppLogger.debug('PhoneAuth', 'phoneIsRegistered failed after ${watch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  @override
  Future<void> createResidentProfile({
    required String uid,
    required String name,
    required String phone,
    String? cnic,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      if (cnic != null && cnic.isNotEmpty) 'cnic': cnic,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>?> fetchResidentProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Future<void> updateResidentProfile({required String uid, required String name}) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveFcmToken({required String uid, required String token}) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeFcmToken({required String uid, required String token}) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveCommunicationPreference({required String uid, required String preference}) async {
    await _firestore.collection('users').doc(uid).set({
      'communicationPreference': preference,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteResidentAccount(String uid) async {
    // Server-side cascade: see `deleteAccount` in functions/index.js.
    await FirebaseFunctions.instance.httpsCallable('deleteAccount').call();
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String? get currentPhone => _auth.currentUser?.phoneNumber;

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Phone OTP through our own Cloud Functions + local SMS gateway instead of
/// Firebase's SMS (unreliable to Pakistani carriers, and prone to "Error
/// code:39" blocks). The server returns a Firebase custom token, so the
/// resident still ends up a normal Firebase Auth user with the same uid —
/// Firestore, Storage, rules and push are all unchanged.
///
/// Errors are re-thrown as [FirebaseAuthException]s with the codes the OTP
/// screen already understands, so no controller had to change.
class CustomOtpAuthService extends FirebaseAuthService {
  final _functions = FirebaseFunctions.instance;

  @override
  Future<void> sendOtp({
    required String e164Phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    final watch = Stopwatch()..start();
    try {
      await _functions.httpsCallable('requestPhoneOtp').call({'phone': e164Phone});
      AppLogger.debug('PhoneAuth', 'custom OTP sent after ${watch.elapsedMilliseconds}ms');
      // The phone number doubles as the "verification id" for confirmOtp.
      onCodeSent(e164Phone);
    } on FirebaseFunctionsException catch (e, stack) {
      AppLogger.error('PhoneAuth', e, stack);
      onError(e.message ?? 'Could not send the code. Please try again.');
    } catch (e, stack) {
      AppLogger.error('PhoneAuth', e, stack);
      onError('Could not send the code. Check your connection and try again.');
    }
  }

  @override
  Future<String> confirmOtp({required String verificationId, required String smsCode}) async {
    final String token;
    try {
      final result = await _functions.httpsCallable('verifyPhoneOtp').call({
        'phone': verificationId,
        'code': smsCode,
      });
      token = (result.data as Map)['token'] as String;
    } on FirebaseFunctionsException catch (e) {
      final code = switch (e.code) {
        'permission-denied' => 'invalid-verification-code',
        'deadline-exceeded' => 'session-expired',
        'resource-exhausted' => 'too-many-requests',
        _ => 'internal-error',
      };
      throw FirebaseAuthException(code: code, message: e.message);
    }
    final signedIn = await FirebaseAuth.instance.signInWithCustomToken(token);
    final uid = signedIn.user?.uid;
    if (uid == null) throw Exception('Sign-in failed. Please try again.');
    return uid;
  }
}

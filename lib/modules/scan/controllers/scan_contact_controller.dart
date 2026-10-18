import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/services/conversation_service.dart';
import '../../../app/services/deep_link_service.dart';
import '../../../app/services/vehicle_service.dart';
import '../../../app/utils/vehicle_color.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../../app/utils/app_logger.dart';

const _scannerIdPrefsKey = 'parktag_scanner_id';
const _preferWebPrefsKey = 'parktag_prefer_web';

const androidPackageName = 'com.parktagapp.mobile';
const playStoreUrl = 'https://play.google.com/store/apps/details?id=$androidPackageName';

/// Drives the public Scan Contact Page (FR-04) — opened straight from a
/// vehicle's QR sticker, no sign-in required.
///
/// Many different people scan the same sticker. Each one is identified by a
/// random [scannerId] persisted in this browser/device's local storage —
/// generated once on first visit and reused after that, so reopening the
/// link continues *your own* conversation with the owner, while someone
/// else scanning the same sticker (a different browser/device, so a
/// different persisted id) always starts a separate, private one.
class ScanContactController extends GetxController {
  final _vehicleService = Get.find<VehicleService>();
  final _conversationService = Get.find<ConversationService>();
  final _deepLinkService = Get.find<DeepLinkService>();

  final String vehicleId = Get.parameters['vehicleId'] ?? '';
  String _scannerId = '';
  String get conversationId => conversationIdFor(vehicleId, _scannerId);

  final isLoading = true.obs;
  final notFound = false.obs;

  final ownerName = ''.obs;
  final nickname = ''.obs;
  final makeModel = ''.obs;
  final plateNumber = ''.obs;
  final colorName = ''.obs;
  final photoUrl = ''.obs;
  Color get vehicleColor => vehicleColorForName(colorName.value);


  final scannerNameController = TextEditingController();
  final messageController = TextEditingController();
  final isSending = false.obs;

  final hasConversation = false.obs;
  final resolved = false.obs;
  final messages = <ConversationMessage>[].obs;

  /// FR-09: this same page's own URL, carrying [_scannerId] — the "Get the
  /// app" CTA opens it via an external launch instead of in-page routing,
  /// so if the app is installed the registered App Link/Universal Link
  /// intercepts it and jumps straight to this conversation; if not, it just
  /// reopens this same web page. Null until the scannerId is loaded.
  final appLinkUrl = Rxn<String>();

  /// True once this visitor has explicitly chosen "Continue on Web". The
  /// choice sticks across reloads so the handoff banner asks once rather
  /// than on every scan of the same sticker.
  final prefersWeb = false.obs;

  StreamSubscription<List<ConversationMessage>>? _messagesSub;
  StreamSubscription<ConversationSummary?>? _metaSub;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    if (vehicleId.isEmpty) {
      isLoading.value = false;
      notFound.value = true;
      return;
    }

    try {
      final data = await _vehicleService.fetchPublicVehicle(vehicleId);
      if (data == null) {
        isLoading.value = false;
        notFound.value = true;
        return;
      }

      _scannerId = await _loadOrCreateScannerId();
      prefersWeb.value = (await SharedPreferences.getInstance()).getBool(_preferWebPrefsKey) ?? false;

      ownerName.value = data['ownerName'] as String? ?? 'A MoveMe resident';
      nickname.value = data['nickname'] as String? ?? '';
      makeModel.value = data['makeModel'] as String? ?? '';
      plateNumber.value = data['plateNumber'] as String? ?? '';
      colorName.value = data['colorName'] as String? ?? '';
      photoUrl.value = data['photoUrl'] as String? ?? '';
      isLoading.value = false;

      _messagesSub = _conversationService.watchMessages(conversationId).listen((msgs) {
        messages.assignAll(msgs);
        if (msgs.isNotEmpty) hasConversation.value = true;
      });
      _metaSub = _conversationService.watchConversation(conversationId).listen((summary) {
        if (summary != null) {
          resolved.value = summary.resolved;
          hasConversation.value = true;
          // This page IS the scanner reading the thread, so an owner reply
          // arriving while it is open is genuinely read. Clearing it here
          // rather than on load also covers the reply that lands while the
          // visitor is sitting on the page.
          if (summary.unreadForScanner) {
            _conversationService.markReadByScanner(conversationId);
          }
        }
      });

      appLinkUrl.value = _deepLinkService.scanLinkFor(vehicleId: vehicleId, scannerId: _scannerId);
      unawaited(_logVisit());
    } catch (e, stack) {
      AppLogger.error('ScanContact', e, stack);
      isLoading.value = false;
      notFound.value = true;
    }
  }

  /// A `scannerId` arriving in the URL (set when this route was opened via
  /// a tapped scan link's App Link/Universal Link handoff, or when sharing
  /// the URL along another channel) takes priority and gets persisted here
  /// too — that's what lets a resident tap the same link again after
  /// installing the app and land back in *this* conversation instead of a
  /// fresh one (FR-09). Otherwise, same as before: load or create this
  /// browser/device's own persisted identity.
  static Future<String> _loadOrCreateScannerId() async {
    final prefs = await SharedPreferences.getInstance();

    final fromLink = Get.parameters['scannerId'];
    if (fromLink != null && fromLink.isNotEmpty) {
      await prefs.setString(_scannerIdPrefsKey, fromLink);
      return fromLink;
    }

    final existing = prefs.getString(_scannerIdPrefsKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final id = List<int>.generate(16, (_) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_scannerIdPrefsKey, id);
    return id;
  }

  static const _locationAskedPrefsKey = 'parktag_location_asked';

  /// The visitor's location, if they shared it — kept for the safety log.
  ScanLocation? _location;

  /// Safety log: records this visit. Location is asked for once per
  /// browser and never required; any failure here is ignored.
  Future<void> _logVisit() async {
    try {
      _location = await _locationIfShared();
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
    }
    try {
      await _conversationService.logScanVisit(vehicleId: vehicleId, scannerId: _scannerId, location: _location);
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
    }
  }

  Future<ScanLocation?> _locationIfShared() async {
    if (!kIsWeb) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_locationAskedPrefsKey) ?? false) return null;
      await prefs.setBool(_locationAskedPrefsKey, true);
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
    );
    return ScanLocation(lat: position.latitude, lng: position.longitude, accuracy: position.accuracy);
  }

  static const maxVoiceSeconds = 120;
  static const _maxVideoBytes = 25 * 1024 * 1024;

  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  /// Photos, videos and voice notes waiting to go with the next message.
  final attachments = <ScannerDraftAttachment>[].obs;

  /// "Sending 2 of 3…" while attachments upload.
  final sendingLabel = RxnString();

  final isRecording = false.obs;
  final recordingSeconds = 0.obs;
  Timer? _recordTimer;
  AudioEncoder _recordEncoder = AudioEncoder.opus;

  Future<void> addPhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
      if (photo == null) return;
      attachments.add(ScannerDraftAttachment(
        kind: MessageKind.image,
        bytes: await photo.readAsBytes(),
        contentType: photo.mimeType ?? 'image/jpeg',
      ));
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
      AppSnackbar.show('Camera unavailable', 'Allow camera access in your browser and try again.');
    }
  }

  Future<void> addVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 1));
      if (video == null) return;
      final bytes = await video.readAsBytes();
      if (bytes.length > _maxVideoBytes) {
        AppSnackbar.show('Video too long', 'Please record a shorter video (under 25 MB).');
        return;
      }
      attachments.add(ScannerDraftAttachment(
        kind: MessageKind.video,
        bytes: bytes,
        contentType: video.mimeType ?? 'video/mp4',
      ));
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
      AppSnackbar.show('Camera unavailable', 'Allow camera access in your browser and try again.');
    }
  }

  void removeAttachment(ScannerDraftAttachment attachment) => attachments.remove(attachment);

  Future<void> startRecording() async {
    if (isRecording.value) return;
    try {
      if (!await _recorder.hasPermission()) {
        AppSnackbar.show('Microphone access needed', 'Allow microphone access in your browser to send a voice note.');
        return;
      }
      _recordEncoder = await _recorder.isEncoderSupported(AudioEncoder.opus) ? AudioEncoder.opus : AudioEncoder.aacLc;
      final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/scan-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(RecordConfig(encoder: _recordEncoder), path: path);
      recordingSeconds.value = 0;
      isRecording.value = true;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingSeconds.value++;
        if (recordingSeconds.value >= maxVoiceSeconds) stopRecording();
      });
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
      isRecording.value = false;
      AppSnackbar.show('Could not start recording', 'Please try again.');
    }
  }

  /// Stops and keeps the note. Under one second is an accidental tap and
  /// is discarded.
  Future<void> stopRecording({bool discard = false}) async {
    if (!isRecording.value) return;
    _recordTimer?.cancel();
    isRecording.value = false;
    final seconds = recordingSeconds.value;
    try {
      final path = await _recorder.stop();
      if (discard || path == null || seconds < 1) return;
      attachments.add(ScannerDraftAttachment(
        kind: MessageKind.voice,
        bytes: await XFile(path).readAsBytes(),
        contentType: _recordEncoder == AudioEncoder.opus ? 'audio/webm' : 'audio/mp4',
        durationSeconds: seconds,
      ));
    } catch (e, s) {
      AppLogger.error('ScanContact', e, s);
      AppSnackbar.show('Could not save the voice note', 'Please try again.');
    }
  }

  /// Uploads attachments one by one (a failed one stays queued for the
  /// next tap), then sends everything in one go through the server.
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if ((text.isEmpty && attachments.isEmpty) || isSending.value || isRecording.value) return;

    isSending.value = true;
    try {
      final total = attachments.length;
      for (var i = 0; i < total; i++) {
        final attachment = attachments[i];
        if (attachment.storagePath != null) continue;
        sendingLabel.value = 'Sending ${i + 1} of $total…';
        attachment.failed.value = false;
        try {
          attachment.storagePath = await _conversationService.uploadScannerAttachment(
            vehicleId: vehicleId,
            scannerId: _scannerId,
            kind: attachment.kind,
            bytes: attachment.bytes,
            contentType: attachment.contentType,
          );
        } catch (e, s) {
          AppLogger.error('ScanContact', e, s);
          attachment.failed.value = true;
          AppSnackbar.show("Couldn't upload an attachment", 'It is still here — tap Send to try again.');
          return;
        }
      }
      sendingLabel.value = 'Sending…';
      await _conversationService.postScannerMessage(
        vehicleId: vehicleId,
        scannerId: _scannerId,
        scannerName: scannerNameController.text.trim(),
        text: text,
        attachments: [
          for (final a in attachments)
            ScannerAttachment(kind: a.kind, storagePath: a.storagePath!, durationSeconds: a.durationSeconds),
        ],
        location: _location,
      );
      messageController.clear();
      attachments.clear();
    } catch (e, stack) {
      AppLogger.error('ScanContact', e, stack);
      AppSnackbar.show('Could not send', 'Something went wrong. Please try again.');
    } finally {
      isSending.value = false;
      sendingLabel.value = null;
    }
  }

  Future<void> toggleResolved() async {
    if (!hasConversation.value) return;
    final next = !resolved.value;
    resolved.value = next;
    try {
      await _conversationService.setResolved(conversationId: conversationId, resolved: next);
    } catch (e, stack) {
      AppLogger.error('ScanContact', e, stack);
      resolved.value = !next;
    }
  }

  Future<void> openApp() async {
    final url = appLinkUrl.value;
    if (url == null) return;
    final link = Uri.parse(url);
    // Browsers never hand a link to an app when it points at the page's own
    // domain, so re-opening this https URL would just reload the page.
    // Android gets an intent:// URL pinned to our package (Play Store if
    // not installed); iOS gets the app's own moveme:// scheme.
    final target = switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse(
          'intent://${link.host}${link.path}?${link.query}'
          '#Intent;scheme=https;package=$androidPackageName;'
          'S.browser_fallback_url=${Uri.encodeComponent(playStoreUrl)};end',
        ),
      TargetPlatform.iOS => link.replace(scheme: 'moveme'),
      _ => link,
    };
    await launchUrl(target, mode: LaunchMode.externalApplication, webOnlyWindowName: '_self');
  }

  /// "Continue on Web" — the visitor stays on this page and is not asked
  /// again. Never force the app open on someone who declined it.
  Future<void> dismissAppHandoff() async {
    prefersWeb.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferWebPrefsKey, true);
  }

  @override
  void onClose() {
    _messagesSub?.cancel();
    _metaSub?.cancel();
    _recordTimer?.cancel();
    if (isRecording.value) _recorder.cancel();
    _recorder.dispose();
    scannerNameController.dispose();
    messageController.dispose();
    super.onClose();
  }
}

/// A photo, video or voice note waiting to be sent from the scan page.
class ScannerDraftAttachment {
  ScannerDraftAttachment({
    required this.kind,
    required this.bytes,
    required this.contentType,
    this.durationSeconds = 0,
  });

  final MessageKind kind;
  final Uint8List bytes;
  final String contentType;
  final int durationSeconds;

  /// Set once uploaded, so a retry never uploads it twice.
  String? storagePath;
  final failed = false.obs;
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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

  String _ownerUid = '';

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

      _ownerUid = data['ownerUid'] as String? ?? '';
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

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending.value) return;

    isSending.value = true;
    try {
      await _conversationService.sendScannerMessage(
        vehicleId: vehicleId,
        scannerId: _scannerId,
        ownerUid: _ownerUid,
        plateNumber: plateNumber.value,
        colorName: colorName.value,
        scannerName: scannerNameController.text.trim(),
        text: text,
      );
      messageController.clear();
    } catch (e, stack) {
      AppLogger.error('ScanContact', e, stack);
      AppSnackbar.show('Could not send', 'Something went wrong. Please try again.');
    } finally {
      isSending.value = false;
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
    // externalApplication is what gives the OS the chance to intercept this
    // as a verified App Link / Universal Link and hand it to the installed
    // app. Without the app, it simply reopens this page.
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    scannerNameController.dispose();
    messageController.dispose();
    super.onClose();
  }
}

import 'dart:async';

import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/conversation_service.dart';
import '../../../app/utils/vehicle_color.dart';
import '../../dashboard/models/message_thread_model.dart';
import '../../../app/utils/app_logger.dart';

/// Lets a signed-in resident scan another car's MoveMe QR sticker right
/// from inside the app — no manual capture button, continuous autofocus,
/// automatic detection, matching the feel of Android's built-in QR
/// scanner. On a valid match, the vehicle/owner identity and the chat
/// room itself are resolved server-side (never trusting anything the
/// client read off the QR beyond the vehicle id) via
/// [ConversationService.resolveVehicleAndOpenChat], then this opens the
/// real in-app Chat screen.
///
/// This is a standalone feature: QR/barcode detection only, never OCR,
/// never touched by or touching the Add Vehicle flow (see
/// ReviewVehicleController for that entirely separate scanner).
class QrScannerController extends GetxController {
  QrScannerController()
    : mobileScannerController = MobileScannerController(
        // Only QR — this scanner has no business reading barcodes/DataMatrix/etc.
        formats: const [BarcodeFormat.qrCode],
        // The SDK's own duplicate suppression, on top of the [_handled]
        // guard below — belt and suspenders against a rapid double-fire.
        detectionSpeed: DetectionSpeed.noDuplicates,
        // Autofocus and continuous detection are mobile_scanner's default
        // behavior (no manual capture button, no manual focus tap needed)
        // — nothing here turns that off.
      );

  final MobileScannerController mobileScannerController;
  final _conversationService = Get.find<ConversationService>();

  final torchOn = false.obs;

  /// True while a detected QR is being resolved against the backend — the
  /// camera is paused for this window (see [onDetect]).
  final isResolving = false.obs;

  /// Drives a transient error banner — set on an unrecognized QR or a
  /// backend resolution failure (vehicle not found, scanning your own
  /// car, ...), auto-cleared a moment later. Scanning always resumes on
  /// its own; the resident never has to leave this screen or take any
  /// action to retry.
  final errorMessage = Rxn<String>();

  bool _handled = false;
  Timer? _errorBannerTimer;

  /// A vehicle sticker's QR encodes `{scanBaseUrl}/scan/{vehicleId}` (see
  /// [VehicleModel.qrScanUrl]) — pull the id out of the path regardless of
  /// host, so this keeps working if the hosting domain ever changes.
  String? _vehicleIdFrom(String rawValue) {
    final uri = Uri.tryParse(rawValue);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final scanIndex = segments.indexOf('scan');
    if (scanIndex == -1 || scanIndex + 1 >= segments.length) return null;
    final id = segments[scanIndex + 1];
    return id.isEmpty ? null : id;
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    String? vehicleId;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      vehicleId = _vehicleIdFrom(raw);
      if (vehicleId != null) break;
    }

    if (vehicleId == null) {
      // Every barcode in this frame was QR but not a MoveMe link (e.g. a
      // random QR code) — surface it briefly and keep scanning; detection
      // was never paused for this branch, so it's already resuming.
      if (capture.barcodes.isNotEmpty) {
        _flashError("That's not a MoveMe code");
      }
      return;
    }

    // Found a valid MoveMe code — lock out further detections and pause
    // the camera while the backend resolves vehicle/owner and creates or
    // fetches the chat room (see resolveVehicleAndOpenChat).
    _handled = true;
    isResolving.value = true;
    await mobileScannerController.stop();

    try {
      final result = await _conversationService.resolveVehicleAndOpenChat(vehicleId: vehicleId);
      isResolving.value = false;
      Get.offNamed(
        AppRoutes.chatThread,
        arguments: MessageThreadModel(
          conversationId: result.conversationId,
          scannerName: '',
          ownerName: result.ownerName,
          plateNumber: result.plateNumber,
          vehicleColor: vehicleColorForName(result.colorName),
          lastMessagePreview: '',
          timeLabel: 'Just now',
          isResolved: result.resolved,
          viewerRole: ThreadViewerRole.scanner,
        ),
      );
    } on ResolveVehicleException catch (e) {
      await _resumeAfterError(e.message);
    } catch (e, stack) {
      AppLogger.error('QrScanner', e, stack);
      await _resumeAfterError("Couldn't open that chat — please try again.");
    }
  }

  /// Backend resolution failed (invalid/removed vehicle, scanning your own
  /// car, network hiccup) — show why, then resume scanning on this same
  /// screen rather than leaving the resident stuck.
  Future<void> _resumeAfterError(String message) async {
    isResolving.value = false;
    _flashError(message);
    _handled = false;
    await mobileScannerController.start();
  }

  void _flashError(String message) {
    errorMessage.value = message;
    _errorBannerTimer?.cancel();
    _errorBannerTimer = Timer(const Duration(seconds: 2), () => errorMessage.value = null);
  }

  Future<void> toggleTorch() async {
    await mobileScannerController.toggleTorch();
    torchOn.value = !torchOn.value;
  }

  @override
  void onClose() {
    _errorBannerTimer?.cancel();
    mobileScannerController.dispose();
    super.onClose();
  }
}

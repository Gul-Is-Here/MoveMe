import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/utils/app_logger.dart';

enum RcCardSide { front, back }

/// Drives the OCR/RC-card scanner — opened ONLY from the "Add Vehicle"
/// button. Delegates the whole capture step to ML Kit's Document Scanner,
/// which runs as Google Play services' own fullscreen flow: automatic
/// document detection, edge-accurate cropping, rotation correction and
/// shadow/stain removal, then hands back a cropped JPEG. ML Kit text
/// recognition runs afterwards, in [ReviewVehicleController], on the
/// cropped front and back images together.
///
/// Android-only by nature — the plugin's iOS side is a stub, so on iOS
/// this screen offers the gallery/manual-entry fallbacks instead (see
/// [isScannerUnavailable]).
///
/// Completely isolated from the QR scanner: no shared imports, no shared
/// state, a different package (`google_mlkit_document_scanner` here vs.
/// `mobile_scanner` there).
class ScanController extends GetxController {
  final _picker = ImagePicker();

  /// True while the choice screen (scan card / enter manually) is showing,
  /// before the resident has picked either option.
  final isChoosing = true.obs;

  /// True while Google's scanner flow is being launched/running for
  /// whichever side is being captured.
  final isLaunching = false.obs;

  /// True when there's no document scanner on this platform (iOS) — the
  /// capture screen then falls back to gallery import for both sides.
  final isScannerUnavailable = false.obs;

  final errorMessage = RxnString();

  /// RC card front/back photos — an ID-card-style two-box capture, the
  /// same idea as scanning the front and back of a CNIC.
  final frontImagePath = RxnString();
  final backImagePath = RxnString();

  bool get hasBothSides =>
      frontImagePath.value != null && backImagePath.value != null;

  @override
  void onInit() {
    super.onInit();
    // iOS never has the scanner, so the choice/capture screens can say so
    // up front rather than waiting for a tap that will just fail.
    if (!Platform.isAndroid) {
      isScannerUnavailable.value = true;
    }
  }

  /// Moves from the initial choice screen into the front/back capture
  /// screen — the scanner itself only launches once a specific side (front
  /// or back) is tapped there.
  void startScanning() {
    isChoosing.value = false;
  }

  /// Back from the capture screen to the scan / enter-manually choice.
  /// Already-captured sides are kept in case the resident comes back.
  void backToChoice() {
    errorMessage.value = null;
    isChoosing.value = true;
  }

  Future<void> scanSide(RcCardSide side) async {
    if (!Platform.isAndroid) {
      isScannerUnavailable.value = true;
      return;
    }
    if (isLaunching.value) return;

    isLaunching.value = true;
    errorMessage.value = null;

    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        pageLimit: 1,
        // `full` enables Google's ML-backed cleanup (shadow/stain removal)
        // plus crop/rotate editing — the cleaner the page, the better the
        // text recognition that runs on it next.
        mode: ScannerMode.full,
        isGalleryImport: true,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final path = result.images?.isNotEmpty ?? false
          ? result.images!.first
          : null;
      if (path == null) {
        errorMessage.value =
            "That scan didn't produce an image. Please try again.";
        return;
      }
      _setPath(side, path);
    } on PlatformException catch (e) {
      // The plugin reports a user cancel as an error, so it has to be told
      // apart from a real failure — backing out of the scanner should just
      // return to the capture screen, not show an error.
      if ((e.message ?? '').toLowerCase().contains('cancel')) {
        return;
      }
      errorMessage.value = "Couldn't open the scanner. Please try again.";
    } on MissingPluginException {
      isScannerUnavailable.value = true;
    } catch (e, stack) {
      AppLogger.error('ScanCard', e, stack);
      errorMessage.value =
          "Something went wrong while scanning. Please try again.";
    } finally {
      isLaunching.value = false;
      await scanner.close();
    }
  }

  /// Gallery fallback for a single side — used directly on iOS (no
  /// scanner at all), and as a manual retake option on Android.
  Future<void> pickSideFromGallery(RcCardSide side) async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo == null) return;
    _setPath(side, photo.path);
  }

  void removeSide(RcCardSide side) {
    if (side == RcCardSide.front) {
      frontImagePath.value = null;
    } else {
      backImagePath.value = null;
    }
  }

  void _setPath(RcCardSide side, String path) {
    if (side == RcCardSide.front) {
      frontImagePath.value = path;
    } else {
      backImagePath.value = path;
    }
  }

  /// Both sides captured — hand them both to Review, which OCRs each and
  /// merges the recognized text to fill the form.
  void next() {
    if (!hasBothSides) return;
    // offNamed, not toNamed: this screen is just a launcher, so Back from
    // the Review screen should return to the dashboard rather than
    // re-triggering the capture flow.
    Get.offNamed(
      AppRoutes.addVehicleReview,
      arguments: {
        'frontImagePath': frontImagePath.value,
        'backImagePath': backImagePath.value,
      },
    );
  }

  void enterManually() {
    Get.offNamed(
      AppRoutes.addVehicleReview,
      arguments: const {'frontImagePath': null, 'backImagePath': null},
    );
  }
}

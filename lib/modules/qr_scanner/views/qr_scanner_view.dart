import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../controllers/qr_scanner_controller.dart';

class QrScannerView extends GetView<QrScannerController> {
  const QrScannerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller.mobileScannerController,
            onDetect: controller.onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          // Dim everything outside the viewfinder frame.
          Obx(
            () => _ScannerOverlay(
              isError: controller.errorMessage.value != null,
              isResolving: controller.isResolving.value,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIconButton(icon: Icons.close, onTap: Get.back),
                  Obx(
                    () => _RoundIconButton(
                      icon: controller.torchOn.value ? Icons.flash_on : Icons.flash_off,
                      onTap: controller.toggleTorch,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Obx(() {
              final error = controller.errorMessage.value;
              if (error != null) {
                return Column(
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingSm.copyWith(color: AppColors.yellow, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Still scanning — try again',
                      style: AppTextStyles.subtitle.copyWith(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                );
              }
              if (controller.isResolving.value) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.yellow),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Opening chat…',
                      style: AppTextStyles.headingSm.copyWith(color: Colors.white, fontSize: 17),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Text(
                    "Scan a car's MoveMe sticker",
                    style: AppTextStyles.headingSm.copyWith(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Point your camera at the QR code — it'll detect automatically",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white70, fontSize: 13),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.isError, required this.isResolving});

  final bool isError;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Colors.redAccent
        : (isResolving ? Colors.white : AppColors.yellow);
    return IgnorePointer(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = error.errorCode == MobileScannerErrorCode.permissionDenied
        ? "MoveMe needs camera access to scan a QR code. Enable it in your device's Settings."
        : "Couldn't start the camera. Please try again.";

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 40, color: AppColors.faint),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

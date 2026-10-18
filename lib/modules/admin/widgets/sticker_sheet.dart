import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/services/sticker_printer.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/glass.dart';
import '../controllers/admin_order_controller.dart';
import 'admin_sheet.dart';

/// One vehicle's sticker from an order: preview, print the ordered copies,
/// or share it as an image.
class StickerSheet extends StatelessWidget {
  const StickerSheet({super.key, required this.item, required this.controller, this.onViewVehicle});

  final OrderItem item;
  final AdminOrderController controller;
  final VoidCallback? onViewVehicle;

  static Future<void> show({
    required OrderItem item,
    required AdminOrderController controller,
    VoidCallback? onViewVehicle,
  }) => AdminSheet.show<void>(StickerSheet(item: item, controller: controller, onViewVehicle: onViewVehicle));

  @override
  Widget build(BuildContext context) {
    final copies = item.quantity;
    return AdminSheet(
      title: item.plateNumber,
      subtitle: '$copies sticker${copies == 1 ? '' : 's'} ordered for this vehicle.',
      children: [
        Center(
          child: StickerPreview(
            plateNumber: item.plateNumber,
            scanUrl: StickerPrint(vehicleId: item.vehicleId, plateNumber: item.plateNumber).scanUrl,
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => GlassPrimaryButton(
            icon: Icons.print_rounded,
            label: copies == 1 ? 'Print Sticker' : 'Print $copies Stickers',
            isLoading: controller.busyJob.value == 'print:${item.vehicleId}',
            onPressed: () => controller.printSticker(item),
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => GlassSecondaryButton(
            label: 'Share Image',
            icon: Icons.image_outlined,
            isLoading: controller.busyJob.value == 'image:${item.vehicleId}',
            onPressed: () => controller.shareStickerImage(item),
          ),
        ),
        if (onViewVehicle != null) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              Get.back();
              onViewVehicle!();
            },
            child: Text(
              "View this vehicle on the customer's account",
              style: AppTextStyles.buttonLabel.copyWith(color: AppColors.yellow, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}

/// The sticker as it prints: the MoveMe frame — black in the light theme,
/// white in the dark one — around the QR code and the plate.
class StickerPreview extends StatelessWidget {
  const StickerPreview({super.key, required this.plateNumber, required this.scanUrl, this.width = 240});

  final String plateNumber;
  final String scanUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    final frame = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: frame, width: 6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset('assets/Applogo.png', width: 20, height: 20),
              ),
              const SizedBox(width: 6),
              Text('MoveMe', style: AppTextStyles.headingSm.copyWith(color: Colors.black, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Blocking you in? Scan to message the owner',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: Colors.black87, fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          QrImageView(
            data: scanUrl,
            size: width - 70,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(plateNumber, style: AppTextStyles.headingSm.copyWith(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

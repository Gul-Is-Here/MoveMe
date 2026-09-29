import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/vehicle_model.dart';
import 'vehicle_image_thumb.dart';
import 'vehicle_qr_thumb.dart';

/// One owned vehicle on the Home tab. Shows only fields the vehicle
/// document actually carries — photo, nickname, make/model, colour and
/// plate — plus its QR thumbnail, which is the point of the app.
class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, this.hasUnread = false});

  final VehicleModel vehicle;

  /// Driven by the Inbox listener rather than [VehicleModel.hasUnread],
  /// which is never populated anywhere in the app.
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.vehicleDetails, arguments: vehicle),
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.yellow.withValues(alpha: 0.06),
        highlightColor: AppColors.yellow.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasUnread ? AppColors.yellow.withValues(alpha: 0.5) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: hasUnread
                    ? AppColors.yellow.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              VehicleImageThumb(photoPaths: vehicle.photoPaths),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.nickname.isEmpty ? vehicle.makeModel : vehicle.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headingSm.copyWith(
                              color: AppColors.ink,
                              fontSize: 16,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          const _UnreadDot(),
                        ],
                      ],
                    ),
                    if (vehicle.makeModel.isNotEmpty && vehicle.nickname.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        vehicle.makeModel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    _PlateChip(vehicle: vehicle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const VehicleQrThumb(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.vehicle});

  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vehicle.color,
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              vehicle.plateNumber,
              style: AppTextStyles.label.copyWith(color: AppColors.muted, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paired with the yellow card border, so "has unread" is never carried by
/// colour alone.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Unread messages',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.yellow,
          boxShadow: [
            BoxShadow(color: AppColors.yellow.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

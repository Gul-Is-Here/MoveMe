import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/vehicle_input.dart';
import '../../../app/widgets/motion.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../controllers/review_vehicle_controller.dart';
import '../utils/card_validator.dart';
import '../widgets/add_vehicle_top_bar.dart';
import '../widgets/form_section_card.dart';
import '../widgets/vehicle_form_field.dart';
import '../widgets/vehicle_photos_section.dart';

/// Step 3 of Add Vehicle — both the "review what the scan read" screen and
/// the "enter manual details" screen (same form, no card panel).
class ReviewVehicleView extends GetView<ReviewVehicleController> {
  const ReviewVehicleView({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.background;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.6, -1),
                    radius: 1.1,
                    colors: [
                      AppColors.yellow.withValues(alpha: 0.12),
                      AppColors.yellow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AddVehicleTopBar(step: 2, onLeading: Get.back),
                  const SizedBox(height: 22),
                  RiseIn(order: 0, child: _Heading(scanned: controller.hasScannedCard)),
                  if (controller.hasScannedCard) ...[
                    const SizedBox(height: 20),
                    RiseIn(order: 1, child: _ScannedCardPanel(controller: controller)),
                  ],
                  const SizedBox(height: 20),
                  RiseIn(
                    order: 2,
                    child: FormSectionCard(
                      icon: Icons.directions_car_filled_rounded,
                      title: 'Vehicle',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Obx(
                                () => VehicleFormField(
                                  label: 'Make',
                                  controller: controller.make,
                                  hint: 'US 70',
                                  fillColor: fill,
                                  helper: controller.isLowConfidence(CardField.make)
                                      ? '⚠ check'
                                      : null,
                                  inputFormatters: [vehicleNameFormatter],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Obx(
                                () => VehicleFormField(
                                  label: 'Maker Name',
                                  controller: controller.model,
                                  hint: 'UNITED',
                                  fillColor: fill,
                                  helper: controller.isLowConfidence(CardField.makerName)
                                      ? '⚠ check'
                                      : null,
                                  inputFormatters: [vehicleNameFormatter],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Obx(
                          () => VehicleFormField(
                            label: 'Registration number (plate)',
                            controller: controller.plateNumber,
                            hint: 'LEA-2231',
                            fillColor: fill,
                            helper: controller.isLowConfidence(CardField.plateNumber)
                                ? '⚠ check'
                                : null,
                            emphasize: true,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [vehicleIdentifierFormatter],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RiseIn(
                    order: 3,
                    child: FormSectionCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Registration',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: VehicleFormField(
                                label: 'Color',
                                controller: controller.color,
                                hint: 'White',
                                fillColor: fill,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: VehicleFormField(
                                label: 'Date of registration',
                                controller: controller.dateOfRegistration,
                                hint: '14 Mar 2022',
                                fillColor: fill,
                                readOnly: true,
                                onTap: () => controller.pickRegistrationDate(context),
                                suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 17,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        VehicleFormField(
                          label: 'Engine number',
                          controller: controller.engineNumber,
                          hint: '2ZR-4498231',
                          fillColor: fill,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [vehicleIdentifierFormatter],
                        ),
                        Obx(
                          () => VehicleFormField(
                            label: 'Chassis number',
                            controller: controller.chassisNumber,
                            hint: 'MR053CE3204119876',
                            fillColor: fill,
                            helper: controller.isLowConfidence(CardField.chassisNumber)
                                ? '⚠ check'
                                : null,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [vehicleIdentifierFormatter],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RiseIn(
                    order: 4,
                    child: FormSectionCard(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      children: [
                        VehicleFormField(
                          label: 'Registered address',
                          helper: '(optional)',
                          controller: controller.address,
                          hint: '123 B Model Town Lahore',
                          fillColor: fill,
                          maxLines: 2,
                          inputFormatters: [vehicleNameFormatter],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RiseIn(
                    order: 5,
                    child: Obx(
                      () => VehiclePhotosSection(
                        photoPaths: [for (final p in controller.vehiclePhotos) p.path],
                        requiredCount: ReviewVehicleController.requiredVehiclePhotos,
                        onPick: () => _pickPhoto(context),
                        onRemove: controller.removeVehiclePhoto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RiseIn(order: 6, child: _SaveArea(controller: controller)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source != null) {
      await controller.addVehiclePhoto(source);
    }
  }

}

class _Heading extends StatelessWidget {
  const _Heading({required this.scanned});

  final bool scanned;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review vehicle details',
          style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 25),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scanned ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  scanned
                      ? 'Read from your RC card — check before saving'
                      : 'Enter your vehicle details',
                  style: AppTextStyles.label.copyWith(
                    color: accent,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scanned card preview + OCR status
// ---------------------------------------------------------------------------

class _ScannedCardPanel extends StatelessWidget {
  const _ScannedCardPanel({required this.controller});

  final ReviewVehicleController controller;

  @override
  Widget build(BuildContext context) {
    final front = controller.frontImagePath;
    final back = controller.backImagePath;

    return Obx(() {
      final reading = controller.isScanningRcCard.value;
      final failed = controller.ocrFailed.value;

      return FormSectionCard(
        icon: Icons.document_scanner_outlined,
        title: 'RC card',
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: reading
              ? const _StatusChip(key: ValueKey('reading'), kind: _Status.reading)
              : failed
              ? const _StatusChip(key: ValueKey('failed'), kind: _Status.failed)
              : const _StatusChip(key: ValueKey('done'), kind: _Status.done),
        ),
        children: [
          Row(
            children: [
              if (front != null)
                Expanded(child: _CardThumb(path: front, label: 'Front', reading: reading)),
              if (front != null && back != null) const SizedBox(width: 12),
              if (back != null)
                Expanded(child: _CardThumb(path: back, label: 'Back', reading: reading)),
            ],
          ),
          if (failed && !reading)
            Center(
              child: Pressable(
                onTap: controller.retryOcrScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.yellow.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 16, color: AppColors.yellow),
                      const SizedBox(width: 6),
                      Text(
                        'Retry scan',
                        style: AppTextStyles.linkTextEmphasis.copyWith(color: AppColors.yellow),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

enum _Status { reading, failed, done }

class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.kind});

  final _Status kind;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (kind) {
      _Status.reading => (AppColors.yellow, 'Reading card…'),
      _Status.failed => (Colors.redAccent, 'Scan failed'),
      _Status.done => (AppColors.success, 'Card read'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == _Status.reading)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else
            Icon(
              kind == _Status.done ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 13,
              color: color,
            ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: color,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.path, required this.label, required this.reading});

  final String path;
  final String label;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.586,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(color: AppColors.background),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: reading ? const _ReadingOverlay() : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.label.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Dims a card thumbnail and sweeps a glowing scan line over it while the
/// card is being read.
class _ReadingOverlay extends StatefulWidget {
  const _ReadingOverlay();

  @override
  State<_ReadingOverlay> createState() => _ReadingOverlayState();
}

class _ReadingOverlayState extends State<_ReadingOverlay> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_loop.isAnimating) {
      _loop.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final y = Curves.easeInOutSine.transform(_loop.value) * constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
              Positioned(
                left: 0,
                right: 0,
                top: y - 1,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.9),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save
// ---------------------------------------------------------------------------

class _SaveArea extends StatelessWidget {
  const _SaveArea({required this.controller});

  final ReviewVehicleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enoughPhotos =
          controller.vehiclePhotos.length >= ReviewVehicleController.requiredVehiclePhotos;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(
            label: 'Save Vehicle',
            isLoading: controller.isSaving.value,
            onPressed: !enoughPhotos ? null : controller.save,
          ),
          PhotosRequiredHint(visible: !enoughPhotos),
        ],
      );
    });
  }
}

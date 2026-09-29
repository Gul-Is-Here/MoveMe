import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/vehicle_input.dart';
import '../../../app/widgets/motion.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../../vehicle/widgets/form_section_card.dart';
import '../../vehicle/widgets/vehicle_form_field.dart';
import '../../vehicle/widgets/vehicle_photos_section.dart';
import '../controllers/edit_vehicle_controller.dart';
import '../widgets/number_plate.dart';

class EditVehicleView extends GetView<EditVehicleController> {
  const EditVehicleView({super.key});

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
                  const RiseIn(order: 0, child: _Header()),
                  const SizedBox(height: 18),
                  RiseIn(order: 1, child: _LivePreview(controller: controller)),
                  const SizedBox(height: 14),
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
                              child: VehicleFormField(
                                label: 'Make',
                                controller: controller.make,
                                hint: 'US 70',
                                fillColor: fill,
                                inputFormatters: [vehicleNameFormatter],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: VehicleFormField(
                                label: 'Maker Name',
                                controller: controller.model,
                                hint: 'UNITED',
                                fillColor: fill,
                                inputFormatters: [vehicleNameFormatter],
                              ),
                            ),
                          ],
                        ),
                        VehicleFormField(
                          label: 'Registration number (plate)',
                          controller: controller.plateNumber,
                          hint: 'LEA-2231',
                          fillColor: fill,
                          emphasize: true,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [vehicleIdentifierFormatter],
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
                        VehicleFormField(
                          label: 'Chassis number',
                          controller: controller.chassisNumber,
                          hint: 'MR053CE3204119876',
                          fillColor: fill,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [vehicleIdentifierFormatter],
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
                        photoPaths: List.of(controller.vehiclePhotos),
                        requiredCount: EditVehicleController.requiredVehiclePhotos,
                        onPick: () => _pickPhoto(context),
                        onRemove: controller.removeVehiclePhoto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RiseIn(
                    order: 6,
                    child: Obx(() {
                      final enoughPhotos =
                          controller.vehiclePhotos.length >= EditVehicleController.requiredVehiclePhotos;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthPrimaryButton(
                            label: 'Save Changes',
                            isLoading: controller.isSaving.value,
                            onPressed: !enoughPhotos ? null : controller.save,
                          ),
                          PhotosRequiredHint(visible: !enoughPhotos),
                        ],
                      );
                    }),
                  ),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          child: Pressable(
            onTap: Get.back,
            scale: 0.9,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 19),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Vehicle',
                style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 23),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 15, color: accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "Update your vehicle's saved details",
                      style: AppTextStyles.label.copyWith(color: accent, letterSpacing: 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A live summary of the vehicle being edited — photo, make/model and the
/// number plate update as the fields below change.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.controller});

  final EditVehicleController controller;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Obx(() {
            final photos = controller.vehiclePhotos;
            return _PreviewThumb(path: photos.isEmpty ? null : photos.first);
          }),
          const SizedBox(width: 14),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                controller.make,
                controller.model,
                controller.plateNumber,
                controller.color,
              ]),
              builder: (context, _) {
                final makeModel = '${controller.make.text.trim()} ${controller.model.text.trim()}'.trim();
                final color = controller.color.text.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE PREVIEW',
                      style: AppTextStyles.overline.copyWith(color: accent, fontSize: 9.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [makeModel.isEmpty ? 'Your vehicle' : makeModel, if (color.isNotEmpty) color].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    NumberPlate(plate: controller.plateNumber.text, compact: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(Icons.directions_car_filled_rounded, color: AppColors.yellow, size: 30),
    );
    final path = this.path;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: path == null
            ? fallback
            : path.startsWith('http')
            ? Image.network(path, key: ValueKey(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)
            : Image.file(File(path), key: ValueKey(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

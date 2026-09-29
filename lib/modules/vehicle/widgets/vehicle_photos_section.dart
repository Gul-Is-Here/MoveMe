import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/motion.dart';
import 'form_section_card.dart';
import 'vehicle_photo_tile.dart';

/// The "Photos" card shared by Add Vehicle (Review) and Edit Vehicle: a
/// live "n of 2 added" count, a progress bar that turns green when
/// complete, and the front/back photo slots.
class VehiclePhotosSection extends StatelessWidget {
  const VehiclePhotosSection({
    super.key,
    required this.photoPaths,
    required this.requiredCount,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> photoPaths;
  final int requiredCount;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = photoPaths.length;
    final done = count >= requiredCount;
    final color = done ? AppColors.success : AppColors.yellow;

    return FormSectionCard(
      icon: Icons.photo_camera_outlined,
      title: 'Photos',
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count of $requiredCount added',
          style: AppTextStyles.label.copyWith(
            color: color,
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'VEHICLE PHOTOS',
              style: AppTextStyles.label.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              "Add at least 2 photos of your vehicle so scanners can confirm it's the right car.",
              style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (count / requiredCount).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  color: color,
                  backgroundColor: AppColors.border,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: VehiclePhotoTile(
                label: 'Front view',
                imagePath: count > 0 ? photoPaths[0] : null,
                onTap: onPick,
                onRemove: count > 0 ? () => onRemove(0) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: VehiclePhotoTile(
                label: 'Back view',
                imagePath: count > 1 ? photoPaths[1] : null,
                onTap: onPick,
                onRemove: count > 1 ? () => onRemove(1) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Add 2 vehicle photos to continue" under a save button, collapsing
/// away once enough photos are in.
class PhotosRequiredHint extends StatelessWidget {
  const PhotosRequiredHint({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.faint),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Add 2 vehicle photos to continue',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: AppColors.faint),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Bottom sheet asking where a new vehicle photo should come from.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _PhotoSourceSheet(),
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, String label, ImageSource source) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: () => Navigator.pop(context, source),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.yellow, AppColors.accentDeep],
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add a vehicle photo',
              style: AppTextStyles.headingSm.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'A clear shot of the whole car works best.',
              style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                option(Icons.photo_camera_outlined, 'Take a photo', ImageSource.camera),
                const SizedBox(width: 12),
                option(Icons.photo_library_outlined, 'Choose from gallery', ImageSource.gallery),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../dashboard/models/chat_message_model.dart';

/// "Take a photo" / "Record a video" — resolves to the chosen kind.
class MediaSourceSheet extends StatelessWidget {
  const MediaSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, String label, String subtitle, ChatMessageKind kind) => ListTile(
          leading: Icon(icon, color: AppColors.yellow),
          title: Text(label, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
          subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
          onTap: () => Get.back(result: kind),
        );

    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(Icons.photo_camera_outlined, 'Take a photo', 'Show where the car is parked', ChatMessageKind.photo),
              option(Icons.videocam_outlined, 'Record a video', 'Up to 1 minute', ChatMessageKind.video),
            ],
          ),
        ),
      ),
    );
  }
}

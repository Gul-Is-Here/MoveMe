import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/services/conversation_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/media_viewers.dart';
import '../controllers/scan_contact_controller.dart';

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Photo / video / voice buttons, the recording bar, and previews of what
/// will be sent (each removable until it is).
class ScanAttachmentBar extends GetView<ScanContactController> {
  const ScanAttachmentBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.isSending.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.isRecording.value)
            _RecordingBar(controller: controller)
          else
            Row(
              children: [
                _ToolButton(icon: Icons.photo_camera_outlined, label: 'Photo', onTap: busy ? null : controller.addPhoto),
                const SizedBox(width: 8),
                _ToolButton(icon: Icons.videocam_outlined, label: 'Video', onTap: busy ? null : controller.addVideo),
                const SizedBox(width: 8),
                _ToolButton(icon: Icons.mic_none_rounded, label: 'Voice', onTap: busy ? null : controller.startRecording),
              ],
            ),
          if (controller.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in controller.attachments)
                  _AttachmentPreview(attachment: a, onRemove: busy ? null : () => controller.removeAttachment(a)),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.ink),
        label: Text(label, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.controller});

  final ScanContactController controller;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE5675E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record_rounded, color: red, size: 14),
          const SizedBox(width: 8),
          Obx(
            () => Text(
              'Recording ${_clock(controller.recordingSeconds.value)} / ${_clock(ScanContactController.maxVoiceSeconds)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => controller.stopRecording(discard: true),
            child: Text('Cancel', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.muted, fontSize: 13)),
          ),
          TextButton(
            onPressed: controller.stopRecording,
            child: Text('Done', style: AppTextStyles.buttonLabel.copyWith(color: red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.onRemove});

  final ScannerDraftAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = switch (attachment.kind) {
      MessageKind.voice => 'Voice ${_clock(attachment.durationSeconds)}',
      MessageKind.video => 'Video',
      _ => 'Photo',
    };
    return Obx(() {
      final failed = attachment.failed.value;
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: failed ? const Color(0xFFE5675E) : AppColors.border, width: failed ? 2 : 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: attachment.kind == MessageKind.image
                    ? Image.memory(attachment.bytes, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            attachment.kind == MessageKind.voice ? Icons.mic_rounded : Icons.videocam_rounded,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 4),
                          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
              ),
            ),
            if (failed)
              const Positioned(
                left: 4,
                bottom: 4,
                child: Icon(Icons.error_rounded, size: 18, color: Color(0xFFE5675E)),
              ),
            if (attachment.storagePath != null)
              Positioned(left: 4, bottom: 4, child: Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success)),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Remove $label',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// A voice note, photo or video inside a message on the scan page.
class ScanMessageMedia extends StatelessWidget {
  const ScanMessageMedia({super.key, required this.message, required this.onDark});

  final ConversationMessage message;

  /// The visitor's own bubbles are filled with the accent colour.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? AppColors.background : AppColors.ink;
    switch (message.kind) {
      case MessageKind.voice:
        final url = message.audioUrl;
        return url == null ? const SizedBox.shrink() : _VoiceNote(url: url, seconds: message.durationSeconds, color: color);
      case MessageKind.image:
        final url = message.mediaUrl;
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showPhotoFullScreen(NetworkImage(url)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 120,
                color: Colors.black12,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: color),
              ),
            ),
          ),
        );
      case MessageKind.video:
        final url = message.mediaUrl;
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showVideoFullScreen(url),
          child: Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.play_circle_fill_rounded, size: 44, color: Colors.white),
          ),
        );
      case MessageKind.text:
        return const SizedBox.shrink();
    }
  }
}

class _VoiceNote extends StatefulWidget {
  const _VoiceNote({required this.url, required this.seconds, required this.color});

  final String url;
  final int seconds;
  final Color color;

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  final _player = AudioPlayer();
  bool _loaded = false;

  Future<void> _toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }
      if (!_loaded) {
        await _player.setUrl(widget.url);
        _loaded = true;
      }
      if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      // A note that can't load just stays paused.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _player.playingStream,
      builder: (_, snap) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: snap.data == true ? 'Pause voice note' : 'Play voice note',
            onPressed: _toggle,
            icon: Icon(snap.data == true ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: widget.color, size: 32),
          ),
          Flexible(
            child: Text(
              'Voice note · ${_clock(widget.seconds)}',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: widget.color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

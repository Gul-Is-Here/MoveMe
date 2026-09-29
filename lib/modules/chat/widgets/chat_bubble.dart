import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../dashboard/models/chat_message_model.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.isOutgoing = false,
    this.showTail = true,
    this.onRetry,
  });

  final ChatMessageModel message;

  /// Whether this message was sent by the person looking at the screen.
  /// Not the same as "from the owner": the scanner side of a conversation
  /// sees their own messages on the right too.
  final bool isOutgoing;

  /// False for a message in the middle of a run from the same sender —
  /// grouped messages drop the timestamp row and the bubble's tail.
  final bool showTail;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isOwner = isOutgoing;

    return Align(
      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildContent(isOwner),
            if (showTail || message.status != ChatMessageStatus.sent) ...[
              const SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.only(left: isOwner ? 0 : 4, right: isOwner ? 4 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.timeLabel,
                      style: AppTextStyles.caption.copyWith(color: AppColors.faint, fontSize: 11),
                    ),
                    // Outgoing messages show only what the backend can
                    // actually confirm: in flight, written, or failed.
                    // There is no delivery or read receipt in the schema,
                    // so no double-tick is shown.
                    if (isOwner) ...[
                      const SizedBox(width: 5),
                      switch (message.status) {
                        ChatMessageStatus.sending => SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.4, color: AppColors.faint),
                        ),
                        ChatMessageStatus.sent => Icon(Icons.check, size: 13, color: AppColors.faint),
                        ChatMessageStatus.failed => const Icon(
                          Icons.error_outline,
                          size: 13,
                          color: Color(0xFFE0736B),
                        ),
                      },
                    ],
                  ],
                ),
              ),
            ],
            if (message.status == ChatMessageStatus.failed) ...[
              const SizedBox(height: 3),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Not sent · Tap to retry',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFE0736B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isOwner) {
    final tail = showTail ? const Radius.circular(4) : const Radius.circular(16);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isOwner ? const Radius.circular(16) : tail,
      bottomRight: isOwner ? tail : const Radius.circular(16),
    );

    switch (message.kind) {
      case ChatMessageKind.text:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOwner ? AppColors.yellow : AppColors.surface,
            borderRadius: radius,
            border: isOwner ? null : Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(
            message.text,
            style: AppTextStyles.fieldValue.copyWith(
              color: isOwner ? AppColors.background : AppColors.ink,
              fontWeight: isOwner ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        );
      case ChatMessageKind.voice:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isOwner ? AppColors.yellow : AppColors.surface,
            borderRadius: radius,
            border: isOwner ? null : Border.all(color: AppColors.border, width: 1.5),
          ),
          child: _VoiceBubbleContent(message: message, isOwner: isOwner),
        );
      case ChatMessageKind.photo:
        return ClipRRect(
          borderRadius: radius,
          child: Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.border, Color(0xFF1B1B18)],
              ),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Icon(Icons.image_outlined, size: 26, color: AppColors.faint),
          ),
        );
    }
  }
}

/// The play/pause control and waveform-style row inside a voice bubble.
/// Owns its own [AudioPlayer] — each bubble plays independently, and this
/// widget's [dispose] releases the player the moment the bubble scrolls
/// out and is recycled by [ListView.builder].
class _VoiceBubbleContent extends StatefulWidget {
  const _VoiceBubbleContent({required this.message, required this.isOwner});

  final ChatMessageModel message;
  final bool isOwner;

  @override
  State<_VoiceBubbleContent> createState() => _VoiceBubbleContentState();
}

class _VoiceBubbleContentState extends State<_VoiceBubbleContent> {
  final _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _stateSub;
  PlayerState _state = PlayerState(false, ProcessingState.idle);
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen(
      (state) {
        if (state.processingState == ProcessingState.completed) {
          _player.pause();
          _player.seek(Duration.zero);
        }
        if (mounted) setState(() => _state = state);
      },
      onError: (Object e, StackTrace st) => AppLogger.error('VoiceBubble', e, st),
    );
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _isPlaying => _state.playing && _state.processingState != ProcessingState.completed;

  bool get _isBuffering =>
      _preparing ||
      (_state.playing &&
          (_state.processingState == ProcessingState.loading ||
              _state.processingState == ProcessingState.buffering));

  Future<void> _toggle() async {
    final url = widget.message.audioUrl;
    if (url == null) return;

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    try {
      if (_player.audioSource == null) {
        setState(() => _preparing = true);
        // The default iOS session is silenced by the ringer switch and, right
        // after a recording, can stay routed to the earpiece.
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await _player.setUrl(url);
      }
      // play() only completes when playback stops, so it must not be awaited.
      unawaited(_player.play().catchError((Object e, StackTrace st) {
        AppLogger.error('VoiceBubble', e, st);
      }));
    } catch (e, st) {
      AppLogger.error('VoiceBubble', e, st);
      AppSnackbar.show('Could not play voice message', 'Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.isOwner;
    final iconColor = AppColors.yellow;
    final uploading = widget.message.audioUrl == null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: uploading ? null : _toggle,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isOwner ? AppColors.surface : AppColors.yellow.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: (_isBuffering || uploading)
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 1.6, color: iconColor),
                  )
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.graphic_eq, size: 18, color: isOwner ? AppColors.background : AppColors.muted),
        const SizedBox(width: 10),
        Text(
          widget.message.voiceDuration,
          style: AppTextStyles.caption.copyWith(
            color: isOwner ? AppColors.background : AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

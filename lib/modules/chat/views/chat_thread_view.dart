import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/widgets/bound_view.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../dashboard/models/chat_message_model.dart';
import '../../dashboard/models/message_thread_model.dart';
import '../controllers/chat_thread_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/resolved_banner.dart';

class ChatThreadView extends BoundView<ChatThreadController> {
  const ChatThreadView({super.key});

  @override
  Widget buildWith(BuildContext context, ChatThreadController controller) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller),
            Obx(
              () => ResolvedBanner(
                isResolved: controller.isResolved.value,
                onResolved: controller.markResolved,
                onNotResolved: controller.markNotResolved,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Obx(
                    // toList() reads through the RxList's own operators,
                    // which is what registers this Obx as a listener.
                    // Passing the RxList itself would not.
                    () => _MessageList(controller: controller, messages: controller.messages.toList()),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Obx(
                      () => AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        offset: controller.hasUnseenIncoming.value ? Offset.zero : const Offset(0, 1.6),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: controller.hasUnseenIncoming.value ? 1 : 0,
                          child: Center(
                            child: _NewMessagePill(onTap: controller.jumpToLatest),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _InputBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// Renders the thread with consecutive messages from the same sender
/// grouped together, and a date separator whenever the day changes.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.controller, required this.messages});

  final ChatThreadController controller;
  final List<ChatMessageModel> messages;

  /// The viewer sends as whichever side of the conversation they are on,
  /// so "mine" is role-relative, not always the owner.
  bool _isOutgoing(ChatMessageModel m) {
    final mine = controller.thread.viewerRole == ThreadViewerRole.owner
        ? ChatSender.owner
        : ChatSender.scanner;
    return m.sender == mine;
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'No messages yet. Say hello — the other person will get a notification.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.faint, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index == 0 ? null : messages[index - 1];
        final next = index == messages.length - 1 ? null : messages[index + 1];

        final showDate = previous == null || !_sameDay(previous.createdAt, message.createdAt);
        // The last message of a run from one sender keeps the tail and the
        // timestamp; the ones above it are visually joined to it.
        final showTail = next == null || next.sender != message.sender;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateSeparator(at: message.createdAt),
            Padding(
              padding: EdgeInsets.only(top: previous == null || showDate ? 0 : (showTail ? 4 : 3)),
              child: ChatBubble(
                message: message,
                isOutgoing: _isOutgoing(message),
                showTail: showTail,
                onRetry: () => controller.retry(message),
              ),
            ),
            if (showTail) const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.at});

  final DateTime? at;

  String get _label {
    final when = at;
    if (when == null) return 'Today';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final base = '${months[when.month - 1]} ${when.day}';
    return when.year == now.year ? base : '$base, ${when.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _label,
            style: AppTextStyles.overline.copyWith(color: AppColors.muted, letterSpacing: 0.4),
          ),
        ),
      ),
    );
  }
}

class _NewMessagePill extends StatelessWidget {
  const _NewMessagePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward, size: 14, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              'New message',
              style: AppTextStyles.label.copyWith(color: Colors.black, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ChatThreadController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Icon(Icons.arrow_back, color: AppColors.ink, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: Color(0xFF2A2210), shape: BoxShape.circle),
            child: Icon(Icons.person_outline, size: 17, color: AppColors.yellow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.counterpartName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: controller.vehicleColor,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(controller.plateNumber, style: AppTextStyles.overline.copyWith(color: AppColors.muted, letterSpacing: 0)),
                  ],
                ),
              ],
            ),
          ),
          // Disabled for this module — re-enable by uncommenting. The
          // controller method behind these (`startCall`) is untouched.
          // _IconButton(icon: Icons.call_outlined, onTap: () => controller.startCall(video: false)),
          // const SizedBox(width: 8),
          // _IconButton(icon: Icons.videocam_outlined, onTap: () => controller.startCall(video: true)),
        ],
      ),
    );
  }
}

// Only used by the call/attachment buttons commented out above — kept so
// re-enabling them doesn't also mean rebuilding this widget.
// ignore: unused_element
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: AppColors.ink),
      ),
    );
  }
}

/// Bottom composer. The trailing control swaps between "record a voice
/// note" and "send" depending on whether there is text — the send action
/// is never hidden behind a long-press once the user has typed something.
class _InputBar extends StatefulWidget {
  const _InputBar({required this.controller});

  final ChatThreadController controller;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.textController.text.trim().isNotEmpty;
    widget.controller.textController.addListener(_sync);
  }

  void _sync() {
    final has = widget.controller.textController.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    // The TextEditingController belongs to the GetX controller, which
    // disposes it — only this listener is ours to remove.
    widget.controller.textController.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Obx(
        () => controller.isRecording.value
            ? _RecordingBar(controller: controller)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Disabled for this module — re-enable by uncommenting.
                  // The controller method behind this (`attachMedia`) is
                  // untouched.
                  // Padding(
                  //   padding: const EdgeInsets.only(bottom: 3),
                  //   child: _IconButton(icon: Icons.attach_file, onTap: controller.attachMedia),
                  // ),
                  // const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 42, maxHeight: 132),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: TextField(
                        controller: controller.textController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: AppColors.yellow,
                        style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink, fontSize: 14, height: 1.35),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Message ${controller.counterpartName}...',
                          hintStyle: AppTextStyles.manropeBase.copyWith(color: AppColors.faint, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: _hasText ? controller.sendText : controller.startVoiceRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Icon(
                            _hasText ? Icons.send_rounded : Icons.mic_none,
                            key: ValueKey(_hasText),
                            size: 18,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Replaces the composer while a voice message is being recorded: a cancel
/// (delete) button, a live elapsed timer with a pulsing mic, and a send
/// button — the three actions the recording flow needs, laid out like the
/// rest of the composer.
class _RecordingBar extends StatefulWidget {
  const _RecordingBar({required this.controller});

  final ChatThreadController controller;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _label(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: controller.cancelVoiceRecording,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE0736B)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
                  child: const Icon(Icons.fiber_manual_record, size: 12, color: Color(0xFFE0736B)),
                ),
                const SizedBox(width: 10),
                Obx(
                  () => Text(
                    _label(controller.recordingSeconds.value),
                    style: AppTextStyles.fieldValue.copyWith(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Recording voice message…',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.faint, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: controller.sendVoiceRecording,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 20, color: AppColors.background),
          ),
        ),
      ],
    );
  }
}

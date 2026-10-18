import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../app/services/conversation_service.dart';
import '../../dashboard/models/chat_message_model.dart';
import '../../dashboard/models/message_thread_model.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../utils/video_compression.dart';
import '../widgets/media_source_sheet.dart';

class ChatThreadController extends GetxController {
  ChatThreadController({required this.thread});

  final MessageThreadModel thread;
  final _conversationService = Get.find<ConversationService>();

  final textController = TextEditingController();
  final scrollController = ScrollController();

  /// Confirmed messages from Firestore, plus any optimistic ones this
  /// device is still sending or failed to send.
  final messages = <ChatMessageModel>[].obs;
  final _pending = <ChatMessageModel>[].obs;

  late final isResolved = thread.isResolved.obs;

  /// True when the reader has scrolled away from the newest messages. New
  /// arrivals must not yank them back down, so the view shows a tappable
  /// "new message" pill instead.
  final isAwayFromLatest = false.obs;
  final hasUnseenIncoming = false.obs;

  final _recorder = AudioRecorder();
  final isRecording = false.obs;
  final recordingSeconds = 0.obs;
  Timer? _recordTimer;
  String? _recordingPath;

  /// Draft text typed but not sent, kept so returning to the thread does
  /// not silently discard it.
  static final _drafts = <String, String>{};

  int _lastConfirmedCount = 0;

  /// Set in [onClose]. A queued post-frame scroll callback can otherwise
  /// still fire after the screen is gone and touch a disposed
  /// ScrollController — the same class of crash as resolving a deleted
  /// controller from a rebuild.
  bool _closed = false;

  StreamSubscription<List<ConversationMessage>>? _messagesSub;
  StreamSubscription<ConversationSummary?>? _metaSub;

  String get scannerName => thread.scannerName;
  String get plateNumber => thread.plateNumber;
  Color get vehicleColor => thread.vehicleColor;

  /// Who this screen's header should show as "who you're talking to" —
  /// the scanner, from the owner's side; the owner, from the scanner's
  /// side (never the viewer's own name).
  String get counterpartName {
    if (thread.viewerRole == ThreadViewerRole.owner) return thread.scannerName;
    return thread.ownerName.isEmpty ? 'Car owner' : thread.ownerName;
  }

  @override
  void onInit() {
    super.onInit();
    textController.text = _drafts[thread.conversationId] ?? '';
    scrollController.addListener(_onScroll);

    _messagesSub = _conversationService.watchMessages(thread.conversationId).listen((msgs) {
      final confirmed = msgs
          .map(
            (m) => ChatMessageModel(
              sender: m.sender == MessageSender.owner ? ChatSender.owner : ChatSender.scanner,
              kind: switch (m.kind) {
                MessageKind.voice => ChatMessageKind.voice,
                MessageKind.image => ChatMessageKind.photo,
                MessageKind.video => ChatMessageKind.video,
                MessageKind.text => ChatMessageKind.text,
              },
              timeLabel: _formatTime(m.createdAt),
              text: m.text,
              voiceDuration: m.kind == MessageKind.voice ? _formatDuration(m.durationSeconds) : '',
              audioUrl: m.audioUrl,
              mediaUrl: m.mediaUrl,
              createdAt: m.createdAt,
            ),
          )
          .toList();

      // A confirmed message that matches a pending one is the same message
      // coming back off the listener — drop the optimistic copy so it
      // isn't rendered twice. Text messages match on their text; a voice
      // message has none, so it matches on its (rounded) duration instead
      // — two different recordings of the exact same length sent by the
      // same person in the same second would be a rare false match.
      // A photo/video matches on its download URL, known once it uploaded.
      _pending.removeWhere(
        (p) =>
            p.status == ChatMessageStatus.sending &&
            confirmed.any(
              (c) =>
                  c.sender == p.sender &&
                  c.kind == p.kind &&
                  switch (p.kind) {
                    ChatMessageKind.voice => c.voiceDuration == p.voiceDuration,
                    ChatMessageKind.photo || ChatMessageKind.video => p.mediaUrl != null && c.mediaUrl == p.mediaUrl,
                    ChatMessageKind.text => c.text == p.text,
                  },
            ),
      );

      final grew = confirmed.length > _lastConfirmedCount;
      _lastConfirmedCount = confirmed.length;
      _rebuild(confirmed);

      if (grew) {
        if (isAwayFromLatest.value) {
          hasUnseenIncoming.value = true;
        } else {
          _scrollToLatest();
        }
      }
    });
    _metaSub = _conversationService.watchConversation(thread.conversationId).listen((summary) {
      if (summary != null) isResolved.value = summary.resolved;
    });
  }

  @override
  void onReady() {
    super.onReady();
    // Opening a thread reads it — clear this viewer's own unread flag.
    // The two sides are tracked separately, so the owner reading a thread
    // must not clear it for the scanner or vice versa.
    if (thread.unreadCount > 0) {
      if (thread.viewerRole == ThreadViewerRole.owner) {
        _conversationService.markReadByOwner(thread.conversationId);
      } else {
        _conversationService.markReadByScanner(thread.conversationId);
      }
    }
    // Open on the newest messages, without an animated scroll the reader
    // would see as a jump.
    _scrollToLatest(animated: false);
  }

  List<ChatMessageModel> _confirmed = const [];

  void _rebuild(List<ChatMessageModel> confirmed) {
    _confirmed = confirmed;
    messages.assignAll([...confirmed, ..._pending]);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    // The list is reversed-in-spirit (newest at the bottom), so "at the
    // latest" means at the maximum extent.
    final distanceFromBottom =
        scrollController.position.maxScrollExtent - scrollController.offset;
    final away = distanceFromBottom > 140;
    isAwayFromLatest.value = away;
    if (!away) hasUnseenIncoming.value = false;
  }

  void _scrollToLatest({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_closed || !scrollController.hasClients) return;
      final target = scrollController.position.maxScrollExtent;
      if (animated) {
        scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(target);
      }
    });
  }

  /// Tapping the "new message" pill.
  void jumpToLatest() {
    hasUnseenIncoming.value = false;
    _scrollToLatest();
  }

  /// The message is rendered immediately and the Firestore write happens
  /// behind it — the sender never waits on the network to see their own
  /// message. A failure marks that bubble as failed and keeps the text so
  /// it can be retried, rather than dropping it on the floor.
  void sendText() {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    textController.clear();
    _drafts.remove(thread.conversationId);
    _dispatch(text);
  }

  void _dispatch(String text) {
    final optimistic = ChatMessageModel(
      sender: thread.viewerRole == ThreadViewerRole.owner ? ChatSender.owner : ChatSender.scanner,
      kind: ChatMessageKind.text,
      timeLabel: _formatTime(DateTime.now()),
      text: text,
      status: ChatMessageStatus.sending,
      createdAt: DateTime.now(),
      localId: '${DateTime.now().microsecondsSinceEpoch}',
    );
    _pending.add(optimistic);
    _rebuild(_confirmed);
    _scrollToLatest();

    final write = thread.viewerRole == ThreadViewerRole.owner
        ? _conversationService.sendOwnerReply(conversationId: thread.conversationId, text: text)
        : _conversationService.sendAuthenticatedScannerReply(
            conversationId: thread.conversationId,
            text: text,
          );

    write.catchError((_) {
      final i = _pending.indexWhere((m) => m.localId == optimistic.localId);
      if (i != -1) {
        _pending[i] = _pending[i].copyWith(status: ChatMessageStatus.failed);
        _rebuild(_confirmed);
      }
    });
  }

  /// Re-sends a message whose write failed, from its own bubble.
  void retry(ChatMessageModel message) {
    _pending.removeWhere((m) => m.localId == message.localId);
    _rebuild(_confirmed);
    final path = message.localPath;
    if ((message.kind == ChatMessageKind.photo || message.kind == ChatMessageKind.video) && path != null) {
      _queueMedia(message.kind, path);
    } else {
      _dispatch(message.text);
    }
  }

  /// Starts capturing a voice message. Requests microphone permission
  /// through the `record` package itself, which shows the OS prompt the
  /// first time and just checks the granted state after that.
  Future<void> startVoiceRecording() async {
    if (isRecording.value) return;
    try {
      if (!await _recorder.hasPermission()) {
        AppSnackbar.show(
          'Microphone access needed',
          'Allow microphone access in your device Settings to send voice messages.',
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _recordingPath = path;
      recordingSeconds.value = 0;
      isRecording.value = true;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) => recordingSeconds.value++);
    } catch (_) {
      isRecording.value = false;
      AppSnackbar.show('Could not start recording', 'Please try again.');
    }
  }

  /// Discards the in-progress recording without sending it.
  Future<void> cancelVoiceRecording() async {
    if (!isRecording.value) return;
    _recordTimer?.cancel();
    isRecording.value = false;
    try {
      await _recorder.cancel();
    } catch (_) {
      // Best-effort — the temp file cleanup below still runs.
    }
    await _deleteLocalRecording(_recordingPath);
    _recordingPath = null;
  }

  /// Stops recording and sends what was captured so far. A recording
  /// shorter than one second is treated as an accidental tap and discarded
  /// rather than sent as a near-silent clip.
  Future<void> sendVoiceRecording() async {
    if (!isRecording.value) return;
    _recordTimer?.cancel();
    final durationSeconds = recordingSeconds.value;
    isRecording.value = false;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _recordingPath;
    }
    _recordingPath = null;

    if (path == null || durationSeconds < 1) {
      await _deleteLocalRecording(path);
      return;
    }
    _dispatchVoice(path, durationSeconds);
  }

  void _dispatchVoice(String localPath, int durationSeconds) {
    final optimistic = ChatMessageModel(
      sender: thread.viewerRole == ThreadViewerRole.owner ? ChatSender.owner : ChatSender.scanner,
      kind: ChatMessageKind.voice,
      timeLabel: _formatTime(DateTime.now()),
      voiceDuration: _formatDuration(durationSeconds),
      status: ChatMessageStatus.sending,
      createdAt: DateTime.now(),
      localId: '${DateTime.now().microsecondsSinceEpoch}',
    );
    _pending.add(optimistic);
    _rebuild(_confirmed);
    _scrollToLatest();

    final write = thread.viewerRole == ThreadViewerRole.owner
        ? _conversationService.sendOwnerVoiceMessage(
            conversationId: thread.conversationId,
            localFilePath: localPath,
            durationSeconds: durationSeconds,
          )
        : _conversationService.sendAuthenticatedScannerVoiceMessage(
            conversationId: thread.conversationId,
            localFilePath: localPath,
            durationSeconds: durationSeconds,
          );

    write
        .then((_) => _deleteLocalRecording(localPath))
        .catchError((_) {
          final i = _pending.indexWhere((m) => m.localId == optimistic.localId);
          if (i != -1) {
            _pending[i] = _pending[i].copyWith(status: ChatMessageStatus.failed);
            _rebuild(_confirmed);
          }
        });
  }

  static Future<void> _deleteLocalRecording(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Leftover temp files are harmless — never let cleanup surface an error.
    }
  }

  static String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  final _picker = ImagePicker();

  /// Photos and videos upload one at a time, in the order they were taken.
  Future<void> _uploadChain = Future.value();

  /// Camera photo or video, chosen from a small sheet.
  Future<void> attachMedia() async {
    final choice = await Get.bottomSheet<ChatMessageKind>(
      const MediaSourceSheet(),
      backgroundColor: Colors.transparent,
    );
    if (choice == null) return;
    try {
      if (choice == ChatMessageKind.photo) {
        final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
        if (photo != null) _queueMedia(ChatMessageKind.photo, photo.path);
      } else {
        final video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 1));
        if (video != null) _queueMedia(ChatMessageKind.video, video.path);
      }
    } catch (_) {
      AppSnackbar.show('Camera unavailable', 'Allow camera access in your device Settings and try again.');
    }
  }

  void _queueMedia(ChatMessageKind kind, String localPath) {
    final localId = '${DateTime.now().microsecondsSinceEpoch}';
    _pending.add(ChatMessageModel(
      sender: thread.viewerRole == ThreadViewerRole.owner ? ChatSender.owner : ChatSender.scanner,
      kind: kind,
      timeLabel: _formatTime(DateTime.now()),
      localPath: localPath,
      uploadProgress: 0,
      status: ChatMessageStatus.sending,
      createdAt: DateTime.now(),
      localId: localId,
    ));
    _rebuild(_confirmed);
    _scrollToLatest();
    _uploadChain = _uploadChain.then((_) => _uploadMedia(localId, kind, localPath));
  }

  void _updatePending(String localId, ChatMessageModel Function(ChatMessageModel) change) {
    if (_closed) return;
    final i = _pending.indexWhere((m) => m.localId == localId);
    if (i == -1) return;
    _pending[i] = change(_pending[i]);
    _rebuild(_confirmed);
  }

  Future<void> _uploadMedia(String localId, ChatMessageKind kind, String localPath) async {
    try {
      var path = localPath;
      if (kind == ChatMessageKind.video) path = await compressVideo(localPath);
      final url = await _conversationService.sendMediaMessage(
        conversationId: thread.conversationId,
        asOwner: thread.viewerRole == ThreadViewerRole.owner,
        kind: kind == ChatMessageKind.video ? MessageKind.video : MessageKind.image,
        localFilePath: path,
        onProgress: (p) => _updatePending(localId, (m) => m.copyWith(uploadProgress: p)),
      );
      _updatePending(localId, (m) => m.copyWith(mediaUrl: url, clearProgress: true));
    } catch (_) {
      _updatePending(localId, (m) => m.copyWith(status: ChatMessageStatus.failed, clearProgress: true));
    }
  }

  // ---------------------------------------------------------------------
  // Disabled for this module (see chat_thread_view.dart's _Header) — kept
  // implemented, not deleted, so in-app calls can be re-enabled by
  // uncommenting their UI entry points. Do not remove.
  // ---------------------------------------------------------------------

  // TODO(FR-05.4): wire to agora_rtc_engine for in-app audio/video calls.
  void startCall({required bool video}) {
    AppSnackbar.show('Coming soon', '${video ? 'Video' : 'Audio'} calls are not available yet.');
  }

  void markResolved() {
    isResolved.value = true;
    _conversationService.setResolved(conversationId: thread.conversationId, resolved: true);
  }

  void markNotResolved() {
    isResolved.value = false;
    _conversationService.setResolved(conversationId: thread.conversationId, resolved: false);
  }

  static String _formatTime(DateTime? at) {
    if (at == null) return 'Now';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final period = at.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void onClose() {
    _closed = true;
    final draft = textController.text.trim();
    if (draft.isEmpty) {
      _drafts.remove(thread.conversationId);
    } else {
      _drafts[thread.conversationId] = draft;
    }
    _messagesSub?.cancel();
    _metaSub?.cancel();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    textController.dispose();
    // Navigating away mid-recording must not leave the mic open or an
    // orphaned temp file behind.
    _recordTimer?.cancel();
    if (isRecording.value) _recorder.cancel();
    _deleteLocalRecording(_recordingPath);
    _recorder.dispose();
    super.onClose();
  }
}

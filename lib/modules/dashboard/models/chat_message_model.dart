/// FR-05: a single message inside a vehicle's chat thread with one scanner.
enum ChatSender { owner, scanner }

enum ChatMessageKind { text, voice, photo, video }

/// How far an *outgoing* message has got.
///
/// Stops at [sent] on purpose. A message document carries `sender`, `text`
/// and `createdAt` and nothing else — there is no per-recipient delivery
/// or read field anywhere in the schema, so "delivered" and "read" cannot
/// be known and are not represented. Adding them would mean showing the
/// sender a receipt the backend never actually confirmed.
enum ChatMessageStatus {
  /// Rendered optimistically; the Firestore write is still in flight.
  sending,

  /// The write completed and the message came back on the listener.
  sent,

  /// The write threw. The bubble offers a retry; the text is not lost.
  failed,
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.sender,
    required this.kind,
    required this.timeLabel,
    this.text = '',
    this.voiceDuration = '',
    this.audioUrl,
    this.mediaUrl,
    this.localPath,
    this.uploadProgress,
    this.status = ChatMessageStatus.sent,
    this.createdAt,
    this.localId,
  });

  final ChatSender sender;
  final ChatMessageKind kind;
  final String timeLabel;
  final String text;
  final String voiceDuration;

  /// Firebase Storage download URL for a [ChatMessageKind.voice] message.
  /// Null for an optimistic voice message still uploading.
  final String? audioUrl;

  /// Download URL of a [ChatMessageKind.photo] or [ChatMessageKind.video].
  final String? mediaUrl;

  /// The file on this device while a photo/video this device sent uploads.
  final String? localPath;

  /// 0-1 while this device's photo/video uploads; null otherwise.
  final double? uploadProgress;

  /// Only meaningful for messages this device sent.
  final ChatMessageStatus status;

  /// Null for a pending message until the server timestamp resolves —
  /// which is also why date separators treat a null as "today".
  final DateTime? createdAt;

  /// Set only on optimistic messages, so a retry can find and replace the
  /// right one.
  final String? localId;

  ChatMessageModel copyWith({
    ChatMessageStatus? status,
    String? audioUrl,
    String? mediaUrl,
    double? uploadProgress,
    bool clearProgress = false,
  }) =>
      ChatMessageModel(
        sender: sender,
        kind: kind,
        timeLabel: timeLabel,
        text: text,
        voiceDuration: voiceDuration,
        audioUrl: audioUrl ?? this.audioUrl,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        localPath: localPath,
        uploadProgress: clearProgress ? null : uploadProgress ?? this.uploadProgress,
        status: status ?? this.status,
        createdAt: createdAt,
        localId: localId,
      );
}

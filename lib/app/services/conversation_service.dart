import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum MessageSender { owner, scanner }

/// Mirrors [ChatMessageKind] at the service layer — kept separate so this
/// file never has to import a UI model. A message document with no `kind`
/// field (every one written before voice messages existed) reads as text.
enum MessageKind { text, voice, image, video }

MessageKind _kindFrom(Object? value) => switch (value) {
      'voice' => MessageKind.voice,
      'image' => MessageKind.image,
      'video' => MessageKind.video,
      _ => MessageKind.text,
    };

/// What the conversation list shows for a message with no text.
String previewFor(MessageKind kind, String text) => switch (kind) {
      MessageKind.voice => '🎤 Voice message',
      MessageKind.image => '📷 Photo',
      MessageKind.video => '🎥 Video',
      MessageKind.text => text,
    };

/// A vehicle's QR sticker is scanned by many different people — each one
/// must get their own private thread with the owner, not walk into a
/// stranger's conversation. [conversationId] is the composite key
/// (`{vehicleId}_{scannerId}`) that scopes a thread to one vehicle *and*
/// one scanner; see [conversationIdFor].
String conversationIdFor(String vehicleId, String scannerId) => '${vehicleId}_$scannerId';

/// One scanner's conversation with a vehicle's owner, as shown in the
/// resident's Inbox (FR-05/FR-06) and on the public Scan Contact Page (FR-04).
class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.vehicleId,
    required this.ownerUid,
    required this.scannerName,
    required this.plateNumber,
    required this.colorName,
    required this.resolved,
    required this.unreadForOwner,
    this.unreadForScanner = false,
    this.unreadCountForOwner = 0,
    this.unreadCountForScanner = 0,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    this.scannerUid,
    this.scannerId,
    this.ownerName = '',
  });

  final String conversationId;
  final String vehicleId;
  final String ownerUid;
  final String? scannerId;
  final String scannerName;

  /// The vehicle owner's display name — only populated for conversations
  /// created via [ConversationService.resolveVehicleAndOpenChat] (an
  /// authenticated in-app scan/deep-link). Empty for conversations created
  /// from the anonymous public Scan Contact Page, which never recorded it.
  final String ownerName;
  final String plateNumber;
  final String colorName;
  final bool resolved;
  /// Unread *for the owner* — set when the scanner writes, cleared when
  /// the owner opens the thread.
  final bool unreadForOwner;

  /// The mirror image, for whoever scanned the sticker. Each side has its
  /// own flag: a single shared one would mean the owner reading a thread
  /// also marked it read for the scanner.
  final bool unreadForScanner;

  /// How many messages the owner has not read yet. Incremented on each
  /// scanner message, zeroed when the owner opens the thread.
  ///
  /// The booleans above are kept in sync rather than replaced: documents
  /// written before these counters existed have no count field, and the
  /// public web page and security rules still read the flags.
  final int unreadCountForOwner;

  /// The scanner's side of [unreadCountForOwner].
  final int unreadCountForScanner;

  final String lastMessagePreview;
  final DateTime? lastMessageAt;

  /// Set once this conversation's anonymous scanner registers an app
  /// account and [ConversationService.linkScannerIdentity] matches it back
  /// (FR-09) — lets that conversation show up in the app under "Sent",
  /// alongside the resident's own "cars I own" inbox.
  final String? scannerUid;
}

/// What [ConversationService.resolveVehicleAndOpenChat] hands back — just
/// enough to build a chat screen immediately, without waiting on a
/// Firestore stream round-trip first.
class ResolvedChat {
  const ResolvedChat({
    required this.conversationId,
    required this.ownerName,
    required this.plateNumber,
    required this.colorName,
    required this.resolved,
  });

  final String conversationId;
  final String ownerName;
  final String plateNumber;
  final String colorName;
  final bool resolved;
}

/// Thrown by [ConversationService.resolveVehicleAndOpenChat] with a
/// message that's already safe to show the resident directly (invalid QR,
/// vehicle removed, scanning your own car, not signed in).
class ResolveVehicleException implements Exception {
  const ResolveVehicleException(this.message);
  final String message;
}

class ConversationMessage {
  const ConversationMessage({
    required this.sender,
    required this.text,
    required this.createdAt,
    this.kind = MessageKind.text,
    this.audioUrl,
    this.mediaUrl,
    this.durationSeconds = 0,
  });

  final MessageSender sender;
  final String text;
  final DateTime? createdAt;
  final MessageKind kind;

  /// Firebase Storage download URL — only set when [kind] is
  /// [MessageKind.voice].
  final String? audioUrl;

  /// Download URL of a photo or video message.
  final String? mediaUrl;

  /// Recording length, rounded to whole seconds — only meaningful when
  /// [kind] is [MessageKind.voice].
  final int durationSeconds;
}

/// Where a scan-page visitor was, if they chose to share it.
class ScanLocation {
  const ScanLocation({required this.lat, required this.lng, this.accuracy});

  final double lat;
  final double lng;
  final double? accuracy;

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'accuracy': ?accuracy};
}

/// A photo, video or voice note a web scanner has already uploaded, ready
/// to attach to [ConversationService.postScannerMessage].
class ScannerAttachment {
  const ScannerAttachment({required this.kind, required this.storagePath, this.durationSeconds = 0});

  final MessageKind kind;

  /// Must sit inside this conversation's own Storage folder — the server
  /// rejects anything else.
  final String storagePath;
  final int durationSeconds;

  Map<String, dynamic> toMap() => {'kind': kind.name, 'path': storagePath, 'durationSeconds': durationSeconds};
}

/// Wraps the Firestore `conversations` collection — the messaging thread a
/// QR scanner opens with a vehicle's owner (FR-04/FR-05/FR-06/FR-07).
/// Every method below is keyed by [conversationId], never by [String]
/// vehicleId alone, so two different people scanning the same sticker never
/// end up in the same thread.
abstract class ConversationService {
  /// The resident's Inbox: every conversation attached to a vehicle they
  /// own — one entry per vehicle *per scanner* who has messaged about it.
  Stream<List<ConversationSummary>> watchOwnerConversations(String ownerUid);

  Stream<ConversationSummary?> watchConversation(String conversationId);

  Stream<List<ConversationMessage>> watchMessages(String conversationId);

  /// "Sent" section of the app Inbox (FR-09): conversations this signed-in
  /// resident started as an anonymous scanner before/without owning the
  /// vehicle, once [linkScannerIdentity] has tied their `scannerUid` in.
  Stream<List<ConversationSummary>> watchScannerConversations(String scannerUid);

  /// Called once, right after a resident signs in, with the `scannerId`
  /// pulled off a Branch handoff link (see [DeepLinkService]). Finds every
  /// conversation that anonymous browser token took part in and stamps
  /// them with this resident's uid, so they surface in the app's "Sent"
  /// inbox from then on. Safe to call repeatedly — a no-op once already
  /// linked.
  Future<void> linkScannerIdentity({required String scannerId, required String uid});

  /// The authenticated in-app path (FR-09/QR chat spec): resolves
  /// [vehicleId] to its owner and returns the deterministic conversation
  /// for (this signed-in caller, that vehicle) — creating it server-side
  /// on first contact, or just returning its id if it already exists.
  /// Never trust a client-supplied owner identity; the backend resolves
  /// it. Throws [ResolveVehicleException] with a display-ready message on
  /// failure (invalid vehicle, scanning your own car, not signed in).
  /// [anonymousScannerId], when present, is the random id this person's
  /// browser used on the public Scan Contact Page before they had an
  /// account. Passing it lets the backend adopt that existing conversation
  /// — with its history — instead of opening a fresh empty one (FR-09).
  Future<ResolvedChat> resolveVehicleAndOpenChat({
    required String vehicleId,
    String? anonymousScannerId,
  });

  /// Uploads one of a web scanner's attachments into their conversation's
  /// Storage folder and returns its path for [postScannerMessage].
  Future<String> uploadScannerAttachment({
    required String vehicleId,
    required String scannerId,
    required MessageKind kind,
    required List<int> bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  });

  /// Called from the public Scan Contact Page, through the
  /// postScannerMessage Cloud Function — the only way that page can send.
  /// The server looks the owner up itself, creates this scanner's
  /// conversation on first contact, and appends the text and any
  /// [attachments]. [scannerId] identifies this browser (persisted by the
  /// scan page), so a different scanner gets a different conversation.
  Future<void> postScannerMessage({
    required String vehicleId,
    required String scannerId,
    required String scannerName,
    required String text,
    List<ScannerAttachment> attachments,
    ScanLocation? location,
  });

  /// Records a scan-page visit in the server's safety log.
  Future<void> logScanVisit({required String vehicleId, required String scannerId, ScanLocation? location});

  /// Called from the resident's Chat screen when they're the vehicle's
  /// owner — just appends a reply.
  Future<void> sendOwnerReply({required String conversationId, required String text});

  /// Called from the resident's Chat screen when they're the *scanner*
  /// side of an already-created conversation (an authenticated in-app
  /// scan/deep-link, see [resolveVehicleAndOpenChat]) — appends their
  /// message as `sender: scanner`, same shape [sendScannerMessage] writes
  /// for the anonymous web case, just for a signed-in participant instead.
  Future<void> sendAuthenticatedScannerReply({required String conversationId, required String text});

  /// Uploads the recorded audio at [localFilePath] to Storage and appends
  /// it as an owner voice message — the voice-message counterpart of
  /// [sendOwnerReply].
  Future<void> sendOwnerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  });

  /// The voice-message counterpart of [sendAuthenticatedScannerReply].
  Future<void> sendAuthenticatedScannerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  });

  /// Uploads a camera photo or video ([kind] is image or video) and appends
  /// it as a message from the owner ([asOwner]) or the signed-in scanner.
  /// Returns its download URL.
  Future<String> sendMediaMessage({
    required String conversationId,
    required bool asOwner,
    required MessageKind kind,
    required String localFilePath,
    void Function(double progress)? onProgress,
  });

  /// Either side can toggle this — the scanner from the web page (FR-07.2),
  /// the resident from the Chat screen.
  Future<void> setResolved({required String conversationId, required bool resolved});

  Future<void> markReadByOwner(String conversationId);

  /// The scanner's side of [markReadByOwner] — called when whoever scanned
  /// the sticker actually opens the thread, in the app or on the public
  /// Scan Contact Page.
  Future<void> markReadByScanner(String conversationId);
}

class FirebaseConversationService implements ConversationService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations => _firestore.collection('conversations');

  @override
  Stream<List<ConversationSummary>> watchOwnerConversations(String ownerUid) {
    return _conversations
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _toSummary(d.id, d.data())).toList());
  }

  @override
  Stream<List<ConversationSummary>> watchScannerConversations(String scannerUid) {
    return _conversations
        .where('scannerUid', isEqualTo: scannerUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _toSummary(d.id, d.data())).toList());
  }

  @override
  Future<void> linkScannerIdentity({required String scannerId, required String uid}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('linkScannerIdentity');
    await callable.call({'scannerId': scannerId, 'uid': uid});
  }

  @override
  Future<ResolvedChat> resolveVehicleAndOpenChat({
    required String vehicleId,
    String? anonymousScannerId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('resolveVehicleAndOpenChat');
      final result = await callable.call({
        'vehicleId': vehicleId,
        if (anonymousScannerId != null && anonymousScannerId.isNotEmpty)
          'scannerId': anonymousScannerId,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return ResolvedChat(
        conversationId: data['conversationId'] as String,
        ownerName: data['ownerName'] as String? ?? 'A MoveMe resident',
        plateNumber: data['plateNumber'] as String? ?? '',
        colorName: data['colorName'] as String? ?? '',
        resolved: data['resolved'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      throw ResolveVehicleException(e.message ?? "Couldn't open this chat. Please try again.");
    }
  }

  @override
  Stream<ConversationSummary?> watchConversation(String conversationId) {
    return _conversations.doc(conversationId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : _toSummary(doc.id, data);
    });
  }

  @override
  Stream<List<ConversationMessage>> watchMessages(String conversationId) {
    return _conversations.doc(conversationId).collection('messages').orderBy('createdAt').snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = d.data();
        return ConversationMessage(
          sender: data['sender'] == 'owner' ? MessageSender.owner : MessageSender.scanner,
          text: data['text'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          kind: _kindFrom(data['kind']),
          audioUrl: data['audioUrl'] as String?,
          mediaUrl: data['mediaUrl'] as String?,
          durationSeconds: data['durationSeconds'] as int? ?? 0,
        );
      }).toList(),
    );
  }

  @override
  Future<String> uploadScannerAttachment({
    required String vehicleId,
    required String scannerId,
    required MessageKind kind,
    required List<int> bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final conversationId = conversationIdFor(vehicleId, scannerId);
    final ext = switch (kind) {
      MessageKind.voice => contentType.contains('webm') ? 'webm' : 'm4a',
      MessageKind.video => contentType.contains('quicktime') ? 'mov' : 'mp4',
      _ => 'jpg',
    };
    final path = 'conversations/$conversationId/scanner/${DateTime.now().microsecondsSinceEpoch}.$ext';
    final upload = FirebaseStorage.instance.ref(path).putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: contentType),
        );
    final sub = upload.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) onProgress?.call(snap.bytesTransferred / snap.totalBytes);
    });
    try {
      await upload;
    } finally {
      await sub.cancel();
    }
    return path;
  }

  @override
  Future<void> postScannerMessage({
    required String vehicleId,
    required String scannerId,
    required String scannerName,
    required String text,
    List<ScannerAttachment> attachments = const [],
    ScanLocation? location,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('postScannerMessage').call({
      'vehicleId': vehicleId,
      'scannerId': scannerId,
      'scannerName': scannerName,
      'text': text,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'location': ?location?.toMap(),
    });
  }

  @override
  Future<void> logScanVisit({required String vehicleId, required String scannerId, ScanLocation? location}) async {
    await FirebaseFunctions.instance.httpsCallable('logActivity').call({
      'vehicleId': vehicleId,
      'scannerId': scannerId,
      'location': ?location?.toMap(),
    });
  }

  @override
  Future<void> sendOwnerReply({required String conversationId, required String text}) async {
    final docRef = _conversations.doc(conversationId);
    await docRef.set({
      'lastMessagePreview': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForOwner': false,
      'unreadForScanner': true,
      'unreadCountForOwner': 0,
      'unreadCountForScanner': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await docRef.collection('messages').add({
      'sender': 'owner',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendAuthenticatedScannerReply({required String conversationId, required String text}) async {
    final docRef = _conversations.doc(conversationId);
    await docRef.set({
      'lastMessagePreview': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForOwner': true,
      'unreadForScanner': false,
      'unreadCountForOwner': FieldValue.increment(1),
      'unreadCountForScanner': 0,
    }, SetOptions(merge: true));
    await docRef.collection('messages').add({
      'sender': 'scanner',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static const _ownerSentPatch = {
    'unreadForOwner': false,
    'unreadForScanner': true,
    'unreadCountForOwner': 0,
  };
  static const _scannerSentPatch = {
    'unreadForOwner': true,
    'unreadForScanner': false,
    'unreadCountForScanner': 0,
  };

  /// Uploads a voice note, photo or video into the conversation's own
  /// Storage folder and appends it as a message. Returns its download URL.
  Future<String> _sendFileMessage({
    required String conversationId,
    required bool asOwner,
    required MessageKind kind,
    required String localFilePath,
    int durationSeconds = 0,
    void Function(double progress)? onProgress,
  }) async {
    final (folder, ext, contentType) = switch (kind) {
      MessageKind.voice => ('voice', 'm4a', 'audio/mp4'),
      MessageKind.video => ('video', 'mp4', 'video/mp4'),
      _ => ('image', 'jpg', 'image/jpeg'),
    };
    final ref = FirebaseStorage.instance.ref(
      'conversations/$conversationId/$folder/${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    final upload = ref.putFile(File(localFilePath), SettableMetadata(contentType: contentType));
    final sub = upload.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) onProgress?.call(snap.bytesTransferred / snap.totalBytes);
    });
    try {
      await upload;
    } finally {
      await sub.cancel();
    }
    final url = await ref.getDownloadURL();

    final docRef = _conversations.doc(conversationId);
    await docRef.set({
      'lastMessagePreview': previewFor(kind, ''),
      'lastMessageAt': FieldValue.serverTimestamp(),
      ...(asOwner ? _ownerSentPatch : _scannerSentPatch),
      asOwner ? 'unreadCountForScanner' : 'unreadCountForOwner': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await docRef.collection('messages').add({
      'sender': asOwner ? 'owner' : 'scanner',
      'kind': kind.name,
      if (kind == MessageKind.voice) 'audioUrl': url else 'mediaUrl': url,
      if (kind == MessageKind.voice) 'durationSeconds': durationSeconds,
      'text': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return url;
  }

  @override
  Future<String> sendMediaMessage({
    required String conversationId,
    required bool asOwner,
    required MessageKind kind,
    required String localFilePath,
    void Function(double progress)? onProgress,
  }) {
    return _sendFileMessage(
      conversationId: conversationId,
      asOwner: asOwner,
      kind: kind,
      localFilePath: localFilePath,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> sendOwnerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    await _sendFileMessage(
      conversationId: conversationId,
      asOwner: true,
      kind: MessageKind.voice,
      localFilePath: localFilePath,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> sendAuthenticatedScannerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    await _sendFileMessage(
      conversationId: conversationId,
      asOwner: false,
      kind: MessageKind.voice,
      localFilePath: localFilePath,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> setResolved({required String conversationId, required bool resolved}) {
    return _conversations.doc(conversationId).set({'resolved': resolved}, SetOptions(merge: true));
  }

  @override
  Future<void> markReadByOwner(String conversationId) {
    return _conversations.doc(conversationId).set({
      'unreadForOwner': false,
      'unreadCountForOwner': 0,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> markReadByScanner(String conversationId) {
    return _conversations.doc(conversationId).set({
      'unreadForScanner': false,
      'unreadCountForScanner': 0,
    }, SetOptions(merge: true));
  }

  /// A conversation last written before the counters existed has only the
  /// boolean. Fall back to it so those threads still show "1" rather than
  /// silently losing their unread badge.
  static int _unreadCount(Map<String, dynamic> data, String countKey, String flagKey) {
    final count = data[countKey];
    if (count is int) return count < 0 ? 0 : count;
    return (data[flagKey] as bool? ?? false) ? 1 : 0;
  }

  ConversationSummary _toSummary(String id, Map<String, dynamic> data) {
    return ConversationSummary(
      conversationId: id,
      vehicleId: data['vehicleId'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      scannerName: data['scannerName'] as String? ?? 'Anonymous',
      plateNumber: data['plateNumber'] as String? ?? '',
      colorName: data['colorName'] as String? ?? '',
      resolved: data['resolved'] as bool? ?? false,
      unreadForOwner: data['unreadForOwner'] as bool? ?? false,
      // Absent on conversations created before this field existed, which
      // correctly reads as "nothing unread" rather than a false badge.
      unreadForScanner: data['unreadForScanner'] as bool? ?? false,
      unreadCountForOwner: _unreadCount(data, 'unreadCountForOwner', 'unreadForOwner'),
      unreadCountForScanner: _unreadCount(data, 'unreadCountForScanner', 'unreadForScanner'),
      lastMessagePreview: data['lastMessagePreview'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      scannerUid: data['scannerUid'] as String?,
      scannerId: data['scannerId'] as String?,
      ownerName: data['ownerName'] as String? ?? '',
    );
  }
}

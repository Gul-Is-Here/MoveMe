import 'dart:async';

import 'package:parktag_app/app/services/conversation_service.dart';

class FakeConversationService implements ConversationService {
  FakeConversationService({this.publicVehicleLookup});

  /// How [postScannerMessage] finds a vehicle's owner, as the server does.
  final Future<Map<String, dynamic>?> Function(String vehicleId)? publicVehicleLookup;

  /// Paths handed out by [uploadScannerAttachment].
  final List<String> uploadedScannerPaths = [];

  /// Set to make [uploadScannerAttachment] fail, to simulate a bad network.
  bool failUploads = false;

  final Map<String, ConversationSummary> _summaries = {};
  final Map<String, List<ConversationMessage>> _messages = {};

  final _summariesController = StreamController<Map<String, ConversationSummary>>.broadcast();
  final _messagesController = StreamController<Map<String, List<ConversationMessage>>>.broadcast();

  void _emit() {
    _summariesController.add(Map.of(_summaries));
    _messagesController.add(Map.of(_messages));
  }

  /// Test helper — seeds a conversation directly, bypassing sendScannerMessage.
  /// Claims an adopted anonymous conversation for a signed-in account.
  static ConversationSummary _withScannerUid(ConversationSummary s, String uid) {
    return ConversationSummary(
      conversationId: s.conversationId,
      vehicleId: s.vehicleId,
      ownerUid: s.ownerUid,
      ownerName: s.ownerName,
      scannerId: s.scannerId,
      scannerUid: uid,
      scannerName: s.scannerName,
      plateNumber: s.plateNumber,
      colorName: s.colorName,
      resolved: s.resolved,
      unreadForOwner: s.unreadForOwner,
      unreadForScanner: s.unreadForScanner,
      unreadCountForOwner: s.unreadCountForOwner,
      unreadCountForScanner: s.unreadCountForScanner,
      lastMessagePreview: s.lastMessagePreview,
      lastMessageAt: s.lastMessageAt,
    );
  }

  /// Rebuilds [summary] with explicit unread counters, keeping the legacy
  /// booleans consistent with them the way the real service does.
  static ConversationSummary _withCounts(
    ConversationSummary summary, {
    required int owner,
    required int scanner,
  }) {
    return ConversationSummary(
      conversationId: summary.conversationId,
      vehicleId: summary.vehicleId,
      ownerUid: summary.ownerUid,
      ownerName: summary.ownerName,
      scannerId: summary.scannerId,
      scannerUid: summary.scannerUid,
      scannerName: summary.scannerName,
      plateNumber: summary.plateNumber,
      colorName: summary.colorName,
      resolved: summary.resolved,
      unreadForOwner: owner > 0,
      unreadForScanner: scanner > 0,
      unreadCountForOwner: owner,
      unreadCountForScanner: scanner,
      lastMessagePreview: summary.lastMessagePreview,
      lastMessageAt: summary.lastMessageAt,
    );
  }

  /// The current stored state of one conversation, for asserting on the
  /// unread flags directly.
  ConversationSummary? summaryFor(String conversationId) => _summaries[conversationId];

  void seed(ConversationSummary summary, [List<ConversationMessage> messages = const []]) {
    _summaries[summary.conversationId] = _withCounts(
      summary,
      owner: summary.unreadCountForOwner > 0
          ? summary.unreadCountForOwner
          : (summary.unreadForOwner ? 1 : 0),
      scanner: summary.unreadCountForScanner > 0
          ? summary.unreadCountForScanner
          : (summary.unreadForScanner ? 1 : 0),
    );
    _messages[summary.conversationId] = List.of(messages);
    _emit();
  }

  /// Test seed for [resolveVehicleAndOpenChat] — mirrors what the real
  /// Cloud Function reads server-side from `vehicles/{vehicleId}`.
  final Map<String, ({String ownerUid, String ownerName, String plateNumber, String colorName})> vehicles = {};

  /// Test seed — mirrors `request.auth.uid` inside the real Cloud
  /// Function; the "signed-in caller" [resolveVehicleAndOpenChat] acts as.
  String callerUid = 'test-caller';

  /// Every vehicleId [resolveVehicleAndOpenChat] successfully created a
  /// *new* conversation for (not just returned an existing one) — lets
  /// tests assert duplicate scans don't create duplicate rooms.
  final resolvedNewChats = <String>[];

  @override
  Stream<List<ConversationSummary>> watchOwnerConversations(String ownerUid) async* {
    yield _summaries.values.where((s) => s.ownerUid == ownerUid).toList();
    yield* _summariesController.stream.map((all) => all.values.where((s) => s.ownerUid == ownerUid).toList());
  }

  @override
  Stream<List<ConversationSummary>> watchScannerConversations(String scannerUid) async* {
    yield _summaries.values.where((s) => s.scannerUid == scannerUid).toList();
    yield* _summariesController.stream.map((all) => all.values.where((s) => s.scannerUid == scannerUid).toList());
  }

  @override
  Future<void> linkScannerIdentity({required String scannerId, required String uid}) async {
    for (final entry in _summaries.entries.toList()) {
      final existing = entry.value;
      if (existing.scannerId != scannerId || existing.scannerUid != null) continue;
      _summaries[entry.key] = ConversationSummary(
        conversationId: existing.conversationId,
        vehicleId: existing.vehicleId,
        ownerUid: existing.ownerUid,
        ownerName: existing.ownerName,
        scannerId: existing.scannerId,
        scannerName: existing.scannerName,
        plateNumber: existing.plateNumber,
        colorName: existing.colorName,
        resolved: existing.resolved,
        unreadForOwner: existing.unreadForOwner,
        unreadForScanner: existing.unreadForScanner,
        unreadCountForOwner: existing.unreadCountForOwner,
        unreadCountForScanner: existing.unreadCountForScanner,
        lastMessagePreview: existing.lastMessagePreview,
        lastMessageAt: existing.lastMessageAt,
        scannerUid: uid,
      );
    }
    _emit();
  }

  @override
  Future<ResolvedChat> resolveVehicleAndOpenChat({
    required String vehicleId,
    String? anonymousScannerId,
  }) async {
    final vehicle = vehicles[vehicleId];
    if (vehicle == null) {
      throw const ResolveVehicleException("This QR code doesn't match a MoveMe vehicle.");
    }
    if (vehicle.ownerUid == callerUid) {
      throw const ResolveVehicleException("This is your own vehicle — nothing to message.");
    }

    var conversationId = conversationIdFor(vehicleId, callerUid);

    // Mirrors the Cloud Function: a conversation this browser started
    // anonymously is adopted (history and all) rather than duplicated —
    // unless it already belongs to a different account.
    if (anonymousScannerId != null && anonymousScannerId.isNotEmpty) {
      final anonymousId = conversationIdFor(vehicleId, anonymousScannerId);
      final anonymous = _summaries[anonymousId];
      final claimedBySomeoneElse =
          anonymous?.scannerUid != null && anonymous?.scannerUid != callerUid;
      if (anonymous != null && !claimedBySomeoneElse) {
        conversationId = anonymousId;
        _summaries[anonymousId] = _withScannerUid(anonymous, callerUid);
        _emit();
      }
    }

    final existing = _summaries[conversationId];
    if (existing != null) {
      return ResolvedChat(
        conversationId: conversationId,
        ownerName: existing.ownerName,
        plateNumber: existing.plateNumber,
        colorName: existing.colorName,
        resolved: existing.resolved,
      );
    }

    resolvedNewChats.add(vehicleId);
    _summaries[conversationId] = ConversationSummary(
      conversationId: conversationId,
      vehicleId: vehicleId,
      ownerUid: vehicle.ownerUid,
      ownerName: vehicle.ownerName,
      scannerId: callerUid,
      scannerUid: callerUid,
      scannerName: 'Test Scanner',
      plateNumber: vehicle.plateNumber,
      colorName: vehicle.colorName,
      resolved: false,
      unreadForOwner: false,
      unreadForScanner: false,
      unreadCountForOwner: 0,
      unreadCountForScanner: 0,
      lastMessagePreview: '',
      lastMessageAt: DateTime.now(),
    );
    _emit();

    return ResolvedChat(
      conversationId: conversationId,
      ownerName: vehicle.ownerName,
      plateNumber: vehicle.plateNumber,
      colorName: vehicle.colorName,
      resolved: false,
    );
  }

  @override
  Future<void> sendAuthenticatedScannerReply({required String conversationId, required String text}) async {
    final existing = _summaries[conversationId];
    if (existing != null) {
      _summaries[conversationId] = ConversationSummary(
        conversationId: existing.conversationId,
        vehicleId: existing.vehicleId,
        ownerUid: existing.ownerUid,
        ownerName: existing.ownerName,
        scannerId: existing.scannerId,
        scannerUid: existing.scannerUid,
        scannerName: existing.scannerName,
        plateNumber: existing.plateNumber,
        colorName: existing.colorName,
        resolved: existing.resolved,
        unreadForOwner: true,
        unreadForScanner: false,
        unreadCountForOwner: existing.unreadCountForOwner + 1,
        unreadCountForScanner: 0,
        lastMessagePreview: text,
        lastMessageAt: DateTime.now(),
      );
    }
    _messages.putIfAbsent(conversationId, () => []).add(
      ConversationMessage(sender: MessageSender.scanner, text: text, createdAt: DateTime.now()),
    );
    _emit();
  }

  /// Test count of voice messages sent, keyed by conversation — asserted
  /// on instead of a real Storage upload/download URL.
  final voiceMessagesSent = <String, int>{};

  @override
  Future<void> sendOwnerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    voiceMessagesSent.update(conversationId, (n) => n + 1, ifAbsent: () => 1);
    _messages.putIfAbsent(conversationId, () => []).add(
      ConversationMessage(
        sender: MessageSender.owner,
        text: '',
        createdAt: DateTime.now(),
        kind: MessageKind.voice,
        audioUrl: 'fake://$localFilePath',
        durationSeconds: durationSeconds,
      ),
    );
    _emit();
  }

  @override
  Future<void> sendAuthenticatedScannerVoiceMessage({
    required String conversationId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    voiceMessagesSent.update(conversationId, (n) => n + 1, ifAbsent: () => 1);
    _messages.putIfAbsent(conversationId, () => []).add(
      ConversationMessage(
        sender: MessageSender.scanner,
        text: '',
        createdAt: DateTime.now(),
        kind: MessageKind.voice,
        audioUrl: 'fake://$localFilePath',
        durationSeconds: durationSeconds,
      ),
    );
    _emit();
  }

  @override
  Stream<ConversationSummary?> watchConversation(String conversationId) async* {
    yield _summaries[conversationId];
    yield* _summariesController.stream.map((all) => all[conversationId]);
  }

  @override
  Stream<List<ConversationMessage>> watchMessages(String conversationId) async* {
    yield _messages[conversationId] ?? const [];
    yield* _messagesController.stream.map((all) => all[conversationId] ?? const []);
  }

  /// Test helper: what a scanner's message looks like once the server has
  /// stored it.
  Future<void> simulateScannerMessage({
    required String vehicleId,
    required String scannerId,
    required String ownerUid,
    required String plateNumber,
    required String colorName,
    required String scannerName,
    required String text,
  }) async {
    final conversationId = conversationIdFor(vehicleId, scannerId);
    final existing = _summaries[conversationId];
    _summaries[conversationId] = ConversationSummary(
      conversationId: conversationId,
      vehicleId: vehicleId,
      ownerUid: ownerUid,
      scannerId: scannerId,
      scannerName: scannerName.isEmpty ? 'Anonymous' : scannerName,
      plateNumber: plateNumber,
      colorName: colorName,
      resolved: false,
      unreadForOwner: true,
      unreadForScanner: false,
      unreadCountForOwner: (existing?.unreadCountForOwner ?? 0) + 1,
      unreadCountForScanner: 0,
      lastMessagePreview: text,
      lastMessageAt: DateTime.now(),
    );
    _messages.putIfAbsent(conversationId, () => []).add(
      ConversationMessage(sender: MessageSender.scanner, text: text, createdAt: DateTime.now()),
    );
    _emit();
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
    if (failUploads) throw Exception('Simulated upload failure');
    onProgress?.call(1);
    final path = 'conversations/${conversationIdFor(vehicleId, scannerId)}/scanner/${uploadedScannerPaths.length}';
    uploadedScannerPaths.add(path);
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
    final vehicle = await publicVehicleLookup?.call(vehicleId);
    if (vehicle == null) throw Exception('not-found');
    await simulateScannerMessage(
      vehicleId: vehicleId,
      scannerId: scannerId,
      ownerUid: vehicle['ownerUid'] as String,
      plateNumber: vehicle['plateNumber'] as String? ?? '',
      colorName: vehicle['colorName'] as String? ?? '',
      scannerName: scannerName,
      text: text.isEmpty ? previewFor(attachments.last.kind, '') : text,
    );
    final thread = _messages[conversationIdFor(vehicleId, scannerId)]!;
    if (text.isEmpty) thread.removeLast();
    for (final a in attachments) {
      thread.add(ConversationMessage(
        sender: MessageSender.scanner,
        text: '',
        kind: a.kind,
        audioUrl: a.kind == MessageKind.voice ? 'https://fake/${a.storagePath}' : null,
        mediaUrl: a.kind == MessageKind.voice ? null : 'https://fake/${a.storagePath}',
        durationSeconds: a.durationSeconds,
        createdAt: DateTime.now(),
      ));
    }
    _emit();
  }

  final List<String> sentMediaPaths = [];

  /// Visits recorded by [logScanVisit].
  final List<String> loggedVisits = [];

  @override
  Future<void> logScanVisit({required String vehicleId, required String scannerId, ScanLocation? location}) async {
    loggedVisits.add(vehicleId);
  }

  @override
  Future<String> sendMediaMessage({
    required String conversationId,
    required bool asOwner,
    required MessageKind kind,
    required String localFilePath,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1);
    sentMediaPaths.add(localFilePath);
    final url = 'https://fake/$localFilePath';
    _messages.putIfAbsent(conversationId, () => []).add(ConversationMessage(
      sender: asOwner ? MessageSender.owner : MessageSender.scanner,
      text: '',
      kind: kind,
      mediaUrl: url,
      createdAt: DateTime.now(),
    ));
    _emit();
    return url;
  }

  @override
  Future<void> sendOwnerReply({required String conversationId, required String text}) async {
    final existing = _summaries[conversationId];
    if (existing != null) {
      _summaries[conversationId] = ConversationSummary(
        conversationId: existing.conversationId,
        vehicleId: existing.vehicleId,
        ownerUid: existing.ownerUid,
        ownerName: existing.ownerName,
        scannerId: existing.scannerId,
        scannerUid: existing.scannerUid,
        scannerName: existing.scannerName,
        plateNumber: existing.plateNumber,
        colorName: existing.colorName,
        resolved: existing.resolved,
        unreadForOwner: false,
        unreadForScanner: true,
        unreadCountForOwner: 0,
        unreadCountForScanner: existing.unreadCountForScanner + 1,
        lastMessagePreview: text,
        lastMessageAt: DateTime.now(),
      );
    }
    _messages.putIfAbsent(conversationId, () => []).add(
      ConversationMessage(sender: MessageSender.owner, text: text, createdAt: DateTime.now()),
    );
    _emit();
  }

  @override
  Future<void> setResolved({required String conversationId, required bool resolved}) async {
    final existing = _summaries[conversationId];
    if (existing == null) return;
    _summaries[conversationId] = ConversationSummary(
      conversationId: existing.conversationId,
      vehicleId: existing.vehicleId,
      ownerUid: existing.ownerUid,
      ownerName: existing.ownerName,
      scannerId: existing.scannerId,
      scannerUid: existing.scannerUid,
      scannerName: existing.scannerName,
      plateNumber: existing.plateNumber,
      colorName: existing.colorName,
      resolved: resolved,
      unreadForOwner: existing.unreadForOwner,
      unreadForScanner: existing.unreadForScanner,
      unreadCountForOwner: existing.unreadCountForOwner,
      unreadCountForScanner: existing.unreadCountForScanner,
      lastMessagePreview: existing.lastMessagePreview,
      lastMessageAt: existing.lastMessageAt,
    );
    _emit();
  }

  @override
  Future<void> markReadByOwner(String conversationId) async {
    final existing = _summaries[conversationId];
    if (existing == null) return;
    _summaries[conversationId] = ConversationSummary(
      conversationId: existing.conversationId,
      vehicleId: existing.vehicleId,
      ownerUid: existing.ownerUid,
      ownerName: existing.ownerName,
      scannerId: existing.scannerId,
      scannerUid: existing.scannerUid,
      scannerName: existing.scannerName,
      plateNumber: existing.plateNumber,
      colorName: existing.colorName,
      resolved: existing.resolved,
      unreadForOwner: false,
      unreadForScanner: existing.unreadForScanner,
      unreadCountForOwner: 0,
      unreadCountForScanner: existing.unreadCountForScanner,
      lastMessagePreview: existing.lastMessagePreview,
      lastMessageAt: existing.lastMessageAt,
    );
    _emit();
  }

  @override
  Future<void> markReadByScanner(String conversationId) async {
    final existing = _summaries[conversationId];
    if (existing == null) return;
    _summaries[conversationId] = ConversationSummary(
      conversationId: existing.conversationId,
      vehicleId: existing.vehicleId,
      ownerUid: existing.ownerUid,
      ownerName: existing.ownerName,
      scannerId: existing.scannerId,
      scannerUid: existing.scannerUid,
      scannerName: existing.scannerName,
      plateNumber: existing.plateNumber,
      colorName: existing.colorName,
      resolved: existing.resolved,
      unreadForOwner: existing.unreadForOwner,
      unreadForScanner: false,
      unreadCountForOwner: existing.unreadCountForOwner,
      unreadCountForScanner: 0,
      lastMessagePreview: existing.lastMessagePreview,
      lastMessageAt: existing.lastMessageAt,
    );
    _emit();
  }
}

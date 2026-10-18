import 'package:parktag_app/app/services/deep_link_service.dart';

class FakeDeepLinkService implements DeepLinkService {
  PendingVehicleScan? pendingVehicleScan;
  int disposeCallCount = 0;

  /// Test hook: records every call to [resolveAndOpenChat] instead of
  /// doing real navigation/backend work, so controller tests can assert
  /// what would have been resolved without a live Firebase Functions call.
  final resolvedScans = <PendingVehicleScan>[];

  @override
  Future<void> init() async {}

  @override
  PendingVehicleScan? consumePendingVehicleScan() {
    final payload = pendingVehicleScan;
    pendingVehicleScan = null;
    return payload;
  }

  @override
  Future<void> resolveAndOpenChat(PendingVehicleScan scan) async {
    resolvedScans.add(scan);
  }

  @override
  String scanLinkFor({required String vehicleId, required String scannerId}) {
    return 'https://moveme-da262.web.app/scan/$vehicleId?scannerId=$scannerId';
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

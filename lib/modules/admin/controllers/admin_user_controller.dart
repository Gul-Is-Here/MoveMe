import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/services/admin_service.dart';
import '../../../app/services/order_service.dart';
import '../../../app/utils/app_logger.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../widgets/admin_confirm_dialog.dart';
import 'admin_orders_controller.dart' show normalizePlate;

/// Everything on one customer's account. Registered with `tag: uid`, since
/// several user screens can be open at once (duplicate-plate links).
class AdminUserController extends GetxController {
  AdminUserController({required this.uid, String? focusVehicleId}) {
    focusedVehicleId.value = focusVehicleId;
  }

  final String uid;
  final _adminService = Get.find<AdminService>();
  final _orderService = Get.find<OrderService>();

  final user = Rxn<AdminUser>();
  final isLoading = true.obs;
  final vehicles = <AdminVehicle>[].obs;
  final orders = <StickerOrder>[].obs;
  final allVehicles = <AdminVehicle>[].obs;
  final ownerNames = <String, String>{}.obs;

  /// The vehicle a search or sticker pointed at: opened and highlighted.
  final focusedVehicleId = RxnString();
  final expanded = <String>{}.obs;
  final isUpdatingBlock = false.obs;

  final _subs = <StreamSubscription<Object?>>[];

  static const _paidStatuses = {OrderStatus.confirmed, OrderStatus.printing, OrderStatus.shipped};

  /// Total of the orders whose payment was accepted.
  int get paidTotal => orders.where((o) => _paidStatuses.contains(o.status)).fold(0, (total, o) => total + o.total);

  @override
  void onInit() {
    super.onInit();
    void log(Object e, StackTrace s) => AppLogger.error('AdminUser', e, s);
    _subs
      ..add(
        _adminService
            .watchUser(uid)
            .listen(
              (value) {
                user.value = value;
                isLoading.value = false;
              },
              onError: (Object e, StackTrace s) {
                log(e, s);
                isLoading.value = false;
              },
            ),
      )
      ..add(
        _adminService.watchUserVehicles(uid).listen((list) {
          vehicles.assignAll(list);
          if (list.length == 1) expanded.add(list.first.id);
          final focus = focusedVehicleId.value;
          if (focus != null) expanded.add(focus);
        }, onError: log),
      )
      ..add(_orderService.watchMyOrders(uid).listen(orders.assignAll, onError: log))
      ..add(_adminService.watchAllVehicles().listen(allVehicles.assignAll, onError: log))
      ..add(
        _adminService.watchUsers().listen(
          (list) => ownerNames.assignAll({for (final u in list) u.uid: u.name}),
          onError: log,
        ),
      );
  }

  void focusVehicle(String vehicleId) {
    focusedVehicleId.value = vehicleId;
    expanded.add(vehicleId);
  }

  void toggleExpanded(String vehicleId) =>
      expanded.contains(vehicleId) ? expanded.remove(vehicleId) : expanded.add(vehicleId);

  /// Other vehicles (on this account or others) with the same registration.
  List<AdminVehicle> duplicatesOf(AdminVehicle vehicle) {
    final plate = normalizePlate(vehicle.plateNumber);
    if (plate.isEmpty) return const [];
    return allVehicles.where((v) => v.id != vehicle.id && normalizePlate(v.plateNumber) == plate).toList();
  }

  String ownerName(String ownerUid) {
    final name = ownerNames[ownerUid] ?? '';
    return name.isEmpty ? 'Another account' : name;
  }

  Future<void> call() async {
    final phone = user.value?.phone ?? '';
    if (phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    AppSnackbar.show('$label copied', value);
  }

  Future<void> toggleBlocked() async {
    final current = user.value;
    if (current == null || isUpdatingBlock.value) return;
    final block = !current.blocked;
    final confirmed = await AdminConfirmDialog.show(
      title: block ? 'Block ${current.firstName}?' : 'Unblock ${current.firstName}?',
      message: block
          ? "They'll be signed out and can't sign in. Their vehicles, chats and orders are kept."
          : "They'll be able to sign in again.",
      confirmLabel: block ? 'Block' : 'Unblock',
      danger: block,
    );
    if (!confirmed) return;
    isUpdatingBlock.value = true;
    try {
      await _adminService.setUserBlocked(uid, blocked: block);
      AppSnackbar.show(
        block ? 'User blocked' : 'User unblocked',
        block
            ? '${current.firstName} is signed out on every device within the hour.'
            : '${current.firstName} can sign in again.',
      );
    } catch (e, s) {
      AppLogger.error('AdminUser', e, s);
      AppSnackbar.show("Couldn't update the account", 'Check your connection and try again.');
    } finally {
      isUpdatingBlock.value = false;
    }
  }

  @override
  void onClose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.onClose();
  }
}

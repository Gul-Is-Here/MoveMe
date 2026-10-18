import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/auth_service.dart';
import '../../../app/services/push_notification_service.dart';
import '../../../app/utils/app_logger.dart';
import '../widgets/delete_account_dialog.dart';
import '../../../app/widgets/app_snackbar.dart';

class ProfileController extends GetxController {
  final _authService = Get.find<AuthService>();
  final _pushService = Get.find<PushNotificationService>();

  late final name = TextEditingController();

  final phoneNumber = ''.obs;
  final cnic = ''.obs;
  final isLoading = true.obs;
  final isSaving = false.obs;
  final isDeleting = false.obs;

  /// False if the resident denied (or has not yet granted) notification
  /// permission — surfaced so "no notifications" is visibly explained
  /// rather than looking identical to a delivery failure. FCM still
  /// reports a push as sent to a device with this off; the OS just never
  /// shows it.
  final notificationsPermitted = true.obs;

  /// How the resident wants to be reached: 'app' (push notifications) or
  /// 'web' (the chat link). Null until loaded or if never chosen.
  final communicationPreference = RxnString();
  final isSavingPreference = false.obs;

  @override
  void onReady() {
    super.onReady();
    _loadProfile();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    notificationsPermitted.value = await _pushService.hasPermission();
  }

  /// Re-checks after the resident may have granted it from system
  /// settings (there is no in-app deep link to that screen yet — Android's
  /// notification-settings intent needs the `app_settings` package, which
  /// isn't a project dependency; adding it is a separate, deliberate call).
  Future<void> recheckNotificationPermission() => _checkNotificationPermission();

  Future<void> _loadProfile() async {
    phoneNumber.value = _authService.currentPhone ?? '';

    final uid = _authService.currentUid;
    if (uid != null) {
      final data = await _authService.fetchResidentProfile(uid);
      // This controller (and its `name` TextEditingController) may have
      // been disposed while the fetch above was in flight — e.g. the
      // resident navigated away before their profile finished loading.
      // Writing to a disposed TextEditingController throws, so bail out
      // rather than touching it once we're no longer alive.
      if (isClosed) return;
      if (data != null) {
        name.text = (data['name'] as String?) ?? '';
        cnic.value = (data['cnic'] as String?) ?? '';
        communicationPreference.value = data['communicationPreference'] as String?;
      }
    }

    if (!isClosed) isLoading.value = false;
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      AppSnackbar.show('Name required', 'Please enter your full name.');
      return;
    }
    final uid = _authService.currentUid;
    if (uid == null) return;

    isSaving.value = true;
    await _authService.updateResidentProfile(uid: uid, name: name.text.trim());
    isSaving.value = false;
    AppSnackbar.show('Profile updated', 'Your details have been saved.');
  }

  void openMyOrders() => Get.toNamed(AppRoutes.myOrders);

  Future<void> setCommunicationPreference(String preference) async {
    final uid = _authService.currentUid;
    if (uid == null || isSavingPreference.value || communicationPreference.value == preference) return;
    final previous = communicationPreference.value;
    communicationPreference.value = preference;
    isSavingPreference.value = true;
    try {
      await _authService.saveCommunicationPreference(uid: uid, preference: preference);
      if (preference == 'app') await _pushService.syncToken();
    } catch (e, s) {
      AppLogger.error('Profile', e, s);
      communicationPreference.value = previous;
      AppSnackbar.show("Couldn't save your choice", 'Check your connection and try again.');
    } finally {
      isSavingPreference.value = false;
    }
  }

  Future<void> logout() async {
    await _pushService.unregisterToken();
    await _authService.signOut();
    Get.offAllNamed(AppRoutes.login);
    AppSnackbar.show('Logged out', "You've been signed out of MoveMe.");
  }

  Future<void> deleteAccount() async {
    final confirmed = await Get.dialog<bool>(const DeleteAccountDialog());
    if (confirmed != true) return;

    final uid = _authService.currentUid;
    if (uid == null || isDeleting.value) return;

    isDeleting.value = true;
    try {
      await _authService.deleteResidentAccount(uid);
    } catch (e, stack) {
      AppLogger.error('ProfileController', e, stack);
      if (!isClosed) isDeleting.value = false;
      AppSnackbar.show(
        "Couldn't delete account",
        'Please check your connection and try again. Nothing was removed from your sign-in.',
      );
      return;
    }

    await _authService.signOut();
    Get.offAllNamed(AppRoutes.login);
    AppSnackbar.show('Account deleted', 'Your account and all its data have been permanently removed.');
  }

  @override
  void onClose() {
    name.dispose();
    super.onClose();
  }
}

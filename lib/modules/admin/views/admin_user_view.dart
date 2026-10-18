import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/services/admin_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/dates.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/surface_card.dart';
import '../../orders/widgets/order_sections.dart';
import '../../vehicle_details/widgets/number_plate.dart';
import '../admin_navigation.dart';
import '../controllers/admin_user_controller.dart';
import '../widgets/admin_ui.dart';

class AdminUserView extends StatelessWidget {
  const AdminUserView({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AdminUserController>(tag: uid);
    // Content scrolls under the frosted app bar.
    final insets = MediaQuery.paddingOf(context);
    final listPadding = EdgeInsets.fromLTRB(16, insets.top + kToolbarHeight + 8, 16, insets.bottom + 32);
    return GlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: 'User details'),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              final user = controller.user.value;
              if (user == null) {
                return const AdminEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'User not found',
                  message: 'This account may have been deleted.',
                );
              }
              final vehicles = controller.vehicles;
              return ListView(
                padding: listPadding,
                children: [
                  _HeaderCard(user: user, onCall: controller.call),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Stat(label: 'Vehicles', value: '${vehicles.length}', color: GlassTokens.teal),
                      const SizedBox(width: 10),
                      _Stat(label: 'Orders', value: '${controller.orders.length}', color: GlassTokens.violet),
                      const SizedBox(width: 10),
                      _Stat(label: 'Paid', value: formatRupees(controller.paidTotal), color: AppColors.yellow),
                    ],
                  ),
                  const SectionLabel('Contact & identity'),
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Column(
                      children: [
                        _CopyRow(label: 'Phone', value: user.phone, onCopy: () => controller.copy('Phone', user.phone)),
                        _CopyRow(label: 'CNIC', value: user.cnic, onCopy: () => controller.copy('CNIC', user.cnic)),
                      ],
                    ),
                  ),
                  SectionLabel('Vehicles'),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} registered on this account',
                      style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                    ),
                  ),
                  for (final vehicle in vehicles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VehicleCard(vehicle: vehicle, controller: controller),
                    ),
                  const SectionLabel('Orders'),
                  if (controller.orders.isEmpty)
                    SurfaceCard(
                      child: Text('No orders yet', style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
                    )
                  else
                    for (final order in controller.orders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SurfaceCard(
                          onTap: () => AdminNav.openOrder(order.number),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${order.number}',
                                      style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15),
                                    ),
                                    Text(
                                      '${order.quantity} sticker${order.quantity == 1 ? '' : 's'} · ${formatRupees(order.total)}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              OrderStatusChip(status: order.status),
                            ],
                          ),
                        ),
                      ),
                  const SectionLabel('Account'),
                  AdminActionRow(
                    icon: user.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    label: user.blocked ? 'Unblock User' : 'Block User',
                    subtitle: user.blocked
                        ? 'Let ${user.firstName} sign in again'
                        : "Signs them out and stops sign-in. Vehicles, chats and orders are kept.",
                    danger: !user.blocked,
                    busy: controller.isUpdatingBlock.value,
                    onTap: controller.toggleBlocked,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user, required this.onCall});

  final AdminUser user;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AdminAvatar(name: user.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? 'No name' : user.name,
                      style: AppTextStyles.headingSm.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        user.blocked
                            ? const AdminTag(label: 'Blocked', color: adminDanger)
                            : AdminTag(label: 'Active', color: AppColors.success),
                        if (user.createdAt != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Joined ${formatDay(user.createdAt!)}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            onPressed: user.phone.isEmpty ? null : onCall,
            icon: Icons.call_rounded,
            height: 50,
            label: 'Call ${user.firstName.isEmpty ? 'user' : user.firstName}',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AdminStatTile(label: label, value: value, color: color),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final missing = value.isEmpty;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            missing ? 'Not added' : value,
            style: AppTextStyles.fieldValue.copyWith(color: missing ? AppColors.faint : AppColors.ink),
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          onPressed: missing ? null : onCopy,
          icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatefulWidget {
  const _VehicleCard({required this.vehicle, required this.controller});

  final AdminVehicle vehicle;
  final AdminUserController controller;

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  final _key = GlobalKey();
  bool _scrolled = false;

  void _scrollIntoViewIfFocused() {
    if (_scrolled || widget.controller.focusedVehicleId.value != widget.vehicle.id) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 350), alignment: 0.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final controller = widget.controller;
    return Obx(() {
      final focused = controller.focusedVehicleId.value == vehicle.id;
      if (!focused) {
        _scrolled = false;
      }
      _scrollIntoViewIfFocused();
      final open = controller.expanded.contains(vehicle.id);
      final duplicates = controller.duplicatesOf(vehicle);
      final accent = AppColors.yellow;
      final details = <(String, String)>[
        ('Registered', vehicle.dateOfRegistration),
        ('Engine no.', vehicle.engineNumber),
        ('Chassis no.', vehicle.chassisNumber),
        ('Address', vehicle.address),
        if (vehicle.createdAt != null) ('Added', formatDay(vehicle.createdAt!)),
      ].where((d) => d.$2.isNotEmpty).toList();
      final images = [
        ...vehicle.photoUrls,
        if (vehicle.rcCardFrontUrl.isNotEmpty) vehicle.rcCardFrontUrl,
        if (vehicle.rcCardBackUrl.isNotEmpty) vehicle.rcCardBackUrl,
      ];

      return KeyedSubtree(
        key: _key,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          borderColor: focused ? accent : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => controller.toggleExpanded(vehicle.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.nickname.isEmpty ? vehicle.plateNumber : vehicle.nickname,
                              style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15),
                            ),
                            Text(
                              [vehicle.makeModel, vehicle.colorName].where((s) => s.isNotEmpty).join(' · '),
                              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                            ),
                            if (duplicates.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const AdminTag(label: 'Duplicate plate', color: adminDanger),
                            ],
                          ],
                        ),
                      ),
                      NumberPlate(plate: vehicle.plateNumber, compact: true),
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.faint),
                    ],
                  ),
                ),
              ),
              if (open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (details.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: GlassTokens.tint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GlassTokens.hairline),
                          ),
                          child: Column(
                            children: [
                              for (final (label, value) in details)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          value,
                                          textAlign: TextAlign.right,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Photos & RC card', style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => showFullScreenImage(images[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  images[i],
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 72,
                                    color: GlassTokens.tint,
                                    child: Icon(Icons.broken_image_outlined, color: AppColors.faint),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (duplicates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GlassTile(
                          radius: 14,
                          tint: adminDanger,
                          borderColor: adminDanger.withValues(alpha: 0.25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This registration number is also registered on:',
                                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                              ),
                              for (final other in duplicates)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed: () => AdminNav.openUser(other.uid, vehicleId: other.id),
                                  child: Text(
                                    other.uid == vehicle.uid
                                        ? 'This account (another vehicle)'
                                        : controller.ownerName(other.uid),
                                    style: AppTextStyles.buttonLabel.copyWith(color: adminDanger, fontSize: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../controllers/admin_users_controller.dart';
import '../widgets/admin_ui.dart';

class AdminUsersTab extends GetView<AdminUsersController> {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final results = controller.results;
      final total = controller.users.length;
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          AdminTabHeader(
            title: 'Users',
            subtitle: controller.isLoading.value ? 'Loading…' : '$total user${total == 1 ? '' : 's'}',
          ),
          AdminSearchField(controller: controller.search, hint: 'Name, CNIC, phone or reg. number'),
          const SizedBox(height: 14),
          if (controller.isLoading.value)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (results.isEmpty)
            AdminEmptyState(
              icon: Icons.group_rounded,
              title: total == 0 ? 'No users yet' : 'No users found',
              message: total == 0
                  ? 'Customers who sign up will appear here.'
                  : 'Try a name, CNIC, phone or registration number.',
            )
          else
            for (final (i, result) in results.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RiseIn(
                  order: i.clamp(0, 6),
                  child: _UserRow(result: result, onTap: () => controller.open(result)),
                ),
              ),
        ],
      );
    });
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.result, required this.onTap});

  final UserSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = result.user;
    final count = result.vehicleCount;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AdminAvatar(name: user.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? 'No name' : user.name,
                      style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15),
                    ),
                    Text(user.phone, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AdminTag(label: count == 0 ? 'No vehicles' : '$count vehicle${count == 1 ? '' : 's'}'),
                        if (user.blocked) const AdminTag(label: 'Blocked', color: adminDanger),
                        if (result.matchedVehicle case final v?)
                          AdminTag(label: 'Matched ${v.plateNumber}', color: AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

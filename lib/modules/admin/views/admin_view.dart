import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/glass.dart';
import '../../dashboard/widgets/dashboard_bottom_nav.dart';
import '../controllers/admin_controller.dart';
import '../controllers/admin_orders_controller.dart';
import 'admin_orders_tab.dart';
import 'admin_profile_tab.dart';
import 'admin_users_tab.dart';

class AdminView extends BoundView<AdminController> {
  const AdminView({super.key});

  static const _navTabs = <NavTab>[
    (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Orders'),
    (icon: Icons.group_outlined, selectedIcon: Icons.group_rounded, label: 'Users'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _tabs = [AdminOrdersTab(), AdminUsersTab(), AdminProfileTab()];

  @override
  Widget buildWith(BuildContext context, AdminController controller) {
    // The whole admin side sits on the glass backdrop; its cards, dock and
    // sheets are frosted panels over it.
    return GlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Obx(() => IndexedStack(index: controller.tabIndex.value, children: _tabs)),
        ),
        bottomNavigationBar: Obx(
          () => DashboardBottomNav(
            tabs: _navTabs,
            selectedIndex: controller.tabIndex.value,
            onTap: controller.changeTab,
            // Orders waiting for a payment check.
            badgeTab: AdminController.ordersTab,
            unreadCount: Get.find<AdminOrdersController>().toReviewCount,
          ),
        ),
      ),
    );
  }
}

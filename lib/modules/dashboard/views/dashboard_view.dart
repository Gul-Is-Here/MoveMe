import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/bound_view.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_bottom_nav.dart';
import 'home_tab_view.dart';
import 'inbox_view.dart';
import 'profile_view.dart';

class DashboardView extends BoundView<DashboardController> {
  const DashboardView({super.key});

  static const _tabs = [HomeTabView(), InboxView(), ProfileView()];

  @override
  Widget buildWith(BuildContext context, DashboardController controller) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // The nav is a floating, frosted dock — content scrolls behind it, and
      // each tab pads its scroll end by MediaQuery's bottom inset to clear it.
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final index = controller.tabIndex.value;
          return IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                _TabEntrance(active: i == index, child: _tabs[i]),
            ],
          );
        }),
      ),
      bottomNavigationBar: Obx(
        () => DashboardBottomNav(
          selectedIndex: controller.tabIndex.value,
          // tabIndex above is always observable, so this Obx is valid even
          // when the Inbox controller (and therefore the count) is absent.
          unreadCount: controller.hasUnreadSource ? controller.unreadMessageCount : 0,
          onTap: controller.changeTab,
          onAddVehicle: controller.openAddVehicle,
        ),
      ),
    );
  }
}

/// Fades and lifts a tab in each time it becomes the active one. The
/// [IndexedStack] keeps every tab alive (scroll position, listeners), so
/// only the arrival is animated — never a rebuild.
class _TabEntrance extends StatefulWidget {
  const _TabEntrance({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<_TabEntrance> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_TabEntrance old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

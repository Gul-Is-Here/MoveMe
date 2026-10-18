import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/dates.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../orders/widgets/order_sections.dart';
import '../controllers/admin_orders_controller.dart';
import '../widgets/admin_ui.dart';

class AdminOrdersTab extends GetView<AdminOrdersController> {
  const AdminOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = controller.visible;
      final orders = controller.orders;
      int count(AdminOrderFilter f) => orders.where((o) => f.matches(o.status)).length;
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          const AdminTabHeader(title: 'Orders', subtitle: 'Check payments, then print and ship stickers.'),
          Row(
            children: [
              Expanded(
                child: AdminStatTile(
                  label: 'Awaiting check',
                  value: '${controller.toReviewCount}',
                  color: AppColors.yellow,
                  onTap: () => controller.filter.value = AdminOrderFilter.toReview,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminStatTile(
                  label: 'Active',
                  value: '${count(AdminOrderFilter.inProgress)}',
                  color: const Color(0xFF4C8DF6),
                  onTap: () => controller.filter.value = AdminOrderFilter.inProgress,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminStatTile(
                  label: 'All orders',
                  value: '${orders.length}',
                  color: GlassTokens.violet,
                  onTap: () => controller.filter.value = AdminOrderFilter.all,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminSearchField(controller: controller.search, hint: 'Order number, name, phone or plate'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final f in AdminOrderFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AdminFilterChip(
                      label: f == AdminOrderFilter.toReview && controller.toReviewCount > 0
                          ? '${f.label} (${controller.toReviewCount})'
                          : f.label,
                      selected: controller.filter.value == f,
                      onTap: () => controller.filter.value = f,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (controller.isLoading.value)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            const AdminEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No orders here',
              message: 'Orders that match will appear here as soon as they are placed.',
            )
          else
            for (final (i, order) in visible.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RiseIn(
                  order: i.clamp(0, 6),
                  child: _OrderRow(order: order, onTap: () => controller.open(order)),
                ),
              ),
        ],
      );
    });
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final StickerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = OrderStatusChip.colorFor(order.status);
    final meta = [
      '${order.quantity} sticker${order.quantity == 1 ? '' : 's'}',
      order.delivery.city,
      if (order.createdAt != null) formatDay(order.createdAt!),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AdminIconBadge(icon: Icons.receipt_long_rounded, color: color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${order.number}',
                            style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15.5),
                          ),
                        ),
                        OrderStatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.customerName} · ${order.customerPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(color: AppColors.ink.withValues(alpha: 0.85), height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                          ),
                        ),
                        Text(
                          formatRupees(order.total),
                          style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

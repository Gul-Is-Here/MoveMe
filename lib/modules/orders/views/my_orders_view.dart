import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/dates.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/surface_card.dart';
import '../controllers/my_orders_controller.dart';
import '../widgets/order_sections.dart';

class MyOrdersView extends BoundView<MyOrdersController> {
  const MyOrdersView({super.key});

  @override
  Widget buildWith(BuildContext context, MyOrdersController controller) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text('My Orders', style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (controller.hasError.value) {
                return _Message(icon: Icons.cloud_off_rounded, title: 'Something went wrong', message: 'Check your connection and try again.');
              }
              if (controller.orders.isEmpty) {
                return const _Message(
                  icon: Icons.receipt_long_rounded,
                  title: 'No orders yet',
                  message: 'Order QR stickers from any of your vehicles.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: controller.orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _OrderRow(order: controller.orders[i], onTap: () => controller.open(controller.orders[i])),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final StickerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.number}', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  '${order.quantity} sticker${order.quantity == 1 ? '' : 's'}'
                  '${order.createdAt == null ? '' : ' · ${formatDay(order.createdAt!)}'}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          OrderStatusChip(status: order.status),
          Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.faint),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

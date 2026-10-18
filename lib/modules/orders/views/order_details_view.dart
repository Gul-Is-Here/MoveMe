import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/surface_card.dart';
import '../controllers/order_details_controller.dart';
import '../widgets/order_sections.dart';

class OrderDetailsView extends BoundView<OrderDetailsController> {
  const OrderDetailsView({super.key});

  @override
  Widget buildWith(BuildContext context, OrderDetailsController controller) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text('Order details', style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              final order = controller.order.value;
              if (order == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      "We couldn't find this order.",
                      style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  OrderHeaderCard(order: order),
                  if (order.note.isNotEmpty) ...[const SizedBox(height: 14), OrderNoteCard(note: order.note)],
                  const SectionLabel('Status'),
                  OrderTimeline(order: order),
                  const SectionLabel('Stickers'),
                  OrderStickersCard(order: order),
                  const SectionLabel('Delivery'),
                  OrderDeliveryCard(delivery: order.delivery),
                  const SectionLabel('Payment'),
                  OrderPaymentCard(payment: order.payment),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

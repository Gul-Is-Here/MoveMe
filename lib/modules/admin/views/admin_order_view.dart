import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/surface_card.dart';
import '../../orders/widgets/order_sections.dart';
import '../admin_navigation.dart';
import '../controllers/admin_order_controller.dart';
import '../widgets/admin_ui.dart';
import '../widgets/sticker_sheet.dart';

class AdminOrderView extends BoundView<AdminOrderController> {
  const AdminOrderView({super.key});

  // Two columns, split by a line: the normal flow on the left, the
  // shipping and stop states on the right.
  static const _left = [OrderStatus.review, OrderStatus.confirmed, OrderStatus.printing];
  static const _right = [OrderStatus.shipped, OrderStatus.rejected, OrderStatus.cancelled];

  @override
  Widget buildWith(BuildContext context, AdminOrderController controller) {
    // Content scrolls under the frosted app bar.
    final insets = MediaQuery.paddingOf(context);
    final listPadding = EdgeInsets.fromLTRB(16, insets.top + kToolbarHeight + 8, 16, insets.bottom + 32);
    return GlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: 'Order #${controller.number}'),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              final order = controller.order.value;
              if (order == null) {
                return const AdminEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Order not found',
                  message: 'It may have been removed.',
                );
              }
              return ListView(
                padding: listPadding,
                children: [
                  OrderHeaderCard(order: order),
                  const SectionLabel('Customer'),
                  SurfaceCard(
                    child: Column(
                      children: [
                        OrderDetailRow(label: 'Name', value: order.customerName),
                        OrderDetailRow(label: 'Phone', value: order.customerPhone),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () => AdminNav.openUser(order.uid),
                            icon: Icon(Icons.person_search_rounded, color: AppColors.yellow, size: 18),
                            label: Text(
                              'View account',
                              style: AppTextStyles.buttonLabel.copyWith(color: AppColors.yellow, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SectionLabel('Stickers'),
                  OrderStickersCard(
                    order: order,
                    onTapItem: (item) => StickerSheet.show(
                      item: item,
                      controller: controller,
                      onViewVehicle: () => AdminNav.openUser(order.uid, vehicleId: item.vehicleId),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a vehicle to view its QR, print it or share it as an image.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => GlassSecondaryButton(
                      label: 'Share PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      isLoading: controller.busyJob.value == 'pdf',
                      onPressed: controller.shareOrderPdf,
                    ),
                  ),
                  const SectionLabel('Delivery'),
                  OrderDeliveryCard(delivery: order.delivery),
                  const SectionLabel('Payment'),
                  OrderPaymentCard(
                    payment: order.payment,
                    footer: _PaymentProof(url: order.payment.screenshotUrl),
                  ),
                  const SectionLabel('Update order'),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatusColumn(statuses: _left, controller: controller),
                              ),
                              VerticalDivider(color: GlassTokens.hairline, width: 20),
                              Expanded(
                                child: _StatusColumn(statuses: _right, controller: controller),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('NOTE TO THE CUSTOMER', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller.note,
                          maxLines: 3,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: 'e.g. a courier tracking number, or why a payment was rejected',
                            hintStyle: AppTextStyles.caption.copyWith(color: AppColors.faint),
                            errorText: controller.noteError.value,
                            filled: true,
                            fillColor: GlassTokens.tint,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: GlassTokens.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.yellow, width: 1.4),
                            ),
                          ),
                        ),
                        Text(
                          'The customer sees this on their order, and in the notification.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        GlassPrimaryButton(
                          label: 'Save Changes',
                          isLoading: controller.isSaving.value,
                          onPressed: controller.save,
                        ),
                      ],
                    ),
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

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.statuses, required this.controller});

  final List<OrderStatus> statuses;
  final AdminOrderController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final status in statuses)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatusButton(
              status: status,
              selected: controller.selectedStatus.value == status,
              onTap: () => controller.selectStatus(status),
            ),
          ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status, required this.selected, required this.onTap});

  final OrderStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = OrderStatusChip.colorFor(status);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Color.alphaBlend(color.withValues(alpha: 0.18), GlassTokens.tint) : GlassTokens.tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : GlassTokens.hairline, width: selected ? 1.6 : 1),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 1 : 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.buttonLabel.copyWith(
                    color: selected ? AppColors.ink : AppColors.muted,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentProof extends StatelessWidget {
  const _PaymentProof({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        GlassTile(
          padding: const EdgeInsets.all(10),
          radius: 14,
          tint: AppColors.yellow,
          borderColor: AppColors.yellow.withValues(alpha: 0.25),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check this amount arrived before confirming.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showFullScreenImage(url),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    url,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 180,
                      color: GlassTokens.tint,
                      alignment: Alignment.center,
                      child: Text(
                        "Couldn't load the screenshot",
                        style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Tap to view',
                      style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

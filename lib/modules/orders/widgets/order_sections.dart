import 'package:flutter/material.dart';

import '../../../app/models/sticker_order.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/dates.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/surface_card.dart';

const _closedRed = Color(0xFFE5675E);

/// A small coloured chip with the order's status.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  static Color colorFor(OrderStatus status) => switch (status) {
        OrderStatus.review => AppColors.yellow,
        OrderStatus.confirmed || OrderStatus.printing => const Color(0xFF4C8DF6),
        OrderStatus.shipped => AppColors.success,
        OrderStatus.rejected || OrderStatus.cancelled => _closedRed,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(
        status.label,
        style: AppTextStyles.label.copyWith(color: color, fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Order number + date placed.
class OrderHeaderCard extends StatelessWidget {
  const OrderHeaderCard({super.key, required this.order, this.trailing});

  final StickerOrder order;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.number}', style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  order.createdAt == null ? 'Just placed' : 'Placed ${formatDayTime(order.createdAt!)}',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          trailing ?? OrderStatusChip(status: order.status),
        ],
      ),
    );
  }
}

/// The order's progress (under review → confirmed → printing → shipped),
/// or where it stopped if it was rejected or cancelled.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final StickerOrder order;

  @override
  Widget build(BuildContext context) {
    final steps = [...OrderStatus.progress];
    if (order.status.isClosed) {
      // Show how far it got, then the stop.
      final reached = steps.lastIndexWhere((s) => order.statusTimes.containsKey(s));
      steps
        ..removeRange(reached + 1, steps.length)
        ..add(order.status);
    }
    final currentIndex = steps.indexOf(order.status);

    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              status: steps[i],
              at: order.statusTimes[steps[i]],
              done: i < currentIndex,
              current: i == currentIndex,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.at,
    required this.done,
    required this.current,
    required this.isLast,
  });

  final OrderStatus status;
  final DateTime? at;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = done || current;
    final color = status.isClosed ? _closedRed : (reached ? AppColors.success : AppColors.border);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: reached ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: reached
                      ? Icon(status.isClosed ? Icons.close_rounded : Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: done ? AppColors.success : AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: reached ? AppColors.ink : AppColors.muted,
                      fontSize: 15,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(height: 2),
                    Text(status.customerText, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                  ],
                  if (at != null && reached)
                    Text(formatDayTime(at!), style: AppTextStyles.caption.copyWith(color: AppColors.faint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The admin's note on an off-white yellow card, so it stands out.
class OrderNoteCard extends StatelessWidget {
  const OrderNoteCard({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: Color(0xFF8A6100)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message from MoveMe',
                  style: AppTextStyles.buttonLabel.copyWith(color: const Color(0xFF5C4100), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(note, style: AppTextStyles.subtitle.copyWith(color: const Color(0xFF3D2C00))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row per vehicle with its sticker count, then unit price and total.
class OrderStickersCard extends StatelessWidget {
  const OrderStickersCard({super.key, required this.order, this.onTapItem});

  final StickerOrder order;
  final void Function(OrderItem item)? onTapItem;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          for (final item in order.items)
            InkWell(
              onTap: onTapItem == null ? null : () => onTapItem!(item),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: AppColors.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.plateNumber, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
                          if (item.nickname.isNotEmpty && item.nickname != item.plateNumber)
                            Text(item.nickname, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text('× ${item.quantity}', style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
                    if (onTapItem != null) Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                  ],
                ),
              ),
            ),
          Divider(color: AppColors.border, height: 20),
          _AmountRow(label: 'Price per sticker', value: formatRupees(order.unitPrice)),
          _AmountRow(label: '${order.quantity} sticker${order.quantity == 1 ? '' : 's'}', value: formatRupees(order.total), bold: true),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 16)
        : AppTextStyles.subtitle.copyWith(color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}

/// Label on the left, value on the right.
class OrderDetailRow extends StatelessWidget {
  const OrderDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.subtitle.copyWith(color: AppColors.muted))),
          Expanded(child: Text(value, style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink))),
        ],
      ),
    );
  }
}

class OrderDeliveryCard extends StatelessWidget {
  const OrderDeliveryCard({super.key, required this.delivery});

  final OrderDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          OrderDetailRow(label: 'Name', value: delivery.fullName),
          OrderDetailRow(label: 'Phone', value: delivery.phone),
          OrderDetailRow(label: 'Address', value: delivery.address),
          OrderDetailRow(label: 'City', value: '${delivery.city}, ${delivery.province}'),
          OrderDetailRow(label: 'Postal code', value: delivery.postalCode),
        ],
      ),
    );
  }
}

class OrderPaymentCard extends StatelessWidget {
  const OrderPaymentCard({super.key, required this.payment, this.footer});

  final OrderPayment payment;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderDetailRow(label: 'Method', value: payment.method),
          OrderDetailRow(label: 'Paid into', value: '${payment.accountNumber} · ${payment.accountTitle}'),
          OrderDetailRow(label: 'Amount sent', value: formatRupees(payment.amount)),
          ?footer,
        ],
      ),
    );
  }
}

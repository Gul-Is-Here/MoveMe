import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/models/payment_account.dart';
import '../../../app/models/sticker_order.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/surface_card.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../controllers/order_form_controller.dart';

class OrderFormView extends BoundView<OrderFormController> {
  const OrderFormView({super.key});

  @override
  Widget buildWith(BuildContext context, OrderFormController controller) {
    return Obx(
      () => PopScope(
        // Back on step 2 returns to step 1 with everything kept.
        canPop: controller.step.value == 0 && !controller.isPlacing.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !controller.isPlacing.value) controller.back();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.ink,
            title: Text('Order QR stickers', style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _StepHeader(step: controller.step.value),
                    Expanded(
                      child: controller.step.value == 0
                          ? _StickersAndDelivery(controller: controller)
                          : _Payment(controller: controller),
                    ),
                    _BottomBar(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    Widget pill(int index, String label) {
      final active = step >= index;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: active ? accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step ${index + 1} · $label',
              style: AppTextStyles.caption.copyWith(color: active ? AppColors.ink : AppColors.muted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(children: [pill(0, 'Stickers & delivery'), const SizedBox(width: 10), pill(1, 'Payment')]),
    );
  }
}

class _StickersAndDelivery extends StatelessWidget {
  const _StickersAndDelivery({required this.controller});

  final OrderFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const SectionLabel('Stickers'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Obx(() {
            if (controller.isLoadingVehicles.value) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            }
            if (controller.vehicles.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Add a vehicle first — each sticker carries one vehicle\'s QR code.',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
                ),
              );
            }
            return Column(
              children: [
                for (final v in controller.vehicles)
                  _QuantityRow(
                    vehicle: v,
                    quantity: controller.quantities[v.id] ?? 0,
                    onAdd: () => controller.increment(v.id),
                    onRemove: () => controller.decrement(v.id),
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Text(
            '${formatRupees(controller.unitPrice.value)} per sticker',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
        ),
        const SectionLabel('Delivery details'),
        SurfaceCard(
          child: Column(
            children: [
              AuthTextField(
                label: 'Full name',
                hint: 'Who should receive the stickers',
                icon: Icons.person_outline_rounded,
                controller: controller.fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _ReadOnlyField(label: 'Phone', value: controller.phone, icon: Icons.phone_outlined),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Full address',
                hint: 'House, street, area',
                icon: Icons.home_outlined,
                controller: controller.address,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _ProvinceField(controller: controller),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'City',
                hint: 'e.g. Lahore',
                icon: Icons.location_city_outlined,
                controller: controller.city,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Postal code',
                hint: '54000',
                icon: Icons.markunread_mailbox_outlined,
                controller: controller.postalCode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                textInputAction: TextInputAction.done,
                isComplete: (text) => text.length == 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({required this.vehicle, required this.quantity, required this.onAdd, required this.onRemove});

  final OrderableVehicle vehicle;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    Widget stepper(IconData icon, String tooltip, VoidCallback? onTap) => IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onTap,
          iconSize: 22,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            backgroundColor: accent.withValues(alpha: 0.14),
            foregroundColor: AppColors.ink,
            disabledBackgroundColor: AppColors.border.withValues(alpha: 0.4),
            disabledForegroundColor: AppColors.faint,
          ),
          icon: Icon(icon),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.plateNumber, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
                if (vehicle.nickname.isNotEmpty && vehicle.nickname != vehicle.plateNumber)
                  Text(vehicle.nickname, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          stepper(Icons.remove_rounded, 'One fewer for ${vehicle.plateNumber}', quantity > 0 ? onRemove : null),
          SizedBox(
            width: 40,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSm.copyWith(color: AppColors.ink),
            ),
          ),
          stepper(Icons.add_rounded, 'One more for ${vehicle.plateNumber}', onAdd),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(value, style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink))),
              Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.faint),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProvinceField extends StatelessWidget {
  const _ProvinceField({required this.controller});

  final OrderFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PROVINCE', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        Obx(
          () => DropdownButtonFormField<String>(
            initialValue: controller.province.value,
            isExpanded: true,
            hint: Text('Choose province', style: AppTextStyles.fieldValue.copyWith(color: AppColors.faint)),
            dropdownColor: AppColors.surface,
            style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.map_outlined, size: 20, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            items: [
              for (final p in pakistanProvinces) DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (value) => controller.province.value = value,
          ),
        ),
      ],
    );
  }
}

class _Payment extends StatelessWidget {
  const _Payment({required this.controller});

  final OrderFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SurfaceCard(
          child: Obx(
            () => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount to send', style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(formatRupees(controller.total), style: AppTextStyles.headingLg.copyWith(color: AppColors.ink)),
                    ],
                  ),
                ),
                Text(
                  '${controller.stickerCount} × ${formatRupees(controller.unitPrice.value)}',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SectionLabel('1. Send the payment to one of these'),
        Obx(() {
          if (controller.isLoadingAccounts.value) {
            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          }
          if (controller.accounts.isEmpty) {
            return SurfaceCard(
              child: Text(
                "Sticker orders aren't open right now — no payment account is available. Please try again later.",
                style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
              ),
            );
          }
          return Column(
            children: [
              for (final account in controller.accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AccountOption(
                    account: account,
                    selected: controller.selectedAccountId.value == account.id,
                    onSelect: () => controller.selectedAccountId.value = account.id,
                    onCopy: () => controller.copyAccountNumber(account),
                  ),
                ),
            ],
          );
        }),
        const SectionLabel('2. Upload a screenshot of the payment'),
        Obx(() => _ScreenshotPicker(path: controller.screenshotPath.value, onPick: controller.pickScreenshot)),
      ],
    );
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({required this.account, required this.selected, required this.onSelect, required this.onCopy});

  final PaymentAccount account;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? accent : AppColors.faint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.method, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
                    Text(account.accountTitle, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, size: 16, color: AppColors.ink),
                label: Text(account.accountNumber, style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotPicker extends StatelessWidget {
  const _ScreenshotPicker({required this.path, required this.onPick});

  final String? path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onPick,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.background,
              child: path == null
                  ? Icon(Icons.add_photo_alternate_outlined, color: AppColors.muted)
                  : Image.file(File(path!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path == null ? 'Choose screenshot' : 'Screenshot added',
                  style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  path == null ? 'From your gallery — it must show the amount sent.' : 'Tap to choose a different one.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Icon(path == null ? Icons.chevron_right_rounded : Icons.check_circle_rounded,
              color: path == null ? AppColors.faint : AppColors.success),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final OrderFormController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Obx(() {
        final progress = controller.uploadProgress.value;
        if (controller.step.value == 0) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${controller.stickerCount} sticker${controller.stickerCount == 1 ? '' : 's'}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                    ),
                    Text(formatRupees(controller.total), style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
                  ],
                ),
              ),
              SizedBox(width: 160, child: AuthPrimaryButton(label: 'Next', onPressed: controller.next)),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null) ...[
              LinearProgressIndicator(value: progress, color: AppColors.yellow, backgroundColor: AppColors.border),
              const SizedBox(height: 6),
              Text(
                'Uploading screenshot… ${(progress * 100).round()}%',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                OutlinedButton(
                  onPressed: controller.isPlacing.value ? null : controller.back,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 56),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Back', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthPrimaryButton(
                    label: 'Place order',
                    isLoading: controller.isPlacing.value,
                    onPressed: controller.accounts.isEmpty ? null : controller.placeOrder,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

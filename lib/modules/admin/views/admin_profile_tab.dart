import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/payment_account.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/money.dart';
import '../controllers/admin_controller.dart';
import '../controllers/admin_settings_controller.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/surface_card.dart';
import '../widgets/admin_theme_controls.dart';
import '../widgets/admin_ui.dart';

class AdminProfileTab extends GetView<AdminController> {
  const AdminProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AdminSettingsController>();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        const AdminTabHeader(title: 'Profile', subtitle: 'What customers pay, and where they pay it.'),
        _AdminHeader(phone: controller.adminPhone),
        const SectionLabel('Sticker price'),
        _StickerPriceCard(settings: settings),
        const SectionLabel('Payment accounts'),
        _PaymentAccounts(settings: settings),
        const SectionLabel('Appearance'),
        const AdminAppearancePicker(),
        const SectionLabel('Account'),
        Obx(
          () => AdminActionRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            subtitle: 'Sign out of the admin side on this phone',
            busy: controller.isSigningOut.value,
            onTap: controller.signOut,
          ),
        ),
      ],
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: accent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MoveMe Admin', style: AppTextStyles.headingSm.copyWith(color: Colors.white, fontSize: 19)),
                    const SizedBox(height: 2),
                    Text(phone, style: AppTextStyles.subtitle.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                ),
                child: Text(
                  'Admin',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontSize: 11.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickerPriceCard extends StatelessWidget {
  const _StickerPriceCard({required this.settings});

  final AdminSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          AdminIconBadge(icon: Icons.sell_rounded, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    formatRupees(settings.stickerPrice.value),
                    style: AppTextStyles.headingLg.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(height: 2),
                Text('per QR sticker', style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 124,
            child: GlassSecondaryButton(
              label: 'Change',
              icon: Icons.edit_outlined,
              height: 46,
              onPressed: settings.changeStickerPrice,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentAccounts extends StatelessWidget {
  const _PaymentAccounts({required this.settings});

  final AdminSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Obx(() {
        final accounts = settings.accounts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
              child: Text(
                'Users pay QR sticker orders into the active accounts.',
                style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
              ),
            ),
            if (!settings.isLoadingAccounts.value && !settings.hasActiveAccount) const _NoActiveAccountNote(),
            for (final account in accounts) ...[
              _AccountRow(
                account: account,
                busy: settings.busyAccountId.value == account.id,
                onEdit: () => settings.editAccount(account),
                onToggle: () => settings.toggleActive(account),
                onDelete: () => settings.deleteAccount(account),
              ),
              const SizedBox(height: 10),
            ],
            AdminActionRow(
              icon: Icons.add_rounded,
              label: 'Add payment account',
              subtitle: 'EasyPaisa, JazzCash or a bank account',
              onTap: settings.addAccount,
            ),
          ],
        );
      }),
    );
  }
}

class _NoActiveAccountNote extends StatelessWidget {
  const _NoActiveAccountNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassTile(
        tint: adminDanger,
        borderColor: adminDanger.withValues(alpha: 0.3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: adminDanger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "No account is shown to users, so customers can't place sticker orders. Add or switch one on.",
                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final PaymentAccount account;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  static IconData _iconFor(String method) {
    final m = method.toLowerCase();
    if (m.contains('bank')) return Icons.account_balance_rounded;
    if (m.contains('easypaisa') || m.contains('jazz')) return Icons.phone_android_rounded;
    return Icons.account_balance_wallet_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    return GlassTile(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 6),
      radius: 18,
      tint: account.active ? accent : null,
      borderColor: account.active ? accent.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminIconBadge(icon: _iconFor(account.method), color: account.active ? accent : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.method, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(account.accountNumber, style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink)),
                    Text(account.accountTitle, style: AppTextStyles.caption.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit account',
                onPressed: busy ? null : onEdit,
                icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
              ),
              IconButton(
                tooltip: 'Delete account',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: adminDanger),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 52),
              Expanded(
                child: Text(
                  account.active ? 'Account shown to users' : 'Account hidden from users',
                  style: AppTextStyles.caption.copyWith(color: account.active ? AppColors.success : AppColors.muted),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Switch.adaptive(value: account.active, activeTrackColor: accent, onChanged: (_) => onToggle()),
            ],
          ),
        ],
      ),
    );
  }
}

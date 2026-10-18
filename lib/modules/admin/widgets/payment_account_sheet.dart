import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/models/payment_account.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../../app/widgets/glass.dart';
import '../../auth/widgets/auth_text_field.dart';
import 'admin_sheet.dart';
import 'admin_ui.dart';

/// Add/edit a payment account. Returns the edited account (keeping
/// [existing]'s id), or null if dismissed.
class PaymentAccountSheet extends StatefulWidget {
  const PaymentAccountSheet({super.key, this.existing});

  final PaymentAccount? existing;

  static Future<PaymentAccount?> show({PaymentAccount? existing}) =>
      AdminSheet.show<PaymentAccount>(PaymentAccountSheet(existing: existing));

  @override
  State<PaymentAccountSheet> createState() => _PaymentAccountSheetState();
}

class _PaymentAccountSheetState extends State<PaymentAccountSheet> {
  late final _method = TextEditingController(text: widget.existing?.method ?? PaymentAccount.methods.first);
  late final _number = TextEditingController(text: widget.existing?.accountNumber ?? '');
  late final _title = TextEditingController(text: widget.existing?.accountTitle ?? '');
  late bool _active = widget.existing?.active ?? true;

  void _save() {
    final missing = <String>[
      if (_method.text.trim().isEmpty) 'payment method',
      if (_number.text.trim().isEmpty) 'account number',
      if (_title.text.trim().isEmpty) 'account title',
    ];
    if (missing.isNotEmpty) {
      AppSnackbar.show('A few things are missing', 'Please add: ${missing.join(', ')}.');
      return;
    }
    Get.back(
      result: PaymentAccount(
        id: widget.existing?.id ?? '',
        method: _method.text.trim(),
        accountNumber: _number.text.trim(),
        accountTitle: _title.text.trim(),
        active: _active,
      ),
    );
  }

  @override
  void dispose() {
    _method.dispose();
    _number.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminSheet(
      title: widget.existing == null ? 'Add payment account' : 'Edit payment account',
      subtitle: 'Customers pay sticker orders into the accounts shown to them.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in PaymentAccount.methods)
              AdminFilterChip(
                label: method,
                selected: _method.text == method,
                onTap: () => setState(() => _method.text = method),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Payment method',
          hint: 'EasyPaisa',
          icon: Icons.account_balance_wallet_outlined,
          controller: _method,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Account number',
          hint: '03XX XXXXXXX or IBAN',
          icon: Icons.numbers_rounded,
          controller: _number,
          inputFormatters: [LengthLimitingTextInputFormatter(40)],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Account title',
          hint: 'The name on the account',
          icon: Icons.person_outline_rounded,
          controller: _title,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _active,
          activeTrackColor: AppColors.yellow,
          onChanged: (value) => setState(() => _active = value),
          title: Text('Show to users', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
          subtitle: Text(
            _active ? 'Customers can pay into this account.' : 'Hidden from customers.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        GlassPrimaryButton(label: widget.existing == null ? 'Add account' : 'Save changes', onPressed: _save),
      ],
    );
  }
}

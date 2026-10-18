import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/services/order_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/utils/money.dart';
import '../../../app/widgets/glass.dart';
import '../../auth/widgets/auth_text_field.dart';
import 'admin_sheet.dart';

/// "Sticker price" sheet. Returns the new price, or null if dismissed.
class StickerPriceSheet extends StatefulWidget {
  const StickerPriceSheet({super.key, required this.current});

  final int current;

  static Future<int?> show({required int current}) => AdminSheet.show<int>(StickerPriceSheet(current: current));

  /// The error to show under the field, or null when [text] is a valid price.
  static String? validate(String text) {
    final price = int.tryParse(text.trim());
    if (price == null) return 'Enter the price in rupees, e.g. 500.';
    if (price < OrderService.minStickerPrice || price > OrderService.maxStickerPrice) {
      return 'Enter a price from ${formatRupees(OrderService.minStickerPrice)} to '
          '${formatRupees(OrderService.maxStickerPrice)}.';
    }
    return null;
  }

  @override
  State<StickerPriceSheet> createState() => _StickerPriceSheetState();
}

class _StickerPriceSheetState extends State<StickerPriceSheet> {
  late final _price = TextEditingController(text: '${widget.current}');
  String? _error;

  void _save() {
    final error = StickerPriceSheet.validate(_price.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Get.back(result: int.parse(_price.text.trim()));
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminSheet(
      title: 'Sticker price',
      subtitle: 'The price of one QR sticker. Orders already placed keep the price they were placed at.',
      children: [
        AuthTextField(
          label: 'Price per sticker (Rs)',
          hint: '500',
          icon: Icons.sell_outlined,
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.caption.copyWith(color: GlassTokens.danger)),
        ],
        const SizedBox(height: 8),
        Text(
          'Currently ${formatRupees(widget.current)} per sticker.',
          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        GlassPrimaryButton(label: 'Save price', onPressed: _save),
      ],
    );
  }
}

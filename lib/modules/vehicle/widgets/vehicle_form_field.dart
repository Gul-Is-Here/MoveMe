import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class VehicleFormField extends StatefulWidget {
  const VehicleFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.emphasize = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.leading,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.fillColor,
  });

  final String label;
  final String? hint;

  /// Small note after the label. One starting with "⚠" is treated as a
  /// "double-check this" flag and rendered as an accent warning chip.
  final String? helper;
  final TextEditingController controller;
  final bool emphasize;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final Widget? leading;

  /// Restricts what can be typed or pasted into the field.
  final List<TextInputFormatter>? inputFormatters;

  /// For fields whose value is chosen rather than typed (the date picker).
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  /// Input fill; defaults to [AppColors.surface]. Pass the page background
  /// when the field sits on a surface-colored card.
  final Color? fillColor;

  @override
  State<VehicleFormField> createState() => _VehicleFormFieldState();
}

class _VehicleFormFieldState extends State<VehicleFormField> {
  bool _focused = false;

  bool get _isWarning => widget.helper?.startsWith('⚠') ?? false;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final labelStyle = AppTextStyles.label.copyWith(
      color: _focused ? accent : AppColors.muted,
      letterSpacing: 0.4,
    );
    final restingBorder = widget.emphasize || _isWarning
        ? accent.withValues(alpha: _isWarning ? 0.7 : 1)
        : AppColors.border;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: widget.label.toUpperCase(),
                  style: labelStyle,
                  children: widget.helper == null || _isWarning
                      ? null
                      : [
                          TextSpan(
                            text: '  ${widget.helper}',
                            style: labelStyle.copyWith(
                              color: AppColors.faint,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                ),
              ),
            ),
            if (_isWarning) ...[
              const SizedBox(width: 8),
              _WarningChip(text: widget.helper!),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.leading != null) ...[
              Padding(padding: const EdgeInsets.only(top: 14), child: widget.leading),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: _focused ? 0.18 : 0),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.controller,
                    keyboardType: widget.keyboardType,
                    textCapitalization: widget.textCapitalization,
                    maxLines: widget.maxLines,
                    inputFormatters: widget.inputFormatters,
                    readOnly: widget.readOnly,
                    onTap: widget.onTap,
                    // A picker-backed field should not raise the keyboard.
                    showCursor: !widget.readOnly,
                    cursorColor: accent,
                    mouseCursor: widget.readOnly ? SystemMouseCursors.click : null,
                    style: AppTextStyles.fieldValue.copyWith(
                      color: AppColors.ink,
                      fontWeight: widget.emphasize ? FontWeight.w700 : FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      suffixIcon: widget.suffixIcon,
                      hintStyle: AppTextStyles.manropeBase.copyWith(
                        color: AppColors.faint,
                      ),
                      filled: true,
                      fillColor: widget.fillColor ?? AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: border(restingBorder),
                      enabledBorder: border(restingBorder),
                      focusedBorder: border(accent),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    // "⚠ check" -> "check": the icon replaces the glyph.
    final words = text.replaceFirst('⚠', '').trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 12, color: accent),
          if (words.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              words,
              style: AppTextStyles.label.copyWith(
                color: accent,
                fontSize: 10.5,
                letterSpacing: 0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

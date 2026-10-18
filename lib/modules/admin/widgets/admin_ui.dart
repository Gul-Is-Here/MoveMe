import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import 'admin_theme_controls.dart';

const adminDanger = GlassTokens.danger;

/// Initials on a coloured disc. The colour is picked from the name, so the
/// same person always gets the same colour and a list reads at a glance.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  static const _palette = [
    Color(0xFFE4572E),
    Color(0xFF6A4CF0),
    Color(0xFF169C8C),
    Color(0xFF2F7FE6),
    Color(0xFFE0457F),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.trim().codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Text(
        _initials,
        style: AppTextStyles.buttonLabel.copyWith(color: Colors.white, fontSize: size * 0.36),
      ),
    );
  }
}

/// A small rounded label, e.g. "2 vehicles" or "Blocked".
class AdminTag extends StatelessWidget {
  const AdminTag({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: tint, fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Eyebrow, big title and one-line subtitle at the top of each admin tab,
/// with the theme toggle (or [trailing]) on the right.
class AdminTabHeader extends StatelessWidget {
  const AdminTabHeader({super.key, required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.yellow),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MOVEME ADMIN',
                      style: AppTextStyles.overline.copyWith(color: AppColors.muted, fontSize: 10.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 30)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.subtitle.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? const AdminThemeToggle(),
        ],
      ),
    );
  }
}

/// A frosted search bar.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      radius: 18,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.yellow,
        style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.fieldValue.copyWith(color: AppColors.muted.withValues(alpha: 0.75)),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: controller.clear,
                    icon: Icon(Icons.close_rounded, color: AppColors.muted),
                  ),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/// A pill filter: frosted when off, solid accent with a glow when on.
class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? accent : GlassTokens.tint,
            border: Border.all(color: selected ? Colors.transparent : GlassTokens.rimHigh),
            boxShadow: selected
                ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected ? Colors.white : AppColors.ink.withValues(alpha: 0.75),
              letterSpacing: 0,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square with a tinted icon — the leading mark of rows
/// and cards.
class AdminIconBadge extends StatelessWidget {
  const AdminIconBadge({super.key, required this.icon, this.color, this.size = 40, this.child});

  final IconData icon;
  final Color? color;
  final double size;

  /// Replaces the icon (e.g. a spinner).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.yellow;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: child ?? Icon(icon, size: size * 0.5, color: c),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminIconBadge(icon: icon, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.headingSm.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable row with an icon, a label and a subtitle — settings and
/// account actions.
class AdminActionRow extends StatelessWidget {
  const AdminActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.busy = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool busy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = danger ? adminDanger : AppColors.ink;
    final badgeColor = danger ? adminDanger : AppColors.yellow;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: busy ? null : onTap,
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          radius: 18,
          tint: danger ? adminDanger : null,
          shadow: false,
          child: Row(
            children: [
              AdminIconBadge(
                icon: icon,
                color: badgeColor,
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2, color: badgeColor),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.buttonLabel.copyWith(color: color, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: danger ? adminDanger : AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small frosted stat: a coloured dot, a big number and a label.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({super.key, required this.label, required this.value, required this.color, this.onTap});

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 24)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      child: Pressable(onTap: onTap, child: tile),
    );
  }
}

/// Shows a network image full screen, pinch-to-zoom.
void showFullScreenImage(String url) {
  Get.dialog(
    Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(maxScale: 5, child: Center(child: Image.network(url))),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Close',
                onPressed: Get.back,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Frosted-glass colors, picked per theme like [AppColors]. Light glass is
/// milky white over a soft grey; dark glass is a faint white film over deep
/// navy. Every colour is solid — no gradients on the admin side.
class GlassTokens {
  GlassTokens._();

  static bool get _light => AppColors.isLight;

  /// Supporting colours for stats and states, beside the brand orange.
  static const violet = Color(0xFF7C5CFF);
  static const teal = Color(0xFF1FB8A6);
  static const danger = Color(0xFFEF5A5A);

  static Color get fill => _light ? Colors.white.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.065);

  /// Heavier glass for things that sit on top of other glass: sheets,
  /// dialogs, the app bar.
  static Color get fillStrong =>
      _light ? Colors.white.withValues(alpha: 0.80) : const Color(0xFF161B2B).withValues(alpha: 0.82);

  /// Inner tiles inside a glass card (rows, fields, buttons).
  static Color get tint => _light ? Colors.white.withValues(alpha: 0.62) : Colors.white.withValues(alpha: 0.05);

  /// The thin light edge around glass.
  static Color get rimHigh => _light ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.12);

  /// Hairline for dividers and inner borders.
  static Color get hairline =>
      _light ? const Color(0xFF1B1F3B).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08);

  static Color get shadow =>
      _light ? const Color(0xFF4B3FA8).withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.38);

  /// The admin side's plain background.
  static Color get background => _light ? const Color(0xFFF1F1F6) : const Color(0xFF0E111C);
}

/// Marks a subtree as glass: [SurfaceCard]s inside render as [GlassPanel]s,
/// so shared cards (the order sections) take on the admin look without
/// changing the customer screens.
class GlassScope extends InheritedWidget {
  const GlassScope({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GlassScope>() != null;

  @override
  bool updateShouldNotify(GlassScope oldWidget) => false;
}

/// The plain background glass sits on. Wraps [child] in a [GlassScope] and
/// a [BackdropGroup], so every panel above it shares one blur pass.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: GlassScope(
        child: ColoredBox(
          color: GlassTokens.background,
          child: BackdropGroup(child: child),
        ),
      ),
    );
  }
}

/// A frosted panel: blurs what's behind it, with a milky fill, a light rim
/// and a soft shadow. [tint] washes the glass in a colour (a warning, a
/// selected state).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.strong = false,
    this.tint,
    this.blur = 22,
    this.shadow = true,
    this.borderColor,
    this.expand = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool strong;

  /// Fills the available width; false sizes the panel to [child].
  final bool expand;
  final Color? tint;
  final double blur;
  final bool shadow;

  /// Replaces the light rim with a coloured border (e.g. focus).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final base = strong ? GlassTokens.fillStrong : GlassTokens.fill;
    final fill = tint == null ? base : Color.alphaBlend(tint!.withValues(alpha: 0.12), base);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [BoxShadow(color: GlassTokens.shadow, blurRadius: 32, spreadRadius: -6, offset: const Offset(0, 16))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: expand ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: r,
              border: Border.all(color: borderColor ?? GlassTokens.rimHigh, width: borderColor == null ? 1.2 : 1.6),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A rounded tile for content inside a glass panel — lighter than a second
/// blur, so rows and fields don't stack backdrop filters.
class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tint == null ? GlassTokens.tint : Color.alphaBlend(tint!.withValues(alpha: 0.10), GlassTokens.tint),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? GlassTokens.hairline),
      ),
      child: child,
    );
  }
}

/// A transparent, frosted app bar for screens drawn over [GlassBackdrop].
/// Use with `Scaffold(extendBodyBehindAppBar: true)`.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GlassTokens.fillStrong.withValues(alpha: GlassTokens.fillStrong.a * 0.6),
            border: Border(bottom: BorderSide(color: GlassTokens.hairline)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: AppColors.ink,
            title: Text(title, style: AppTextStyles.headingSm.copyWith(color: AppColors.ink)),
            actions: actions,
          ),
        ),
      ),
    );
  }
}

/// The solid accent button with a soft coloured glow.
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final accent = AppColors.yellow;
    return Opacity(
      opacity: onPressed == null && !isLoading ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: accent,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: height,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                          Text(label, style: AppTextStyles.buttonLabel.copyWith(color: Colors.white, fontSize: 15.5)),
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

/// A frosted secondary button: glass fill, ink label.
class GlassSecondaryButton extends StatelessWidget {
  const GlassSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.isLoading = false,
    this.height = 52,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isLoading;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.ink;
    return Material(
      color: GlassTokens.tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: GlassTokens.rimHigh.withValues(alpha: GlassTokens.rimHigh.a * 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        child: SizedBox(
          height: height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else
                  Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Text(label, style: AppTextStyles.buttonLabel.copyWith(color: fg, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

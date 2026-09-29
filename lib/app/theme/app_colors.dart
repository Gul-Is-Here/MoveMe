import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme_controller.dart';

/// Every screen reads its colors from here rather than `Theme.of(context)`,
/// so switching palettes is one flag: [_isLight] mirrors
/// [ThemeController.isLight], and each field below picks dark or light.
/// Toggling the controller calls `Get.forceAppUpdate()`, which repaints
/// every screen with whichever palette is now selected.
class AppColors {
  static bool get _isLight =>
      Get.isRegistered<ThemeController>() && ThemeController.to.isLight;

  /// Dark is the app's original, default look.
  static Color get background =>
      _isLight ? _light.background : _dark.background;
  static Color get surface => _isLight ? _light.surface : _dark.surface;
  static Color get yellow => _isLight ? _light.yellow : _dark.yellow;
  /// A darker shade of the accent, for the far end of accent gradients.
  static Color get accentDeep {
    final hsl = HSLColor.fromColor(yellow);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }

  static Color get ink => _isLight ? _light.ink : _dark.ink;
  static Color get muted => _isLight ? _light.muted : _dark.muted;
  static Color get faint => _isLight ? _light.faint : _dark.faint;

  /// The app's one hairline-border color (cards, chips, buttons, dividers).
  /// Was scattered across the codebase as several near-identical dark
  /// grays (`0xFF33332E`, `0xFF2E2E29`, ...) picked for a dark background
  /// — invisible there, but a harsh near-black outline once `surface`
  /// turns white in light mode. Consolidated to one semantic color here so
  /// it can have a real light-mode value instead.
  static Color get border => _isLight ? _light.border : _dark.border;

  /// The two shades [ShimmerBox] sweeps its highlight between — same idea
  /// as [border]: was a fixed dark-gray pair that stayed dark (and
  /// invisible against a white skeleton) in light mode.
  static Color get shimmerBase =>
      _isLight ? _light.shimmerBase : _dark.shimmerBase;
  static Color get shimmerHighlight =>
      _isLight ? _light.shimmerHighlight : _dark.shimmerHighlight;

  /// Green "resolved / verified" accent: text & icons, chip fill, chip border.
  static Color get success => _isLight ? _light.success : _dark.success;
  static Color get successSurface =>
      _isLight ? _light.successSurface : _dark.successSurface;
  static Color get successBorder =>
      _isLight ? _light.successBorder : _dark.successBorder;

  static const _dark = _Palette(
    background: Color(0xFF282828),
    surface: Color(0xFF1E1E1E),
    yellow: Color(0xffE4572E),
    ink: Color(0xFFF5F1E8),
    muted: Color(0xFF8A8A85),
    faint: Color(0xFF5C5C58),
    border: Color(0xFF33332E),
    shimmerBase: Color(0xFF232320),
    shimmerHighlight: Color(0xFF32322C),
    success: Color(0xFF7FBF7F),
    successSurface: Color(0xFF182018),
    successBorder: Color(0xFF2A3D2A),
  );

  static const _light = _Palette(
    background: Color(0xFFF0F0F0),
    surface: Color(0xFFFFFFFF),
    yellow: Color(0xffE4572E),
    ink: Color(0xFF1E1E1E),
    muted: Color(0xFF6B6B66),
    faint: Color(0xFFB0B0AA),
    border: Color(0xFFE0E0DA),
    shimmerBase: Color(0xFFE4E4DE),
    shimmerHighlight: Color(0xFFF6F6F2),
    success: Color(0xFF2E7D32),
    successSurface: Color(0xFFE6F4E7),
    successBorder: Color(0xFFB8DDBB),
  );
}

class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.yellow,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.border,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.success,
    required this.successSurface,
    required this.successBorder,
  });

  final Color background;
  final Color surface;
  final Color yellow;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color border;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color success;
  final Color successSurface;
  final Color successBorder;
}

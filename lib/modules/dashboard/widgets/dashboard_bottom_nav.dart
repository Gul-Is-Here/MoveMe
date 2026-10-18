import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/glass.dart';

/// Floating dock: a frosted-glass pill holding the three tabs, with a
/// liquid indicator that stretches from tab to tab, plus a separate raised
/// accent button for the Add-vehicle flow (RC card capture -> OCR).
///
/// Meant for `Scaffold(extendBody: true)`, so content scrolls behind the
/// blur; tab bodies clear it with `MediaQuery.paddingOf(context).bottom`.
typedef NavTab = ({IconData icon, IconData selectedIcon, String label});

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.onAddVehicle,
    this.unreadCount = 0,
    this.tabs = customerTabs,
    this.badgeTab = 1,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  /// The raised Add-vehicle button; hidden when null (the admin side).
  final VoidCallback? onAddVehicle;

  /// Count shown on the [badgeTab] tab (unread messages for customers).
  final int unreadCount;

  final List<NavTab> tabs;
  final int badgeTab;

  static const _height = 64.0;

  static const customerTabs = <NavTab>[
    (
      icon: Icons.directions_car_filled_outlined,
      selectedIcon: Icons.directions_car_filled,
      label: 'Home',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    (
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final background = AppColors.background;
    final glass = GlassScope.of(context);

    return DecoratedBox(
      // Fades content out beneath the dock so it never fights the tabs —
      // not on the admin side, which uses no gradients.
      decoration: glass
          ? const BoxDecoration()
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  background.withValues(alpha: 0),
                  background.withValues(alpha: 0.92),
                ],
                stops: const [0, 0.55],
              ),
            ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(child: _glassPill(glass)),
              if (onAddVehicle case final onAdd?) ...[
                const SizedBox(width: 12),
                _AddButton(size: _height, onTap: onAdd),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassPill(bool glass) {
    const radius = BorderRadius.all(Radius.circular(_height / 2));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glass
                ? GlassTokens.shadow
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: glass
                  ? GlassTokens.fillStrong
                  : AppColors.surface.withValues(alpha: 0.82),
              borderRadius: radius,
              border: Border.all(
                color: glass ? GlassTokens.rimHigh : AppColors.border,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segment = constraints.maxWidth / tabs.length;
                return Stack(
                  children: [
                    _LiquidIndicator(
                      index: selectedIndex,
                      segmentWidth: segment,
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _NavItem(
                              icon: tabs[i].icon,
                              selectedIcon: tabs[i].selectedIcon,
                              label: tabs[i].label,
                              isSelected: selectedIndex == i,
                              badgeCount: i == badgeTab ? unreadCount : 0,
                              onTap: () {
                                if (selectedIndex != i) {
                                  HapticFeedback.selectionClick();
                                }
                                onTap(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected-tab highlight. When the tab changes, its leading edge
/// races ahead and the trailing edge catches up, so the pill stretches
/// toward the new tab and snaps back into shape — a liquid slide rather
/// than a rigid one.
class _LiquidIndicator extends StatefulWidget {
  const _LiquidIndicator({required this.index, required this.segmentWidth});

  final int index;
  final double segmentWidth;

  @override
  State<_LiquidIndicator> createState() => _LiquidIndicatorState();
}

class _LiquidIndicatorState extends State<_LiquidIndicator>
    with SingleTickerProviderStateMixin {
  static const _inset = 6.0;
  static const _lead = Interval(0, 0.7, curve: Curves.easeOutCubic);
  static const _trail = Interval(0.25, 1, curve: Curves.easeOutCubic);

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );

  /// Edges (in px) the current slide starts from; re-captured mid-flight so
  /// a quick second tap continues from where the pill is, not where it was.
  late double _fromLeft = _leftOf(widget.index);
  late double _fromRight = _rightOf(widget.index);

  double _leftOf(int i) => i * widget.segmentWidth + _inset;
  double _rightOf(int i) => (i + 1) * widget.segmentWidth - _inset;

  (double, double) _edgesAt(double t) {
    final target = widget.index;
    final movingRight = _leftOf(target) >= _fromLeft;
    final leftT = (movingRight ? _trail : _lead).transform(t);
    final rightT = (movingRight ? _lead : _trail).transform(t);
    return (
      _fromLeft + (_leftOf(target) - _fromLeft) * leftT,
      _fromRight + (_rightOf(target) - _fromRight) * rightT,
    );
  }

  @override
  void didUpdateWidget(_LiquidIndicator old) {
    super.didUpdateWidget(old);
    if (old.segmentWidth != widget.segmentWidth) {
      _fromLeft = _leftOf(widget.index);
      _fromRight = _rightOf(widget.index);
      _controller.value = 1;
    } else if (old.index != widget.index) {
      // Where the pill is right now, measured against the old target.
      final oldTarget = old.index;
      final t = _controller.value;
      final movingRight = _leftOf(oldTarget) >= _fromLeft;
      final leftT = (movingRight ? _trail : _lead).transform(t);
      final rightT = (movingRight ? _lead : _trail).transform(t);
      _fromLeft = _fromLeft + (_leftOf(oldTarget) - _fromLeft) * leftT;
      _fromRight = _fromRight + (_rightOf(oldTarget) - _fromRight) * rightT;

      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final (left, right) = _edgesAt(_controller.value);
        return Positioned(
          left: left,
          width: right - left,
          top: _inset,
          bottom: _inset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(
                DashboardBottomNav._height / 2,
              ),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.yellow : AppColors.muted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: badgeCount > 0
          ? '$label, $badgeCount unread message${badgeCount == 1 ? '' : 's'}'
          : label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Keyed on selection so the pop replays each time a tab is
              // picked, and never on the tab being left.
              TweenAnimationBuilder<double>(
                key: ValueKey(isSelected),
                tween: Tween(begin: isSelected ? 0.6 : 1, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _IconWithBadge(
                  icon: isSelected ? selectedIcon : icon,
                  color: color,
                  badgeCount: badgeCount,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 11,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tab icon with its unread badge pinned to the top-right.
///
/// The badge overflows the icon's box deliberately, so adding it never
/// changes the icon's size and the three tabs stay evenly spaced whether
/// or not there are unread messages.
class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color, size: 24),
          Positioned(
            top: -5,
            right: -8,
            child: AnimatedScale(
              scale: badgeCount > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(9),
                  // Matches the dock so the badge reads as sitting on top
                  // of the icon rather than merging into it.
                  border: Border.all(color: AppColors.surface, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline.copyWith(
                    color: Colors.black,
                    fontSize: 9.5,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raised accent circle beside the pill. Adding a vehicle (RC card capture
/// -> OCR) — the QR-to-chat scanner lives on the Home tab, so this one
/// intentionally isn't a QR icon.
class _AddButton extends StatefulWidget {
  const _AddButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final deep = HSLColor.fromColor(accent)
        .withLightness(
          (HSLColor.fromColor(accent).lightness - 0.1).clamp(0.0, 1.0),
        )
        .toColor();

    return Semantics(
      button: true,
      label: 'Add a vehicle',
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, deep],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _pressed ? 0.3 : 0.45),
                  blurRadius: _pressed ? 12 : 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              size: 25,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../app/utils/auth_input.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/dot_grid_background.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/shimmer.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../../vehicle/widgets/form_section_card.dart';
import '../../vehicle/widgets/vehicle_form_field.dart';
import '../controllers/home_tab_controller.dart';
import '../controllers/inbox_controller.dart';
import '../controllers/profile_controller.dart';

const _danger = Color(0xFFE5675E);

class ProfileView extends BoundView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget buildWith(BuildContext context, ProfileController controller) {
    return Obx(() {
      if (controller.isLoading.value) return const _LoadingState();
      return _ProfileForm(
        controller: controller,
        phone: controller.phoneNumber.value,
        cnic: controller.cnic.value,
      );
    });
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({required this.controller, required this.phone, required this.cnic});

  final ProfileController controller;
  final String phone;
  final String cnic;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // The bottom inset clears the floating nav dock.
      padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + MediaQuery.paddingOf(context).bottom),
      children: [
        RiseIn(
          order: 0,
          child: Text(
            'Profile',
            style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 28),
          ),
        ),
        const SizedBox(height: 14),
        RiseIn(order: 1, child: _HeroCard(controller: controller)),

        // No exit animation on purpose: once permission is granted the
        // banner is gone in the same frame.
        Obx(
          () => controller.notificationsPermitted.value
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: RiseIn(
                    order: 2,
                    child: _NotificationsOffBanner(onTapRecheck: controller.recheckNotificationPermission),
                  ),
                ),
        ),
        const SizedBox(height: 14),

        RiseIn(
          order: 2,
          child: FormSectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Personal info',
            children: [
              VehicleFormField(
                label: 'Full Name',
                controller: controller.name,
                fillColor: AppColors.background,
                inputFormatters: nameInputFormatters,
              ),
              Obx(
                () => AuthPrimaryButton(
                  label: 'Save Changes',
                  isLoading: controller.isSaving.value,
                  onPressed: controller.save,
                  height: 52,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        RiseIn(
          order: 3,
          child: FormSectionCard(
            icon: Icons.verified_user_outlined,
            title: 'Verified identity',
            spacing: 12,
            children: [
              _LockedField(
                icon: Icons.phone_iphone_rounded,
                label: 'Phone number',
                value: phone.isEmpty ? 'Not available' : phone,
                note: "Can't be changed without re-verification",
                verified: true,
              ),
              if (cnic.isNotEmpty)
                // CNIC — read-only, used for identity verification only (FR-01.1).
                _LockedField(
                  icon: Icons.badge_outlined,
                  label: 'CNIC',
                  value: cnic,
                  note: 'Used for identity verification only',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        RiseIn(
          order: 4,
          child: FormSectionCard(
            icon: Icons.receipt_long_outlined,
            title: 'QR stickers',
            spacing: 10,
            children: [
              _AccountAction(
                icon: Icons.local_shipping_outlined,
                label: 'My Orders',
                subtitle: 'Track your QR sticker orders',
                onTap: controller.openMyOrders,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        RiseIn(order: 4, child: _ReachPreferenceCard(controller: controller)),
        const SizedBox(height: 14),

        const RiseIn(order: 4, child: _AppearanceCard()),
        const SizedBox(height: 14),

        RiseIn(
          order: 5,
          child: FormSectionCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            spacing: 10,
            children: [
              _AccountAction(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                subtitle: 'Sign out of MoveMe on this phone',
                onTap: controller.logout,
              ),
              Obx(
                () => _AccountAction(
                  icon: Icons.delete_outline_rounded,
                  label: controller.isDeleting.value ? 'Deleting account…' : 'Delete Account',
                  subtitle: 'Permanently remove your account and data',
                  danger: true,
                  busy: controller.isDeleting.value,
                  onTap: controller.isDeleting.value ? null : controller.deleteAccount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const RiseIn(order: 6, child: _Footer()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// Accent card with the resident's avatar, live name (it follows the Full
/// Name field as it's edited), verified badge, and a glance at their
/// vehicles and conversations when those tabs are loaded.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, AppColors.accentDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DotGridBackground(color: Colors.white, center: Alignment(0.9, -0.6), radius: 1.2),
          ),
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller.name,
              builder: (context, value, _) {
                final name = value.text.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(initials: _initialsOf(name)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'Your name' : name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.headingLg.copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'Verified Resident',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.label.copyWith(
                                          color: Colors.white,
                                          letterSpacing: 0,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const _HeroStats(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

/// White initials disc inside a gradient ring that sweeps once around on
/// arrival.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => CustomPaint(
        painter: _RingPainter(progress: t),
        child: child,
      ),
      child: Container(
        width: 76,
        height: 76,
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          alignment: Alignment.center,
          child: initials.isEmpty
              ? Icon(Icons.person_rounded, size: 32, color: AppColors.yellow)
              : Text(
                  initials,
                  style: AppTextStyles.headingLg.copyWith(
                    color: AppColors.accentDeep,
                    fontSize: 24,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

/// Vehicles and conversations counts, read from the Home and Inbox tabs'
/// existing listeners — shown only when those are loaded (the profile is
/// also rendered standalone).
class _HeroStats extends StatelessWidget {
  const _HeroStats();

  @override
  Widget build(BuildContext context) {
    final home = Get.isRegistered<HomeTabController>() ? Get.find<HomeTabController>() : null;
    final inbox = Get.isRegistered<InboxController>() ? Get.find<InboxController>() : null;
    if (home == null && inbox == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Obx(
        () => Row(
          children: [
            if (home != null)
              Expanded(
                child: _StatPill(
                  icon: Icons.directions_car_filled_rounded,
                  value: home.vehicles.length,
                  label: home.vehicles.length == 1 ? 'Vehicle' : 'Vehicles',
                ),
              ),
            if (home != null && inbox != null) const SizedBox(width: 10),
            if (inbox != null)
              Expanded(
                child: _StatPill(
                  icon: Icons.forum_rounded,
                  value: inbox.threads.length + inbox.sentThreads.length,
                  label: inbox.threads.length + inbox.sentThreads.length == 1 ? 'Conversation' : 'Conversations',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: AppTextStyles.headingSm.copyWith(color: Colors.white, fontSize: 17),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications banner
// ---------------------------------------------------------------------------

/// Only shown while [ProfileController.notificationsPermitted] is false.
///
/// Why this exists: FCM reports a push as "successfully delivered" the
/// moment it reaches the device, regardless of whether the OS is actually
/// allowed to show it. With notifications denied, that push is silently
/// discarded — from the backend's side (and from a resident just staring
/// at the app) it looks identical to a broken token, when the real cause
/// is a permission this app can only ask for once.
class _NotificationsOffBanner extends StatelessWidget {
  const _NotificationsOffBanner({required this.onTapRecheck});

  final VoidCallback onTapRecheck;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.1), AppColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.notifications_off_outlined, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications are turned off',
                  style: AppTextStyles.fieldValue.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  "You won't be alerted when someone messages you. Enable "
                  'notifications for MoveMe in your phone\'s Settings app, '
                  'then come back here.',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                Pressable(
                  onTap: onTapRecheck,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            "I've enabled it — check again",
                            style: AppTextStyles.linkTextEmphasis.copyWith(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

class _LockedField extends StatelessWidget {
  const _LockedField({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    this.verified = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: AppTextStyles.fieldValue.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (verified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.success,
                          letterSpacing: 0.2,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.faint),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            note,
            style: AppTextStyles.caption.copyWith(color: AppColors.faint, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance
// ---------------------------------------------------------------------------

/// Lets the resident switch between the app's dark (default) and light
/// palettes — [ThemeController] persists the choice and repaints every
/// screen via [Get.forceAppUpdate]. A sliding highlight marks the choice.
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  static const _modes = [
    (mode: AppThemeMode.light, icon: Icons.light_mode_rounded, label: 'Light'),
    (mode: AppThemeMode.dark, icon: Icons.dark_mode_rounded, label: 'Dark'),
    (mode: AppThemeMode.system, icon: Icons.brightness_auto_rounded, label: 'Auto'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return FormSectionCard(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      children: [
        Obx(() {
          final mode = ThemeController.to.mode.value;
          final index = _modes.indexWhere((m) => m.mode == mode);

          return Container(
            height: 76,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segment = constraints.maxWidth / _modes.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      left: index * segment,
                      width: segment,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(colors: [accent, AppColors.accentDeep]),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final m in _modes)
                          Expanded(
                            child: _ThemeOption(
                              icon: m.icon,
                              label: m.label,
                              selected: m.mode == mode,
                              onTap: () => ThemeController.to.setMode(m.mode),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spins in when picked.
              TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: selected ? -0.5 : 0, end: 0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, turns, child) => Transform.rotate(
                  angle: turns * 2 * math.pi,
                  child: child,
                ),
                child: Icon(icon, size: 21, color: fg),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.label.copyWith(
                  color: fg,
                  letterSpacing: 0,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _danger : AppColors.ink;

    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: danger ? _danger.withValues(alpha: 0.07) : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: danger ? _danger.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: danger ? _danger.withValues(alpha: 0.14) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _danger),
                      )
                    : Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.buttonLabel.copyWith(color: color, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: danger ? _danger : AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: 0.85,
            child: Image.asset('assets/Applogo.png', width: 34, height: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: AppTextStyles.headingSm.copyWith(color: AppColors.muted, fontSize: 14),
            children: [
              const TextSpan(text: 'Move'),
              TextSpan(text: 'Me', style: TextStyle(color: AppColors.yellow)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Scan. Message. Move on.',
          style: AppTextStyles.caption.copyWith(color: AppColors.faint),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

/// Skeleton in the page's own shape, instead of a bare spinner.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    Widget card(double height) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        children: [
          const Align(alignment: Alignment.centerLeft, child: ShimmerBox(width: 110, height: 26)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                ShimmerBox(width: 76, height: 76, radius: 38),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 18),
                      SizedBox(height: 10),
                      ShimmerBox(width: 110, height: 22, radius: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          card(170),
          const SizedBox(height: 14),
          card(190),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How should we reach you?
// ---------------------------------------------------------------------------

class _ReachPreferenceCard extends StatelessWidget {
  const _ReachPreferenceCard({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      icon: Icons.notifications_active_outlined,
      title: 'How should we reach you?',
      spacing: 10,
      children: [
        Obx(() {
          final selected = controller.communicationPreference.value;
          return Column(
            children: [
              _ReachOption(
                icon: Icons.phone_iphone_rounded,
                title: 'In this app',
                subtitle: 'Push notifications when someone messages you (recommended)',
                selected: selected == 'app',
                onTap: () => controller.setCommunicationPreference('app'),
              ),
              const SizedBox(height: 10),
              _ReachOption(
                icon: Icons.link_rounded,
                title: 'On the web link',
                subtitle: "For when you'd rather not keep the app installed",
                selected: selected == 'web',
                onTap: () => controller.setCommunicationPreference('web'),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _ReachOption extends StatelessWidget {
  const _ReachOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? accent : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.buttonLabel.copyWith(color: AppColors.ink, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? accent : AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

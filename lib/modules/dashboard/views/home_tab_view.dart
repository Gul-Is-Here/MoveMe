import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/bound_view.dart';
import '../../../app/widgets/dot_grid_background.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/shimmer.dart';
import '../../../app/widgets/viewfinder_painter.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/home_tab_controller.dart';
import '../models/vehicle_model.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_qr_thumb.dart';

/// Home: who you are, the one thing you come here to do (scan a sticker to
/// message a car's owner), a live glance at your vehicles and unread
/// messages, and the vehicles you own.
///
/// Every value shown comes from the existing controller — the resident's
/// first name, their vehicle documents, and the unread state the Inbox tab
/// is already listening to. Nothing on this screen is generated.
class HomeTabView extends BoundView<HomeTabController> {
  const HomeTabView({super.key});

  @override
  Widget buildWith(BuildContext context, HomeTabController controller) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      color: AppColors.yellow,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        // Always scrollable so pull-to-refresh still works on the empty
        // and error states, which are shorter than the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverToBoxAdapter(
              child: RiseIn(order: 0, child: _Header(controller: controller)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            sliver: SliverToBoxAdapter(
              child: RiseIn(
                order: 1,
                child: _ScanHeroCard(
                  onTap: () => Get.toNamed(AppRoutes.qrScanner),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            sliver: SliverToBoxAdapter(
              child: RiseIn(order: 2, child: _StatsRow(controller: controller)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
            sliver: SliverToBoxAdapter(
              child: RiseIn(
                order: 3,
                child: _SectionHeader(controller: controller),
              ),
            ),
          ),
          SliverPadding(
            // The bottom inset clears the floating nav dock, which the
            // dashboard lets content scroll behind.
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: Obx(() {
              if (controller.hasError.value) {
                return SliverToBoxAdapter(
                  child: _ErrorState(controller: controller),
                );
              }
              if (controller.isLoading.value) {
                return const SliverToBoxAdapter(child: _VehiclesSkeleton());
              }

              final vehicles = controller.vehicles;
              if (vehicles.isEmpty) {
                return SliverToBoxAdapter(
                  child: RiseIn(
                    order: 4,
                    child: _EmptyState(controller: controller),
                  ),
                );
              }

              return SliverList.separated(
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => RiseIn(
                  key: ValueKey(vehicles[index].id),
                  order: 4 + index.clamp(0, 5),
                  child: Pressable(
                    child: _ReactiveVehicleCard(
                      controller: controller,
                      vehicle: vehicles[index],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Switches the dashboard tab, when Home is mounted inside the dashboard.
void _goToTab(int index) {
  if (Get.isRegistered<DashboardController>()) {
    Get.find<DashboardController>().changeTab(index);
  }
}

/// Only the unread dot reacts here, so a new message repaints one card
/// rather than the whole list.
class _ReactiveVehicleCard extends StatelessWidget {
  const _ReactiveVehicleCard({required this.controller, required this.vehicle});

  final HomeTabController controller;
  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasUnreadSource) return VehicleCard(vehicle: vehicle);
    return Obx(
      () => VehicleCard(
        vehicle: vehicle,
        hasUnread: controller.hasUnreadFor(vehicle.id),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_greetingIcon, size: 15, color: AppColors.yellow),
                  const SizedBox(width: 6),
                  Text(
                    controller.greeting,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  controller.residentFirstName.value.isEmpty
                      ? 'there'
                      : controller.residentFirstName.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingLg.copyWith(
                    color: AppColors.ink,
                    fontSize: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Obx(() => _Avatar(name: controller.residentFirstName.value)),
      ],
    );
  }

  IconData get _greetingIcon {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.wb_cloudy_outlined;
    return Icons.nightlight_outlined;
  }
}

/// The resident's initial on an accent gradient; opens the Profile tab.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final hasName = name.isNotEmpty && name != 'there';

    return Semantics(
      button: true,
      label: 'Open profile',
      child: Pressable(
        onTap: () => _goToTab(2),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, _deepen(accent)],
              ),
            ),
            child: Center(
              child: hasName
                  ? Text(
                      name.characters.first.toUpperCase(),
                      style: AppTextStyles.headingSm.copyWith(
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan hero
// ---------------------------------------------------------------------------

/// The primary action as a card: "blocked in? scan their sticker". A live
/// viewfinder on the right sweeps a scan line over a QR glyph on loop.
class _ScanHeroCard extends StatefulWidget {
  const _ScanHeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ScanHeroCard> createState() => _ScanHeroCardState();
}

class _ScanHeroCardState extends State<_ScanHeroCard>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // A few sweeps to draw the eye, then rest — no endless animation
    // burning battery on the app's most-visited screen.
    if (!MediaQuery.of(context).disableAnimations) _loop.repeat(count: 3);
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Semantics(
      button: true,
      label: 'Scan a vehicle QR code to message its owner',
      child: Pressable(
        scale: 0.98,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, _deepen(accent, 0.14)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DotGridBackground(
                  color: Colors.white,
                  center: Alignment(0.9, -0.2),
                  radius: 1.1,
                ),
              ),
              Positioned(
                right: -50,
                top: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                right: 22,
                top: 0,
                bottom: 0,
                child: Center(
                  child: ExcludeSemantics(child: _LiveScanGlyph(loop: _loop)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 128, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SCAN & MESSAGE',
                        style: AppTextStyles.overline.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Blocked in?',
                      style: AppTextStyles.headingLg.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Scan the car's MoveMe sticker to message its owner, privately.",
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scan QR',
                            style: AppTextStyles.label.copyWith(
                              color: accent,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }
}

class _LiveScanGlyph extends StatelessWidget {
  const _LiveScanGlyph({required this.loop});

  final Animation<double> loop;

  static const _size = 88.0;
  static const _inner = 12.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final v = loop.value;
        final scanning = loop.isAnimating;
        // Down and back up, easing at both ends.
        final sweep = (1 - math.cos(v * 2 * math.pi)) / 2;
        final breathe = 2.5 * math.sin(v * 2 * math.pi);

        return SizedBox.square(
          dimension: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size.square(_size),
                painter: ViewfinderPainter(
                  gap: breathe,
                  color: Colors.white,
                  arm: 18,
                  radius: 9,
                  strokeWidth: 3,
                ),
              ),
              Center(
                child: CustomPaint(
                  size: const Size.square(46),
                  painter: QrGlyphPainter(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              if (scanning)
                Positioned(
                  left: _inner - 4,
                  right: _inner - 4,
                  top: _inner + sweep * (_size - _inner * 2) - 1,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white,
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.7),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.controller});

  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Obx(
            () => _StatTile(
              icon: Icons.directions_car_filled_rounded,
              label: 'Vehicles',
              value: controller.isLoading.value || controller.hasError.value
                  ? null
                  : controller.vehicles.length,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: controller.hasUnreadSource
              ? Obx(() => _unreadTile(controller.unreadCount))
              : _unreadTile(0),
        ),
      ],
    );
  }

  Widget _unreadTile(int count) => _StatTile(
    icon: Icons.mark_chat_unread_rounded,
    label: count == 1 ? 'Unread message' : 'Unread messages',
    value: count,
    highlight: count > 0,
    onTap: () => _goToTab(1),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null while the number isn't known yet (loading or errored).
  final int? value;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? accent.withValues(alpha: 0.5) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? accent.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value == null
                    ? Text('–', style: _valueStyle)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: value!.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) =>
                            Text('${v.round()}', style: _valueStyle),
                      ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
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

  TextStyle get _valueStyle => AppTextStyles.headingLg.copyWith(
    color: AppColors.ink,
    fontSize: 22,
    height: 1.15,
  );
}

// ---------------------------------------------------------------------------
// Vehicles section
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.controller});

  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your vehicles',
                style: AppTextStyles.headingSm.copyWith(
                  color: AppColors.ink,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Obx(() {
                if (controller.isLoading.value || controller.hasError.value) {
                  return const SizedBox(height: 16);
                }
                final count = controller.vehicles.length;
                return SizedBox(
                  height: 16,
                  child: Text(
                    count == 0
                        ? 'Each vehicle gets its own QR sticker'
                        : '$count vehicle${count == 1 ? '' : 's'} · tap one for its QR code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AddVehicleButton(onTap: controller.addVehicle),
      ],
    );
  }
}

class _AddVehicleButton extends StatelessWidget {
  const _AddVehicleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Semantics(
      button: true,
      label: 'Add a vehicle',
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 17, color: accent),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: AppTextStyles.label.copyWith(
                  color: accent,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors [VehicleCard]'s geometry exactly — same radius, same 14px
/// padding, same 56px thumb — so the real cards drop in without the list
/// shifting.
class _VehiclesSkeleton extends StatelessWidget {
  const _VehiclesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const ShimmerBox(width: 56, height: 56, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerBox(width: 130, height: 15),
                        const SizedBox(height: 7),
                        const ShimmerBox(width: 92, height: 12),
                        const SizedBox(height: 11),
                        const ShimmerBox(width: 104, height: 22, radius: 9),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const ShimmerBox(width: 52, height: 52, radius: 12),
                ],
              ),
            ),
            if (i != 2) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return HomeStateBlock(
      icon: Icons.directions_car_filled_outlined,
      title: 'No vehicles yet',
      subtitle:
          'Add your first vehicle and MoveMe generates a QR sticker for it. '
          'Anyone who scans it can message you without seeing your number.',
      action: _AddVehicleButton(onTap: controller.addVehicle),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.controller});

  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return HomeStateBlock(
      icon: Icons.wifi_off_rounded,
      title: 'Something went wrong',
      subtitle:
          "We couldn't load your vehicles. Check your connection and try again.",
      action: Semantics(
        button: true,
        child: Material(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: controller.reload,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Try again',
                style: AppTextStyles.buttonLabel.copyWith(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motion helpers
// ---------------------------------------------------------------------------

/// Darker shade of [color] for the far end of accent gradients.
Color _deepen(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

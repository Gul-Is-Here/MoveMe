import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/app_snackbar.dart';
import '../../../app/widgets/dot_grid_background.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/viewfinder_painter.dart';
import '../../dashboard/models/vehicle_model.dart';
import '../../vehicle/widgets/form_section_card.dart';
import '../controllers/vehicle_details_controller.dart';
import '../widgets/number_plate.dart';

const _danger = Color(0xFFE5675E);

class VehicleDetailsView extends GetView<VehicleDetailsController> {
  const VehicleDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    // Reactive: editing this vehicle pops back into this same screen with
    // the updated data (see VehicleDetailsController.editVehicle) instead
    // of pushing a fresh copy of it, so this needs to rebuild in place.
    return Obx(() => _buildContent(context, controller.vehicle));
  }

  Widget _buildContent(BuildContext context, VehicleModel vehicle) {
    // Vehicles added without a nickname store the plate as one — show the
    // make/model as the title then, so the plate isn't printed twice.
    final nicknameIsPlate = vehicle.nickname.trim().toUpperCase() ==
        vehicle.plateNumber.trim().toUpperCase();
    final title = nicknameIsPlate && vehicle.makeModel.isNotEmpty
        ? vehicle.makeModel
        : vehicle.nickname;
    final subtitle = [
      if (!nicknameIsPlate || vehicle.makeModel.isEmpty) vehicle.makeModel,
      vehicle.colorName,
    ].where((s) => s.trim().isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _CircleButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: Get.back),
                  Expanded(
                    child: Text(
                      'Vehicle Details',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 17),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit vehicle',
                    iconColor: AppColors.yellow,
                    onTap: controller.editVehicle,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Hero with the plate overlapping its bottom edge.
              RiseIn(
                order: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Hero(vehicle: vehicle, title: title, subtitle: subtitle),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -29,
                      child: Center(child: NumberPlate(plate: vehicle.plateNumber)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),

              RiseIn(order: 1, child: _QrCard(controller: controller, vehicle: vehicle)),
              const SizedBox(height: 12),
              RiseIn(order: 2, child: _ShareButton(controller: controller)),
              const SizedBox(height: 18),

              RiseIn(order: 3, child: _InfoSection(vehicle: vehicle)),
              const SizedBox(height: 24),

              RiseIn(
                order: 4,
                child: _ActionButton(
                  label: 'Edit Vehicle',
                  icon: Icons.edit_outlined,
                  primary: true,
                  onTap: controller.editVehicle,
                ),
              ),
              const SizedBox(height: 12),
              RiseIn(
                order: 5,
                child: _ActionButton(
                  label: 'Remove Vehicle',
                  icon: Icons.delete_outline_rounded,
                  onTap: controller.removeVehicle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 19, color: iconColor ?? AppColors.ink),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// Swipeable vehicle photos (or an accent placeholder when there are none)
/// with the vehicle's name over a bottom scrim.
class _Hero extends StatefulWidget {
  const _Hero({required this.vehicle, required this.title, required this.subtitle});

  final VehicleModel vehicle;
  final String title;
  final String subtitle;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.vehicle.photoPaths;
    final accent = AppColors.yellow;

    return AspectRatio(
      aspectRatio: 16 / 11,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photos.isEmpty)
                _PlaceholderHero(accent: accent)
              else
                PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _photo(photos[i]),
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Colors.transparent, Color(0xB3000000)],
                      stops: [0, 0.35, 1],
                    ),
                  ),
                ),
              ),
              if (photos.length > 1)
                Positioned(
                  top: 14,
                  right: 14,
                  child: _PageDots(count: photos.length, index: _page),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 42,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headingLg.copyWith(color: Colors.white, fontSize: 26),
                      ),
                      if (widget.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (widget.vehicle.colorName.isNotEmpty) ...[
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: widget.vehicle.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                              child: Text(
                                widget.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(String path) {
    final fallback = _PlaceholderHero(accent: AppColors.yellow);
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    }
    return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

class _PlaceholderHero extends StatelessWidget {
  const _PlaceholderHero({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, AppColors.accentDeep],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DotGridBackground(color: Colors.white, center: Alignment(0.6, -0.4), radius: 1.1),
          Align(
            alignment: const Alignment(0.75, -0.35),
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: i == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == index ? 1 : 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR card
// ---------------------------------------------------------------------------

/// The shareable QR card (captured as an image by [shareQrCode]). The code
/// is always dark-on-white — inverted QR codes fail on many scanners — with
/// the app logo in the middle (high error correction keeps it scannable).
/// A scan line sweeps it twice on arrival, then rests.
class _QrCard extends StatefulWidget {
  const _QrCard({required this.controller, required this.vehicle});

  final VehicleDetailsController controller;
  final VehicleModel vehicle;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  static const _qrSize = 168.0;
  static const _qrInk = Color(0xFF16161A);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _sweep.repeat(count: 2);
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final wordmark = AppTextStyles.headingSm.copyWith(color: AppColors.ink, fontSize: 16);

    return RepaintBoundary(
      key: widget.controller.qrBoundaryKey,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/Applogo.png', width: 22, height: 22),
                ),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    style: wordmark,
                    children: [
                      const TextSpan(text: 'Move'),
                      TextSpan(text: 'Me', style: TextStyle(color: accent)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.success,
                          fontSize: 11,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox.square(
              dimension: _qrSize + 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ViewfinderPainter(
                        gap: -2,
                        color: accent,
                        arm: 26,
                        radius: 14,
                        strokeWidth: 3.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: widget.vehicle.qrScanUrl,
                      size: _qrSize,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: _qrInk),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: _qrInk,
                      ),
                      embeddedImage: const AssetImage('assets/Applogo.png'),
                      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(34, 34)),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      if (!_sweep.isAnimating) return const SizedBox.shrink();
                      final t = Curves.easeInOutSine.transform(_sweep.value);
                      return Positioned(
                        left: 18,
                        right: 18,
                        top: 22 + t * _qrSize - 1,
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.8),
                                blurRadius: 12,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'SCAN TO VERIFY VEHICLE',
              style: AppTextStyles.label.copyWith(
                color: accent,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Show this to the parking attendant',
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.controller});

  final VehicleDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;

    return Obx(() {
      final sharing = controller.isSharing.value;
      return Semantics(
        button: true,
        child: Pressable(
          onTap: sharing ? null : controller.shareQrCode,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: sharing
                      ? SizedBox(
                          key: const ValueKey('busy'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                        )
                      : Icon(Icons.ios_share_rounded, key: const ValueKey('idle'), size: 17, color: accent),
                ),
                const SizedBox(width: 9),
                Text(
                  'Share QR Code',
                  style: AppTextStyles.buttonLabel.copyWith(color: accent, fontSize: 14.5),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Information
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.vehicle});

  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    final half = <Widget>[
      _InfoTile(
        icon: Icons.directions_car_outlined,
        label: 'Make & Model',
        value: vehicle.makeModel,
      ),
      if (vehicle.colorName.isNotEmpty)
        _InfoTile(
          icon: Icons.palette_outlined,
          label: 'Color',
          value: vehicle.colorName,
          swatch: vehicle.color,
        ),
      if (vehicle.dateOfRegistration.isNotEmpty)
        _InfoTile(
          icon: Icons.event_outlined,
          label: 'Date of registration',
          value: vehicle.dateOfRegistration,
        ),
    ];

    return FormSectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Vehicle information',
      spacing: 10,
      children: [
        // Short values pair up two per row; long ones get the full width.
        for (var i = 0; i < half.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: half[i]),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < half.length ? half[i + 1] : const SizedBox()),
              ],
            ),
          ),
        if (vehicle.engineNumber.isNotEmpty)
          _InfoTile(
            icon: Icons.settings_outlined,
            label: 'Engine number',
            value: vehicle.engineNumber,
            copyable: true,
          ),
        if (vehicle.chassisNumber.isNotEmpty)
          _InfoTile(
            icon: Icons.qr_code_2_rounded,
            label: 'Chassis number',
            value: vehicle.chassisNumber,
            copyable: true,
          ),
        if (vehicle.address.isNotEmpty)
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Registered address',
            value: vehicle.address,
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.swatch,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? swatch;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 13, color: AppColors.faint),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (swatch != null) ...[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: swatch,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        style: AppTextStyles.fieldValue.copyWith(
                          color: AppColors.ink,
                          fontSize: 14,
                          letterSpacing: copyable ? 0.6 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (copyable)
            Semantics(
              button: true,
              label: 'Copy $label',
              child: Pressable(
                scale: 0.85,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  HapticFeedback.lightImpact();
                  AppSnackbar.show('Copied', '$label copied to clipboard.');
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Icons.copy_rounded, size: 15, color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final fg = primary ? Colors.white : _danger;

    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: primary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, AppColors.accentDeep],
                  )
                : null,
            color: primary ? null : _danger.withValues(alpha: 0.08),
            border: primary ? null : Border.all(color: _danger.withValues(alpha: 0.35)),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label, style: AppTextStyles.buttonLabel.copyWith(color: fg, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

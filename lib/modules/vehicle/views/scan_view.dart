import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/widgets/motion.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../controllers/scan_controller.dart';
import '../widgets/add_vehicle_top_bar.dart';
import '../widgets/rc_card_illustration.dart';
import '../widgets/vehicle_photo_tile.dart';

/// 3.18mm (the standard ID-card corner radius) converted to logical
/// pixels at 96dpi (1mm ≈ 3.7795px) — ≈12.02.
const _cardCornerRadius = 3.18 * 3.7795275591;

/// Launcher for ML Kit's Document Scanner — Google's flow runs fullscreen
/// on top of this screen. Flow: choose to scan or enter manually -> if
/// scanning, capture the RC card's front then back (CNIC-style two-box
/// layout) -> Next hands both images to Review, which OCRs and merges
/// them to fill the form.
class ScanView extends GetView<ScanController> {
  const ScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _TopGlow(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Obx(() {
                    final choosing = controller.isChoosing.value;
                    return AddVehicleTopBar(
                      step: choosing ? 0 : 1,
                      leadingIcon: choosing ? Icons.close_rounded : Icons.arrow_back_rounded,
                      leadingLabel: choosing ? 'Close' : 'Back',
                      onLeading: choosing ? Get.back : controller.backToChoice,
                    );
                  }),
                ),
                Expanded(
                  child: Obx(() {
                    final choosing = controller.isChoosing.value;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(child.key == const ValueKey('choice') ? -0.06 : 0.06, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: choosing
                          ? _ChoiceState(
                              key: const ValueKey('choice'),
                              isScannerUnavailable: controller.isScannerUnavailable.value,
                              onScan: controller.startScanning,
                              onEnterManually: controller.enterManually,
                            )
                          : _CaptureState(
                              key: const ValueKey('capture'),
                              frontImagePath: controller.frontImagePath.value,
                              backImagePath: controller.backImagePath.value,
                              isLaunching: controller.isLaunching.value,
                              errorMessage: controller.errorMessage.value,
                              isScannerUnavailable: controller.isScannerUnavailable.value,
                              onCaptureFront: () => _capture(RcCardSide.front),
                              onCaptureBack: () => _capture(RcCardSide.back),
                              onRemoveFront: () => controller.removeSide(RcCardSide.front),
                              onRemoveBack: () => controller.removeSide(RcCardSide.back),
                              onNext: controller.next,
                              onEnterManually: controller.enterManually,
                            ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _capture(RcCardSide side) {
    if (controller.isScannerUnavailable.value) {
      controller.pickSideFromGallery(side);
    } else {
      controller.scanSide(side);
    }
  }
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 420,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 0.8,
              colors: [
                AppColors.yellow.withValues(alpha: 0.13),
                AppColors.yellow.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable page body. Short content is centered vertically when
/// [center] is set; [bottom] (the primary action) stays pinned below the
/// scroll area so it's always reachable.
class _ScrollBody extends StatelessWidget {
  const _ScrollBody({required this.children, this.bottom, this.center = false});

  final List<Widget> children;
  final Widget? bottom;
  final bool center;

  static const _padding = EdgeInsets.fromLTRB(24, 12, 24, 24);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: _padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - _padding.vertical).clamp(0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
        if (bottom != null)
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: bottom),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 26);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: Text(title, textAlign: TextAlign.center, style: style)),
            Text('.', style: style.copyWith(color: AppColors.yellow)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 13.5),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — choose how to add the vehicle
// ---------------------------------------------------------------------------

class _ChoiceState extends StatelessWidget {
  const _ChoiceState({
    super.key,
    required this.isScannerUnavailable,
    required this.onScan,
    required this.onEnterManually,
  });

  final bool isScannerUnavailable;
  final VoidCallback onScan;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    return _ScrollBody(
      center: true,
      children: [
        const RiseIn(order: 0, child: Center(child: RcCardIllustration(width: 210))),
        const SizedBox(height: 18),
        const RiseIn(
          order: 1,
          child: _Title(
            title: 'Add your vehicle',
            subtitle: 'Scan the RC card to fill the details automatically, or enter them yourself.',
          ),
        ),
        const SizedBox(height: 28),
        RiseIn(
          order: 2,
          child: _OptionCard(
            primary: true,
            icon: Icons.document_scanner_outlined,
            title: 'Scan the document',
            subtitle: isScannerUnavailable
                ? 'Add photos of the front and back of the RC card'
                : 'Scan the front and back of the RC card',
            badge: 'AUTO-FILL',
            onTap: onScan,
          ),
        ),
        const SizedBox(height: 14),
        RiseIn(
          order: 3,
          child: _OptionCard(
            icon: Icons.edit_note_rounded,
            title: 'Enter manual details',
            subtitle: 'Fill in the vehicle details yourself',
            onTap: onEnterManually,
          ),
        ),
        const SizedBox(height: 24),
        RiseIn(
          order: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: AppColors.faint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Every detail stays editable before you save.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.faint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final fg = primary ? Colors.white : AppColors.ink;
    final fgMuted = primary ? Colors.white.withValues(alpha: 0.85) : AppColors.muted;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: primary ? null : AppColors.surface,
              gradient: primary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, AppColors.accentDeep],
                    )
                  : null,
              border: primary ? null : Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: primary
                      ? accent.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: primary ? 24 : 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.18)
                        : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: primary ? Colors.white : accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.headingSm.copyWith(color: fg, fontSize: 16),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: primary ? 0.22 : 0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: AppTextStyles.overline.copyWith(
                                  color: fg,
                                  fontSize: 8.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.subtitle.copyWith(
                          color: fgMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.background,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: primary ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — capture the front and back
// ---------------------------------------------------------------------------

class _CaptureState extends StatelessWidget {
  const _CaptureState({
    super.key,
    required this.frontImagePath,
    required this.backImagePath,
    required this.isLaunching,
    required this.errorMessage,
    required this.isScannerUnavailable,
    required this.onCaptureFront,
    required this.onCaptureBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
    required this.onNext,
    required this.onEnterManually,
  });

  final String? frontImagePath;
  final String? backImagePath;
  final bool isLaunching;
  final String? errorMessage;
  final bool isScannerUnavailable;
  final VoidCallback onCaptureFront;
  final VoidCallback onCaptureBack;
  final VoidCallback onRemoveFront;
  final VoidCallback onRemoveBack;
  final VoidCallback onNext;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final hasBoth = frontImagePath != null && backImagePath != null;
    final captured = [frontImagePath, backImagePath].where((p) => p != null).length;
    final emptyIcon = isScannerUnavailable
        ? Icons.add_photo_alternate_outlined
        : Icons.document_scanner_outlined;
    final emptyLabel = isScannerUnavailable ? 'Tap to add a photo' : 'Tap to scan';

    return _ScrollBody(
      bottom: RiseIn(
        order: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(label: 'Next', onPressed: hasBoth ? onNext : null),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: onEnterManually,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Enter details manually',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.linkTextEmphasis.copyWith(color: AppColors.yellow),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        RiseIn(
          order: 0,
          child: _Title(
            title: 'Scan the RC card',
            subtitle: isScannerUnavailable
                ? 'Add a photo of the front, then the back.'
                : 'Scan the front, then the back — just like scanning a CNIC.',
          ),
        ),
        const SizedBox(height: 16),
        RiseIn(order: 1, child: Center(child: _CaptureProgress(captured: captured))),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: errorMessage == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _ErrorBanner(message: errorMessage!),
                ),
        ),
        const SizedBox(height: 20),
        RiseIn(
          order: 2,
          child: _SideSlot(
            number: 1,
            label: 'Front side',
            imagePath: frontImagePath,
            emptyIcon: emptyIcon,
            emptyLabel: emptyLabel,
            onCapture: onCaptureFront,
            onRemove: onRemoveFront,
          ),
        ),
        const SizedBox(height: 18),
        RiseIn(
          order: 3,
          child: _SideSlot(
            number: 2,
            label: 'Back side',
            imagePath: backImagePath,
            emptyIcon: emptyIcon,
            emptyLabel: emptyLabel,
            onCapture: onCaptureBack,
            onRemove: onRemoveBack,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: isLaunching
              ? Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.yellow,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Opening scanner…',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// "1 of 2 sides captured" with two dots that fill as each side lands.
class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.captured});

  final int captured;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final done = captured == 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (done ? AppColors.success : accent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: i < captured ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i < captured
                    ? (done ? AppColors.success : accent)
                    : AppColors.faint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              done ? 'Both sides captured' : '$captured of 2 sides captured',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppTextStyles.label.copyWith(
                color: done ? AppColors.success : accent,
                letterSpacing: 0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideSlot extends StatelessWidget {
  const _SideSlot({
    required this.number,
    required this.label,
    required this.imagePath,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.onCapture,
    required this.onRemove,
  });

  final int number;
  final String label;
  final String? imagePath;
  final IconData emptyIcon;
  final String emptyLabel;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.yellow;
    final done = imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.success : accent.withValues(alpha: 0.14),
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : Text(
                      '$number',
                      style: AppTextStyles.label.copyWith(
                        color: accent,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 9),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.label.copyWith(color: AppColors.ink),
            ),
            const Spacer(),
            if (done)
              GestureDetector(
                onTap: onCapture,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 15, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Retake',
                      style: AppTextStyles.label.copyWith(
                        color: accent,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        VehiclePhotoTile(
          label: done ? label : emptyLabel,
          imagePath: imagePath,
          onTap: onCapture,
          onRemove: done ? onRemove : null,
          emptyIcon: emptyIcon,
          // CR80 ID-card proportions (85.6mm x 53.98mm) and radius — the
          // RC card is scanned in the same shape it actually is.
          aspectRatio: 1.586,
          borderRadius: _cardCornerRadius,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const red = Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.subtitle.copyWith(color: red, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

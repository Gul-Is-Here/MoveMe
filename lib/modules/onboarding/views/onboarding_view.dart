import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../controllers/onboarding_controller.dart';
import '../models/onboarding_page_data.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_illustrations.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  static final _pages = [
    OnboardingPageData(
      headline: 'Put a tag on\nyour car',
      body: "Register your vehicle and order your MoveMe QR sticker. Stick it on your windshield — it's all anyone needs to reach you.",
      illustrationBuilder: (_) => const TagCarIllustration(),
    ),
    OnboardingPageData(
      headline: 'Get notified,\nnever exposed',
      body: 'Anyone blocked in can scan your sticker and send you a message instantly. Your phone number is never shown to anyone.',
      illustrationBuilder: (_) => const NotifiedIllustration(),
    ),
    OnboardingPageData(
      headline: 'Chat, resolve,\nmove on',
      body: "Reply right from the app, mark the issue resolved when you're done, and get back to your day — no notes on windshields.",
      illustrationBuilder: (_) => const ResolveIllustration(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => OnboardingDots(count: OnboardingController.pageCount, index: controller.currentPage.value)),
                  Obx(
                    () => GestureDetector(
                      onTap: controller.skip,
                      child: Opacity(
                        opacity: controller.isLastPage ? 0 : 1,
                        child: Text('Skip', style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 13.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) => _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Obx(
                () => GestureDetector(
                  onTap: controller.next,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.isLastPage ? 'Get Started' : 'Next',
                          style: AppTextStyles.buttonLabel.copyWith(color: AppColors.background, fontSize: 15.5),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.background),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          data.illustrationBuilder(context),
          const SizedBox(height: 32),
          Text(
            data.headline,
            style: AppTextStyles.headingLg.copyWith(color: AppColors.ink, fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.muted, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

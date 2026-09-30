import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_button.dart';
import '../../data/providers/repository_providers.dart';
import 'widgets/onboarding_page.dart';

/// Minimal 3-page onboarding experience with dot indicators, Skip, and Get Started buttons.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Intelligent Conversations',
      description:
          'Chat naturally with an ultra-responsive AI assistant built for clarity, speed, and real-time streaming.',
    ),
    OnboardingPageData(
      icon: Icons.terminal_rounded,
      title: 'Markdown & Code Native',
      description:
          'Beautiful formatted text, syntax-styled code blocks with one-tap copy, and rich structured lists.',
    ),
    OnboardingPageData(
      icon: Icons.tune_rounded,
      title: 'Minimal & Private',
      description:
          'Zero visual clutter, no distracting gradients, and full local persistence across app sessions.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final storage = ref.read(localStorageProvider);
    await storage.setOnboardingCompleted(true);
    if (!mounted) return;
    context.go(AppRoutes.authPath);
  }

  void _onNext() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.standard,
        curve: AppDurations.defaultCurve,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLastPage = _currentIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip',
                style: AppTextStyles.button.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return OnboardingPageView(data: _pages[index]);
                },
              ),
            ),
            // Bottom control row: Dots indicator & Action button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // Dot indicator (solid colors only)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentIndex;
                      return AnimatedContainer(
                        duration: AppDurations.quick,
                        curve: AppDurations.defaultCurve,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                        width: isActive ? 24.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: isActive ? colors.primary : colors.border,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    text: isLastPage ? 'Get Started' : 'Next',
                    icon: isLastPage ? Icons.arrow_forward_rounded : null,
                    onPressed: _onNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

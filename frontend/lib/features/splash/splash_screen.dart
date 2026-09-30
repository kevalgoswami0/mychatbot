import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../data/providers/repository_providers.dart';

/// Minimal, elegant splash screen with solid color background and subtle wordmark fade-in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.medium,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: AppDurations.defaultCurve,
      ),
    );

    _animController.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Wait for smooth splash presentation
    await Future.delayed(AppDurations.splash);
    if (!mounted) return;

    final storage = ref.read(localStorageProvider);
    final onboardingDone = storage.isOnboardingCompleted();
    final user = storage.loadUserProfile();

    if (!onboardingDone) {
      context.go(AppRoutes.onboardingPath);
    } else if (user == null) {
      context.go(AppRoutes.authPath);
    } else {
      context.go(AppRoutes.chatPath);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimal solid logo badge (NO gradients)
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 34,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.display.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppConstants.appTagline,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
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

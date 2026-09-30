import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import 'widgets/login_form.dart';
import 'widgets/signup_form.dart';

/// Authentication screen supporting Login, Signup, and Guest mode.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;

  void _onAuthSuccess() {
    context.go(AppRoutes.chatPath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimal solid logo icon (NO gradients)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _isLogin ? 'Welcome back' : 'Create an account',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isLogin
                      ? 'Sign in to access your conversations with ${AppConstants.appName}.'
                      : 'Join ${AppConstants.appName} for fast, intelligent assistance.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Flat segmented switch between Sign In and Sign Up
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          title: 'Sign In',
                          isSelected: _isLogin,
                          onTap: () => setState(() => _isLogin = true),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          title: 'Sign Up',
                          isSelected: !_isLogin,
                          onTap: () => setState(() => _isLogin = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Form
                if (_isLogin)
                  LoginForm(onSuccess: _onAuthSuccess)
                else
                  SignupForm(onSuccess: _onAuthSuccess),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: isSelected ? Border.all(color: colors.border, width: 1) : null,
        ),
        child: Text(
          title,
          style: AppTextStyles.button.copyWith(
            color: isSelected ? colors.textPrimary : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

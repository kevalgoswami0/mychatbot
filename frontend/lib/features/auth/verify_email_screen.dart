import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import 'providers/auth_provider.dart';

/// Screen for verifying email OTP after sign up.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.email,
  });

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _inlineError;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    context.hideKeyboard();
    setState(() => _inlineError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final message = await ref.read(authProvider.notifier).verifyEmail(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isNotEmpty ? message : 'Email verified successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to Home screen
      context.go(AppRoutes.chatPath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.authPath);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 26,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Header
                  Text(
                    'Verify your email',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _emailController.text.isNotEmpty
                        ? 'We sent a 6-digit verification code to ${_emailController.text}. Enter it below to activate your account.'
                        : 'Enter your email address and the 6-digit verification code sent to your inbox.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Inline error alert
                  if (_inlineError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: colors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: colors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Email Field (Editable if needed)
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icon(Icons.email_outlined, size: 20, color: colors.textSecondary),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email.';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // OTP Field
                  AppTextField(
                    controller: _otpController,
                    label: '6-digit Verification Code',
                    hint: '123456',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(),
                    prefixIcon: Icon(Icons.pin_outlined, size: 20, color: colors.textSecondary),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the verification code.';
                      }
                      if (value.trim().length < 6) {
                        return 'OTP must be 6 digits.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Verify button
                  AppButton(
                    text: 'Verify Email',
                    isLoading: _isLoading,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Resend code row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                      ),
                      if (_resendCooldown > 0)
                        Text(
                          'Resend in ${_resendCooldown}s',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            _startCooldownTimer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('If registered, a new code will be delivered to your email.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Resend Code',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Return to sign in
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(AppRoutes.authPath),
                      icon: Icon(Icons.arrow_back_rounded, size: 16, color: colors.textSecondary),
                      label: Text(
                        'Back to Sign In',
                        style: AppTextStyles.button.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

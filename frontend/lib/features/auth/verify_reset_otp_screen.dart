import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import 'providers/auth_provider.dart';

/// Screen for verifying OTP sent to email during password recovery.
/// On successful verification, receives a reset_token and navigates to ResetPasswordScreen.
class VerifyResetOtpScreen extends ConsumerStatefulWidget {
  const VerifyResetOtpScreen({
    super.key,
    this.email,
  });

  final String? email;

  @override
  ConsumerState<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends ConsumerState<VerifyResetOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
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

  Future<void> _verifyOtp() async {
    context.hideKeyboard();
    setState(() => _inlineError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final otp = _otpController.text.trim();

      // Call verify-reset-otp API to get reset_token
      final resetToken = await ref.read(authProvider.notifier).verifyResetOtp(
            email: email,
            otp: otp,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP verified successfully! Now create your new password.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Move to Reset Password screen with the reset_token
      context.push(
        AppRoutes.resetPasswordPath,
        extra: {
          'resetToken': resetToken,
          'email': email,
        },
      );
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

  Future<void> _resendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _inlineError = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isResending = true;
      _inlineError = null;
    });

    try {
      final message = await ref.read(authProvider.notifier).forgotPassword(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
      _startCooldownTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
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
                  const SizedBox(height: AppSpacing.lg),

                  // Header title & subtitle
                  Text(
                    'Verify Reset Code',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'We sent a 6-digit verification OTP to your email. Enter it below to proceed with resetting your password.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Inline error banner if any
                  if (_inlineError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: AppTextStyles.caption.copyWith(
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

                  // Email field
                  AppTextField(
                    label: 'Email Address',
                    hint: 'name@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // OTP field
                  AppTextField(
                    label: '6-Digit Reset Code',
                    hint: '123456',
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.security_outlined, size: 20),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter the 6-digit code';
                      if (v.trim().length != 6) return 'Code must be exactly 6 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Verify button
                  AppButton(
                    text: 'Verify Code',
                    isLoading: _isLoading,
                    onPressed: _verifyOtp,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Resend OTP row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
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
                          onPressed: _isResending ? null : _resendOtp,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _isResending ? 'Sending...' : 'Resend Code',
                            style: AppTextStyles.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Back to Sign In
                  TextButton(
                    onPressed: () => context.go(AppRoutes.authPath),
                    child: Text(
                      'Back to Sign In',
                      style: AppTextStyles.button.copyWith(
                        color: colors.textSecondary,
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

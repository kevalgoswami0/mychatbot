import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/razorpay_service.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/subscription_plan.dart';
import '../auth/providers/auth_provider.dart';
import 'providers/subscription_provider.dart';

/// Minimalist, high-conversion Subscription Plans screen.
/// Directly connected to FastAPI backend plans, subscription status, and real Razorpay checkout.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int? _processingPlanId;

  Future<void> _handleSelectPlan(SubscriptionPlan plan) async {
    if (plan.price == 0) {
      context.showSnackBar('You are already on the Free tier.');
      return;
    }

    // 1. Ensure user is authenticated before purchasing
    final user = ref.read(authProvider).value;
    if (user == null || user.isGuest) {
      _showSignInRequiredDialog(context);
      return;
    }

    setState(() => _processingPlanId = plan.backendId);

    try {
      // 2. Create official Razorpay order on backend
      final order = await ref
          .read(userSubscriptionProvider.notifier)
          .createOrder(plan.backendId);

      if (!mounted) return;

      // 3. Launch official Razorpay standard checkout modal (showing QR, UPI, Card, Netbanking)
      await launchRazorpayWebCheckout(
        keyId: order.keyId,
        orderId: order.orderId,
        amountInRupees: order.amountInRupees,
        currency: order.currency,
        planName: plan.name,
        userName: user.name,
        userEmail: user.email,
        onSuccess: (paymentId, orderId, signature) async {
          try {
            // 4. Submit real Razorpay payment ID and cryptographic signature to backend for verification
            await ref.read(userSubscriptionProvider.notifier).verifyPayment(
                  razorpayPaymentId: paymentId,
                  razorpayOrderId: orderId,
                  razorpaySignature: signature,
                  planId: plan.backendId,
                );

            if (!mounted) return;
            setState(() => _processingPlanId = null);
            ref.read(userSubscriptionProvider.notifier).refresh();
            context.showSnackBar(
              'Payment verified! Your ${plan.name} subscription is now active.',
            );
          } catch (verifyErr) {
            if (!mounted) return;
            setState(() => _processingPlanId = null);
            context.showSnackBar(
              verifyErr.toString().replaceAll('Exception: ', ''),
              isError: true,
            );
          }
        },
        onFailure: (errorMsg) {
          if (!mounted) return;
          setState(() => _processingPlanId = null);
          final isCancel = errorMsg.toLowerCase().contains('cancel') ||
              errorMsg.toLowerCase().contains('closed') ||
              errorMsg.toLowerCase().contains('dismiss');

          context.showSnackBar(
            isCancel ? 'Payment cancelled' : 'Payment failed: $errorMsg',
            isError: !isCancel,
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _processingPlanId = null);
        context.showSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _showSignInRequiredDialog(BuildContext context) {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: colors.primary, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Sign In Required',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Please sign in or create an account before purchasing a subscription. This ensures your active plan is permanently attached to your account.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.loginPath);
            },
            child: const Text('Sign In / Sign Up', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final userSubAsync = ref.watch(userSubscriptionProvider);
    final plansAsync = ref.watch(plansListProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Subscriptions',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(userSubscriptionProvider.notifier).refresh();
            ref.invalidate(plansListProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Header Tagline
              Text(
                'Unlock Unlimited Intelligence',
                style: AppTextStyles.titleLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Power your workflow with Groq LLaMA 3.3, real-time WebSocket streaming, and extended context.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Active Subscription Card
              userSubAsync.when(
                data: (sub) => Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(Icons.verified_rounded, size: 22, color: colors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Current: ${sub.planName}',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sub.hasSubscription
                                        ? colors.success.withValues(alpha: 0.15)
                                        : colors.textSecondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                  child: Text(
                                    sub.hasSubscription ? 'ACTIVE' : 'FREE TIER',
                                    style: AppTextStyles.micro.copyWith(
                                      color: sub.hasSubscription ? colors.success : colors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub.endDate != null
                                  ? 'Valid until ${AppDateFormatters.formatDateDivider(sub.endDate!)}'
                                  : 'Initial 10-minute free trial session',
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Plans List
              plansAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Failed to load plans: $err', style: TextStyle(color: colors.error)),
                  ),
                ),
                data: (plans) {
                  final activePlanName = userSubAsync.value?.planName.toLowerCase() ?? 'free';

                  return Column(
                    children: plans.map((plan) {
                      final isCurrent = plan.name.toLowerCase() == activePlanName;
                      final isProcessing = _processingPlanId == plan.backendId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(
                              color: isCurrent
                                  ? colors.primary
                                  : (plan.isPopular ? colors.textPrimary : colors.border),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Plan Name & Badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        plan.name,
                                        style: AppTextStyles.titleMedium.copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                            border: Border.all(color: colors.primary, width: 1),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: AppTextStyles.micro.copyWith(
                                              color: colors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (plan.isPopular && !isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.textPrimary,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                      ),
                                      child: Text(
                                        'POPULAR',
                                        style: AppTextStyles.micro.copyWith(
                                          color: colors.background,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                plan.tagline,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),

                              // Price Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    plan.formattedPrice,
                                    style: AppTextStyles.display.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    plan.billingPeriod,
                                    style: AppTextStyles.caption.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Divider(color: colors.border, height: 1),
                              const SizedBox(height: AppSpacing.md),

                              // Features
                              ...plan.features.map(
                                (feat) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: isCurrent ? colors.primary : colors.success,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          feat,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Action Button
                              AppButton(
                                text: isCurrent
                                    ? 'Active Plan'
                                    : (plan.price == 0 ? 'Free Plan' : 'Subscribe to ${plan.name}'),
                                isLoading: isProcessing,
                                variant: isCurrent
                                    ? AppButtonVariant.secondary
                                    : (plan.isPopular ? AppButtonVariant.primary : AppButtonVariant.secondary),
                                onPressed: isCurrent ? null : () => _handleSelectPlan(plan),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  '🔒 Official 256-Bit SSL Encrypted Razorpay Checkout',
                  style: AppTextStyles.micro.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

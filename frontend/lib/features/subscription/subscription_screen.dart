import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/subscription_plan.dart';
import '../auth/providers/auth_provider.dart';
import '../history/providers/history_provider.dart';
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
  int? _pendingPlanId;
  String? _pendingPlanName;
  late final Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    AppLogger.info('Razorpay payment success: ${response.paymentId}');
    final paymentId = response.paymentId;
    final orderId = response.orderId;
    final signature = response.signature;
    final planId = _pendingPlanId;
    final planName = _pendingPlanName ?? 'Subscription';

    if (paymentId == null || orderId == null || signature == null || planId == null) {
      if (mounted) {
        setState(() {
          _processingPlanId = null;
          _pendingPlanId = null;
          _pendingPlanName = null;
        });
        context.showSnackBar('Payment details incomplete. Verification aborted.', isError: true);
      }
      return;
    }

    _verifyPaymentAndActivate(
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      planId: planId,
      planName: planName,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppLogger.warning('Razorpay payment error: [${response.code}] ${response.message}');
    if (!mounted) return;
    setState(() {
      _processingPlanId = null;
      _pendingPlanId = null;
      _pendingPlanName = null;
    });

    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      context.showSnackBar('Payment cancelled');
    } else {
      final msg = response.message != null && response.message!.isNotEmpty
          ? response.message!
          : 'Payment failed (code ${response.code})';
      context.showSnackBar(msg, isError: true);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    AppLogger.info('Razorpay external wallet: ${response.walletName}');
    if (!mounted) return;
    setState(() {
      _processingPlanId = null;
      _pendingPlanId = null;
      _pendingPlanName = null;
    });
    context.showSnackBar('External wallet selected: ${response.walletName}');
  }

  Future<void> _verifyPaymentAndActivate({
    required String paymentId,
    required String orderId,
    required String signature,
    required int planId,
    required String planName,
  }) async {
    setState(() => _processingPlanId = planId);
    try {
      // Submit Razorpay payment ID, order ID, and cryptographic signature to backend for verification
      await ref.read(userSubscriptionProvider.notifier).verifyPayment(
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
            planId: planId,
          );

      if (!mounted) return;
      setState(() {
        _processingPlanId = null;
        _pendingPlanId = null;
        _pendingPlanName = null;
      });
      await ref.read(userSubscriptionProvider.notifier).refresh();
      if (!mounted) return;
      context.showSnackBar(
        'Payment verified! Your $planName subscription is now active.',
      );

      // Seamlessly return to current chat to continue conversation
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        final activeId = ref.read(activeConversationIdProvider);
        if (activeId != null && activeId.isNotEmpty) {
          context.go('${AppRoutes.chatPath}?id=$activeId');
        } else {
          context.go(AppRoutes.chatPath);
        }
      }
    } catch (verifyErr) {
      if (!mounted) return;
      setState(() {
        _processingPlanId = null;
        _pendingPlanId = null;
        _pendingPlanName = null;
      });
      context.showSnackBar(
        verifyErr.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }

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

    setState(() {
      _processingPlanId = plan.backendId;
      _pendingPlanId = plan.backendId;
      _pendingPlanName = plan.name;
    });

    try {
      // 2. Create official Razorpay order on backend
      final order = await ref
          .read(userSubscriptionProvider.notifier)
          .createOrder(plan.backendId);

      if (!mounted) return;

      final keyId = order.keyId ?? 'rzp_test_ThS9jKhfBkpcIx';

      // 3. Launch official Razorpay Checkout UI directly via Razorpay Flutter SDK
      final options = <String, dynamic>{
        'key': keyId,
        'amount': order.amount, // amount in paise
        'name': 'Nova Chat AI',
        'description': '${plan.name} Subscription Payment',
        'order_id': order.orderId,
        'currency': order.currency,
        'prefill': {
          'name': user.name,
          'email': user.email,
          'contact': '',
        },
        'theme': {
          'color': '#0C2340',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingPlanId = null;
          _pendingPlanId = null;
          _pendingPlanName = null;
        });
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
              context.push(AppRoutes.authPath);
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  // Hero Header Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.workspace_premium_rounded, size: 26, color: colors.primary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Subscription Plans',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Text(
                            'Supercharge your conversations with extended reasoning, zero wait times, and high-throughput streaming.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Active Subscription Card
                  userSubAsync.when(
                    data: (sub) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: sub.hasSubscription
                              ? colors.success.withValues(alpha: 0.35)
                              : colors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (sub.hasSubscription ? colors.success : colors.primary)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              sub.hasSubscription ? Icons.verified_rounded : Icons.bolt_rounded,
                              size: 20,
                              color: sub.hasSubscription ? colors.success : colors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Current Tier: ${sub.planName}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (sub.hasSubscription ? colors.success : colors.textSecondary)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      ),
                                      child: Text(
                                        sub.hasSubscription ? 'ACTIVE' : 'FREE',
                                        style: AppTextStyles.micro.copyWith(
                                          color: sub.hasSubscription ? colors.success : colors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sub.endDate != null
                                      ? 'Valid until ${AppDateFormatters.formatDateDivider(sub.endDate!)}'
                                      : 'Initial 10-minute trial session',
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
                          final isPopular = plan.isPopular && !isCurrent;

                          // Icon per plan
                          IconData planIcon = Icons.bolt_rounded;
                          if (plan.name.toLowerCase().contains('free')) {
                            planIcon = Icons.explore_outlined;
                          } else if (plan.name.toLowerCase().contains('pro')) {
                            planIcon = Icons.auto_awesome_rounded;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                border: Border.all(
                                  color: isCurrent
                                      ? colors.primary
                                      : (isPopular
                                          ? colors.primary.withValues(alpha: 0.7)
                                          : colors.border),
                                  width: isCurrent || isPopular ? 1.5 : 1,
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
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: (isCurrent
                                                      ? colors.primary
                                                      : (isPopular ? colors.primary : colors.textSecondary))
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                            ),
                                            child: Icon(
                                              planIcon,
                                              size: 18,
                                              color: isCurrent
                                                  ? colors.primary
                                                  : (isPopular ? colors.primary : colors.textSecondary),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
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
                                      if (isPopular)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                          ),
                                          child: Text(
                                            'POPULAR',
                                            style: AppTextStyles.micro.copyWith(
                                              color: colors.onPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
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
                                          fontWeight: FontWeight.w800,
                                          fontSize: 28,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        plan.billingPeriod,
                                        style: AppTextStyles.caption.copyWith(
                                          color: colors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Divider(color: colors.border.withValues(alpha: 0.6), height: 1),
                                  const SizedBox(height: AppSpacing.md),

                                  // Features
                                  ...plan.features.map(
                                    (feat) => Padding(
                                      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
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
                                  const SizedBox(height: AppSpacing.md),

                                  // Action Button
                                  AppButton(
                                    text: isCurrent
                                        ? 'Current Plan'
                                        : (plan.price == 0 ? 'Free Plan' : 'Subscribe to ${plan.name}'),
                                    isLoading: isProcessing,
                                    icon: isCurrent ? Icons.check_rounded : (plan.price == 0 ? null : Icons.bolt_rounded),
                                    variant: isCurrent
                                        ? AppButtonVariant.secondary
                                        : (isPopular ? AppButtonVariant.primary : AppButtonVariant.secondary),
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

                  // Trust & Security Badge
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: colors.success),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '256-Bit SSL Encrypted Razorpay Checkout',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

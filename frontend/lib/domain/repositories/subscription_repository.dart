import '../../data/models/payment_order.dart';
import '../../data/models/subscription_plan.dart';

/// Contract for fetching subscription plans, current user subscription, and processing Razorpay payments.
abstract class SubscriptionRepository {
  /// Fetch all subscription plans from backend GET /users/plans.
  Future<List<SubscriptionPlan>> getPlans();

  /// Get current logged-in user subscription status from GET /users/subscription.
  Future<UserSubscriptionStatus> getCurrentSubscription();

  /// Create Razorpay order via POST /users/create-order.
  Future<PaymentOrderResponse> createOrder(int planId);

  /// Verify Razorpay payment and activate subscription via POST /users/verify-payment.
  Future<UserSubscriptionStatus> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required int planId,
  });
}

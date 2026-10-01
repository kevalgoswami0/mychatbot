import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/payment_order.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/repositories/subscription_repository.dart';

/// Provider for loading the available plans list from backend GET /users/plans.
final plansListProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getPlans();
});

/// State for the current user's subscription status.
class UserSubscriptionNotifier extends AsyncNotifier<UserSubscriptionStatus> {
  late final SubscriptionRepository _repository;

  @override
  Future<UserSubscriptionStatus> build() async {
    _repository = ref.watch(subscriptionRepositoryProvider);
    return _repository.getCurrentSubscription();
  }

  void resetToFree() {
    state = const AsyncData(UserSubscriptionStatus(
      hasSubscription: false,
      planName: 'Free',
      status: 'active',
      dailyLimitSeconds: 120,
      remainingSecondsToday: 120,
      usedSecondsToday: 0,
      limitReached: false,
    ));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getCurrentSubscription());
  }

  Future<PaymentOrderResponse> createOrder(int planId) async {
    return _repository.createOrder(planId);
  }

  Future<UserSubscriptionStatus> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required int planId,
  }) async {
    final result = await _repository.verifyPayment(
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      razorpaySignature: razorpaySignature,
      planId: planId,
    );
    state = AsyncData(result);
    return result;
  }
}

final userSubscriptionProvider =
    AsyncNotifierProvider<UserSubscriptionNotifier, UserSubscriptionStatus>(
  UserSubscriptionNotifier.new,
);

/// Legacy / convenience provider that provides the active SubscriptionPlan object.
final subscriptionProvider = Provider<SubscriptionPlan>((ref) {
  final userSub = ref.watch(userSubscriptionProvider).value;
  final planName = userSub?.planName ?? 'Free';
  return SubscriptionPlan.getById(planName.toLowerCase());
});

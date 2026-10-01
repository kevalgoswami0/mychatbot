import 'package:flutter/foundation.dart';

/// Immutable subscription plan entity mapped to backend plan and UI presentation.
@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.backendId,
    required this.name,
    required this.tagline,
    required this.price,
    required this.durationDays,
    required this.features,
    this.isPopular = false,
  });

  final String id;
  final int backendId;
  final String name;
  final String tagline;
  final int price; // In INR ₹
  final int durationDays;
  final List<String> features;
  final bool isPopular;

  String get formattedPrice => price == 0 ? '₹0 Free' : '₹$price';
  String get billingPeriod => durationDays == 0 ? 'Forever' : 'for $durationDays days';

  factory SubscriptionPlan.fromBackendJson(Map<String, dynamic> json) {
    final int bId = (json['id'] as num?)?.toInt() ?? 0;
    final String bName = json['name']?.toString() ?? 'Plan';
    final int bPrice = (json['price'] as num?)?.toInt() ?? 0;
    final int bDays = (json['duration_days'] as num?)?.toInt() ?? 0;

    String tagline = 'Standard access to chat assistant';
    List<String> features = ['Access to AI Chatbot', 'Standard speed'];
    bool isPop = false;

    if (bName.toLowerCase().contains('free')) {
      tagline = 'Try out the chatbot with initial free access';
      features = [
        '10 minutes free trial session',
        'Groq LLaMA 3.3 high-speed inference',
        'Real-time WebSocket streaming',
        'Markdown & code highlighting',
      ];
    } else if (bName.toLowerCase().contains('basic')) {
      tagline = 'Essential plan for regular personal use';
      isPop = true;
      features = [
        'Unlimited chat messages for 30 days',
        'High-speed streaming responses',
        'Full conversation history & persistence',
        'Instant Razorpay activation',
      ];
    } else if (bName.toLowerCase().contains('pro')) {
      tagline = 'Maximum performance and reasoning capacity';
      features = [
        'Everything in Basic tier',
        'Priority high-throughput compute',
        'Extended context memory retention',
        'Early access to new features',
      ];
    }

    return SubscriptionPlan(
      id: bName.toLowerCase(),
      backendId: bId,
      name: bName,
      tagline: tagline,
      price: bPrice,
      durationDays: bDays,
      features: features,
      isPopular: isPop,
    );
  }

  static const List<SubscriptionPlan> defaultPlans = [
    SubscriptionPlan(
      id: 'free',
      backendId: 1,
      name: 'Free',
      tagline: 'Try out the chatbot with initial free access',
      price: 0,
      durationDays: 0,
      features: [
        '10 minutes free trial session',
        'Groq LLaMA 3.3 high-speed inference',
        'Real-time WebSocket streaming',
        'Markdown & code highlighting',
      ],
    ),
    SubscriptionPlan(
      id: 'basic',
      backendId: 2,
      name: 'Basic',
      tagline: 'Essential plan for regular personal use',
      price: 1,
      durationDays: 30,
      isPopular: true,
      features: [
        'Unlimited chat messages for 30 days',
        'High-speed streaming responses',
        'Full conversation history & persistence',
        'Instant Razorpay activation',
      ],
    ),
    SubscriptionPlan(
      id: 'pro',
      backendId: 3,
      name: 'Pro',
      tagline: 'Maximum performance and reasoning capacity',
      price: 2,
      durationDays: 30,
      features: [
        'Everything in Basic tier',
        'Priority high-throughput compute',
        'Extended context memory retention',
        'Early access to new features',
      ],
    ),
  ];

  static SubscriptionPlan getById(String id) {
    return defaultPlans.firstWhere(
      (p) => p.id == id.toLowerCase(),
      orElse: () => defaultPlans.first,
    );
  }

  static SubscriptionPlan getByBackendId(int bId) {
    return defaultPlans.firstWhere(
      (p) => p.backendId == bId,
      orElse: () => defaultPlans.first,
    );
  }
}

/// Active user subscription status returned by backend GET /users/subscription.
class UserSubscriptionStatus {
  const UserSubscriptionStatus({
    required this.hasSubscription,
    required this.planName,
    required this.status,
    this.subscriptionId,
    this.planId,
    this.price,
    this.startDate,
    this.endDate,
    this.limitReached = false,
    this.dailyLimitSeconds = 120,
    this.usedSecondsToday = 0,
    this.remainingSecondsToday = 120,
  });

  final bool hasSubscription;
  final String planName;
  final String status;
  final int? subscriptionId;
  final int? planId;
  final int? price;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool limitReached;
  final int dailyLimitSeconds;
  final int usedSecondsToday;
  final int remainingSecondsToday;

  bool get isActive => status == 'active';
  
  /// Validates whether the subscription is active and within its valid end date
  bool get isSubscribedAndValid {
    if (!hasSubscription || status != 'active') return false;
    if (endDate != null) {
      final nowUtc = DateTime.now().toUtc();
      final endUtc = endDate!.isUtc ? endDate! : endDate!.toUtc();
      if (nowUtc.isAfter(endUtc)) {
        return false;
      }
    }
    return true;
  }

  bool get isChatAllowed => isSubscribedAndValid || !limitReached;

  Map<String, dynamic> toJson() => {
    'has_subscription': hasSubscription,
    'plan_name': planName,
    'status': status,
    'subscription_id': subscriptionId,
    'plan_id': planId,
    'price': price,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'limit_reached': limitReached,
    'daily_limit_seconds': dailyLimitSeconds,
    'used_seconds_today': usedSecondsToday,
    'remaining_seconds_today': remainingSecondsToday,
  };

  factory UserSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      var str = v.toString();
      if (!str.endsWith('Z') && !str.contains('+')) {
        str = '${str}Z';
      }
      return DateTime.tryParse(str) ?? DateTime.tryParse(v.toString());
    }

    final end = parseDate(json['end_date']);
    final rawHasSub = json['has_subscription'] == true;
    final isExpired = end != null && DateTime.now().toUtc().isAfter(end.toUtc());

    return UserSubscriptionStatus(
      hasSubscription: rawHasSub && !isExpired,
      planName: json['plan_name']?.toString() ?? 'Free',
      status: isExpired ? 'expired' : (json['status']?.toString() ?? 'inactive'),
      subscriptionId: (json['subscription_id'] as num?)?.toInt(),
      planId: (json['plan_id'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toInt(),
      startDate: parseDate(json['start_date']),
      endDate: end,
      limitReached: (rawHasSub && !isExpired) ? false : (json['limit_reached'] == true),
      dailyLimitSeconds: (json['daily_limit_seconds'] as num?)?.toInt() ?? 120,
      usedSecondsToday: (rawHasSub && !isExpired) ? 0 : ((json['used_seconds_today'] as num?)?.toInt() ?? 0),
      remainingSecondsToday: (json['remaining_seconds_today'] as num?)?.toInt() ?? 120,
    );
  }
}

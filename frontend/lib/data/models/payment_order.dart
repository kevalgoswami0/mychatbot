import 'package:flutter/foundation.dart';

/// Razorpay order payload created by backend POST /users/create-order.
@immutable
class PaymentOrderResponse {
  const PaymentOrderResponse({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.planId,
    required this.planName,
    this.keyId,
  });

  final String orderId;
  final int amount; // Amount in paise (e.g. 100 = ₹1)
  final String currency;
  final int planId;
  final String planName;
  final String? keyId;

  double get amountInRupees => amount / 100.0;

  factory PaymentOrderResponse.fromJson(Map<String, dynamic> json) {
    return PaymentOrderResponse(
      orderId: json['order_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      planName: json['plan_name']?.toString() ?? '',
      keyId: json['key_id']?.toString(),
    );
  }
}

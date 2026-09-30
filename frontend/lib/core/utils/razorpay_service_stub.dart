/// Stub implementation for non-web platforms and headless tests.
Future<void> launchRazorpayWebCheckout({
  required String keyId,
  required String orderId,
  required double amountInRupees,
  required String currency,
  required String planName,
  required String userName,
  required String userEmail,
  required Function(String paymentId, String orderId, String signature) onSuccess,
  required Function(String error) onFailure,
}) async {
  onFailure('Razorpay web checkout is available on Web. Please open in a browser.');
}

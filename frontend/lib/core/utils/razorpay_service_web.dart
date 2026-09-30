import 'dart:convert';
import 'dart:js_interop' as js;

@js.JS('openRazorpay')
external void _openRazorpay(
  js.JSString optionsJson,
  js.JSFunction onSuccess,
  js.JSFunction onFailure,
);

/// Web implementation calling the official Razorpay JS Checkout.
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
  try {
    final options = {
      'key': keyId,
      'amount': (amountInRupees * 100).toInt(),
      'currency': currency,
      'name': 'Nova Chat',
      'description': '$planName Subscription',
      'order_id': orderId,
      'prefill': {
        'name': userName,
        'email': userEmail,
      },
      'theme': {
        'color': '#2563EB',
      },
    };

    final jsSuccess = ((js.JSString pId, js.JSString oId, js.JSString sig) {
      onSuccess(pId.toDart, oId.toDart, sig.toDart);
    }).toJS;

    final jsFailure = ((js.JSString err) {
      onFailure(err.toDart);
    }).toJS;

    _openRazorpay(jsonEncode(options).toJS, jsSuccess, jsFailure);
  } catch (e) {
    onFailure(e.toString());
  }
}

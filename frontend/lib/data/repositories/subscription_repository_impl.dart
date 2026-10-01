import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/local_storage.dart';
import '../models/payment_order.dart';
import '../models/subscription_plan.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    required LocalStorage localStorage,
    http.Client? client,
  })  : _storage = localStorage,
        _client = client ?? http.Client();

  final LocalStorage _storage;
  final http.Client _client;

  bool _isTokenExpired(String? token) {
    if (token == null || token.trim().isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payloadNormalized = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(payloadNormalized);
      final payloadJson = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final exp = payloadJson['exp'];
      if (exp is num) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
        return DateTime.now().toUtc().isAfter(expiryTime.subtract(const Duration(seconds: 60)));
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _getValidAccessToken({bool forceRefresh = false}) async {
    final token = _storage.getAccessToken();
    if (!forceRefresh && token != null && token.isNotEmpty && !_isTokenExpired(token)) {
      return token;
    }

    final refreshToken = _storage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        AppLogger.info('Refreshing JWT access token for subscription...');
        final res = await _client.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authRefreshEndpoint}'),
          headers: {'Content-Type': 'application/json', 'accept': '*/*'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          final newToken = data['access_token'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            await _storage.saveAuthTokens(accessToken: newToken, refreshToken: refreshToken);
            AppLogger.info('Access token refreshed successfully.');
            return newToken;
          }
        }
      } catch (e) {
        AppLogger.warning('Token refresh failed: $e');
      }
    }
    return token;
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final token = await _getValidAccessToken(forceRefresh: forceRefresh);
    return {
      'accept': '*/*',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = await _authHeaders();
    var response = await requestFn(headers).timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 401) {
      AppLogger.info('Received 401 in subscription call. Retrying with fresh token...');
      headers = await _authHeaders(forceRefresh: true);
      response = await requestFn(headers).timeout(ApiConfig.requestTimeout);
    }

    return response;
  }

  @override
  Future<List<SubscriptionPlan>> getPlans() async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.plansEndpoint}');
    AppLogger.info('Fetching plans from: $url');

    try {
      final response = await _client.get(
        url,
        headers: {'accept': '*/*'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> plansJson = data['plans'] as List<dynamic>? ?? [];
        final plans = plansJson
            .map((p) => SubscriptionPlan.fromBackendJson(p as Map<String, dynamic>))
            .toList();

        if (plans.isNotEmpty) {
          return plans;
        }
      }
    } catch (e, st) {
      AppLogger.warning('Could not fetch live plans, using defaults: $e', stackTrace: st);
    }

    return SubscriptionPlan.defaultPlans;
  }

  @override
  Future<UserSubscriptionStatus> getCurrentSubscription() async {
    final token = await _getValidAccessToken();
    if (token == null || token.isEmpty) {
      return const UserSubscriptionStatus(
        hasSubscription: false,
        planName: 'Free',
        status: 'active',
      );
    }

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.subscriptionEndpoint}');
    AppLogger.info('Fetching current subscription from: $url');

    try {
      final response = await _authenticatedRequest(
        (headers) => _client.get(url, headers: headers),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status = UserSubscriptionStatus.fromJson(data);
        await _storage.setSubscriptionPlan(status.planName.toLowerCase());
        await _storage.saveSubscriptionStatus(status);
        return status;
      } else {
        AppLogger.warning('Failed to fetch subscription: ${response.statusCode}');
      }
    } catch (e, st) {
      AppLogger.error('Error fetching subscription status', error: e, stackTrace: st);
    }

    // Fallback: If network failed or server temporarily unavailable, preserve active subscription till its end date
    final cached = _storage.loadSubscriptionStatus();
    if (cached != null && cached.isSubscribedAndValid) {
      AppLogger.info('Retaining valid cached subscription (${cached.planName}) valid until ${cached.endDate}');
      return cached;
    }

    return const UserSubscriptionStatus(
      hasSubscription: false,
      planName: 'Free',
      status: 'active',
    );
  }

  @override
  Future<PaymentOrderResponse> createOrder(int planId) async {
    final token = await _getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to subscribe to a plan.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.createOrderEndpoint}');
    AppLogger.info('Creating Razorpay order for plan $planId: $url');

    try {
      final response = await _authenticatedRequest(
        (headers) => _client.post(
          url,
          headers: headers,
          body: jsonEncode({'plan_id': planId}),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PaymentOrderResponse.fromJson(data);
      } else {
        throw Exception(_parseError(response.body, 'Failed to create payment order (${response.statusCode})'));
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Order error: $e');
    }
  }

  @override
  Future<UserSubscriptionStatus> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required int planId,
  }) async {
    final token = await _getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to complete payment verification.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyPaymentEndpoint}');
    AppLogger.info('Verifying Razorpay payment: $url');

    try {
      final response = await _authenticatedRequest(
        (headers) => _client.post(
          url,
          headers: headers,
          body: jsonEncode({
            'razorpay_payment_id': razorpayPaymentId.trim(),
            'razorpay_order_id': razorpayOrderId.trim(),
            'razorpay_signature': razorpaySignature.trim(),
            'plan_id': planId,
          }),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final mergedData = Map<String, dynamic>.from(data);
        mergedData['has_subscription'] = true;
        mergedData['limit_reached'] = false;
        final status = UserSubscriptionStatus.fromJson(mergedData);

        await _storage.setSubscriptionPlan(status.planName.toLowerCase());
        await _storage.saveSubscriptionStatus(status);
        return status;
      } else {
        throw Exception(_parseError(response.body, 'Payment verification failed (${response.statusCode})'));
      }
    } on TimeoutException {
      throw Exception('Verification request timed out. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Verification error: $e');
    }
  }

  String _parseError(String body, String fallback) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] != null) {
          if (decoded['detail'] is String) return decoded['detail'] as String;
          if (decoded['detail'] is List && (decoded['detail'] as List).isNotEmpty) {
            final f = (decoded['detail'] as List).first;
            if (f is Map && f['msg'] != null) return f['msg'].toString();
            return f.toString();
          }
        }
        if (decoded['message'] != null) return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}

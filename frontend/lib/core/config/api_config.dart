/// Configuration for FastAPI backend integration and live endpoints.
class ApiConfig {
  ApiConfig._();

  /// Flag indicating whether the app is currently using the mock data layer.
  /// Set this to `false` to connect to the live backend API.
  static const bool useMock = false;

  /// Base URL for the FastAPI backend.
  static const String baseUrl = 'http://192.168.1.13:8000';

  /// WebSocket Base URL (ws:// for http, wss:// for https).
  static String get wsBaseUrl {
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    }
    return baseUrl.replaceFirst('http://', 'ws://');
  }

  // --- Auth & Account Endpoints ---
  static const String authSignupEndpoint = '/users/signup';
  static const String authVerifyEmailEndpoint = '/users/verify-email';
  static const String authLoginEndpoint = '/users/login';
  static const String authProfileEndpoint = '/users/me';
  static const String authRefreshEndpoint = '/users/refresh';
  static const String authForgotPasswordEndpoint = '/users/forgot-password';
  static const String authVerifyResetOtpEndpoint = '/users/verify-reset-otp';
  static const String authResetPasswordEndpoint = '/users/reset-password';
  static const String authLogoutEndpoint = '/users/logout';
  static const String usersListEndpoint = '/users/';

  // --- Conversation & Chat Endpoints ---
  static const String conversationsEndpoint = '/users/conversations';
  static String conversationMessagesEndpoint(dynamic conversationId) =>
      '/users/conversations/$conversationId/messages';
  static String conversationDetailEndpoint(dynamic conversationId) =>
      '/users/conversations/$conversationId';
  static const String chatHttpEndpoint = '/users/chat';

  /// WebSocket chat endpoint with JWT authentication query param.
  static String wsChatEndpoint(dynamic conversationId, String token) =>
      '$wsBaseUrl/users/ws/chat/$conversationId?token=${Uri.encodeComponent(token)}';

  // --- Subscription & Payment Endpoints ---
  static const String plansEndpoint = '/users/plans';
  static const String subscriptionEndpoint = '/users/subscription';
  static const String createOrderEndpoint = '/users/create-order';
  static const String verifyPaymentEndpoint = '/users/verify-payment';

  /// Default timeout for HTTP requests.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Streaming token interval simulation for mock datasource (in ms).
  static const int mockTokenIntervalMs = 15;

  /// Minimum and maximum mock network latency simulation (in ms).
  static const int mockLatencyMinMs = 40;
  static const int mockLatencyMaxMs = 100;
}

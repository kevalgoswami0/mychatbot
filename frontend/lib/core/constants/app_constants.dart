/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// The working title/name of the application.
  /// Centralized in a single constant so it's effortless to change.
  static const String appName = 'Nova';

  /// Current application version string.
  static const String appVersion = '1.0.0';

  /// Build number representation.
  static const String appBuildNumber = '1';

  /// Short tagline for the application.
  static const String appTagline = 'Fast, minimal & intelligent conversational AI';

  /// Maximum lines for the message input field.
  static const int maxInputLines = 5;

  /// Streaming token batching throttle duration in milliseconds.
  static const int streamBatchThrottleMs = 50;

  /// Default model name for display.
  static const String defaultModelName = 'Nova-3.5 Ultra';

  /// Key prefixes for SharedPreferences and storage.
  static const String prefKeyThemeMode = 'nova_theme_mode';
  static const String prefKeyOnboardingCompleted = 'nova_onboarding_completed';
  static const String prefKeyAuthUser = 'nova_auth_user';
  static const String prefKeyAccessToken = 'nova_access_token';
  static const String prefKeyRefreshToken = 'nova_refresh_token';
  static const String prefKeyActiveConversationId = 'nova_active_conversation_id';
  static const String prefKeySubscriptionPlan = 'nova_subscription_plan';
  static const String storageBoxConversations = 'nova_conversations_box';
  static const String storageBoxMessages = 'nova_messages_box';
}

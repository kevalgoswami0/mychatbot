import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user_profile.dart';

/// Clean local persistence service backed by SharedPreferences with robust JSON serialization.
/// Ensures chats, messages, user sessions, and settings seamlessly survive app restarts.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  /// Save onboarding completed flag
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(AppConstants.prefKeyOnboardingCompleted, completed);
  }

  /// Check if onboarding has been completed
  bool isOnboardingCompleted() {
    return _prefs.getBool(AppConstants.prefKeyOnboardingCompleted) ?? false;
  }

  /// Save theme mode ('system', 'light', 'dark')
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(AppConstants.prefKeyThemeMode, mode);
  }

  /// Get stored theme mode
  String getThemeMode() {
    return _prefs.getString(AppConstants.prefKeyThemeMode) ?? 'system';
  }

  /// Save active subscription plan ID ('free', 'pro', 'ultra')
  Future<void> setSubscriptionPlan(String planId) async {
    await _prefs.setString(AppConstants.prefKeySubscriptionPlan, planId);
  }

  /// Get stored active subscription plan ID
  String getSubscriptionPlan() {
    return _prefs.getString(AppConstants.prefKeySubscriptionPlan) ?? 'free';
  }

  /// Save authenticated user profile
  Future<void> saveUserProfile(UserProfile? profile) async {
    if (profile == null) {
      await _prefs.remove(AppConstants.prefKeyAuthUser);
      await _prefs.remove(AppConstants.prefKeyAccessToken);
      await _prefs.remove(AppConstants.prefKeyRefreshToken);
    } else {
      await _prefs.setString(AppConstants.prefKeyAuthUser, profile.toJson());
    }
  }

  /// Save JWT auth tokens
  Future<void> saveAuthTokens({String? accessToken, String? refreshToken}) async {
    if (accessToken != null) {
      await _prefs.setString(AppConstants.prefKeyAccessToken, accessToken);
    } else {
      await _prefs.remove(AppConstants.prefKeyAccessToken);
    }
    if (refreshToken != null) {
      await _prefs.setString(AppConstants.prefKeyRefreshToken, refreshToken);
    } else {
      await _prefs.remove(AppConstants.prefKeyRefreshToken);
    }
  }

  /// Retrieve stored access token
  String? getAccessToken() => _prefs.getString(AppConstants.prefKeyAccessToken);

  /// Retrieve stored refresh token
  String? getRefreshToken() => _prefs.getString(AppConstants.prefKeyRefreshToken);

  String get _currentUserId => loadUserProfile()?.id.toString() ?? 'guest';
  String get _conversationsKey => 'nova_storage_${_currentUserId}_conversations';
  String _messagesKey(String conversationId) => 'nova_storage_${_currentUserId}_messages_$conversationId';

  /// Load authenticated user profile
  UserProfile? loadUserProfile() {
    final raw = _prefs.getString(AppConstants.prefKeyAuthUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(raw);
    } catch (e, st) {
      AppLogger.error('Failed to parse cached user profile', error: e, stackTrace: st);
      return null;
    }
  }

  /// Load all saved conversations for current user
  List<Conversation> loadConversations() {
    final raw = _prefs.getString(_conversationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      return list
          .map((item) => Conversation.fromMap(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e, st) {
      AppLogger.error('Failed to parse cached conversations', error: e, stackTrace: st);
      return [];
    }
  }

  /// Save full list of conversations for current user
  Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      final raw = json.encode(conversations.map((c) => c.toMap()).toList());
      await _prefs.setString(_conversationsKey, raw);
    } catch (e, st) {
      AppLogger.error('Failed to save conversations', error: e, stackTrace: st);
    }
  }

  /// Load messages for a specific conversation for current user
  List<Message> loadMessages(String conversationId) {
    final raw = _prefs.getString(_messagesKey(conversationId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      return list
          .map((item) => Message.fromMap(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e, st) {
      AppLogger.error('Failed to parse cached messages for $conversationId', error: e, stackTrace: st);
      return [];
    }
  }

  /// Save messages for a specific conversation for current user
  Future<void> saveMessages(String conversationId, List<Message> messages) async {
    try {
      final raw = json.encode(messages.map((m) => m.toMap()).toList());
      await _prefs.setString(_messagesKey(conversationId), raw);
    } catch (e, st) {
      AppLogger.error('Failed to save messages for $conversationId', error: e, stackTrace: st);
    }
  }

  /// Delete messages for a specific conversation for current user
  Future<void> deleteMessages(String conversationId) async {
    await _prefs.remove(_messagesKey(conversationId));
  }

  /// Clear all stored conversations and messages from disk for current user
  Future<void> clearAllChatData() async {
    final conversations = loadConversations();
    for (final c in conversations) {
      await deleteMessages(c.id);
    }
    await _prefs.remove(_conversationsKey);
  }
}

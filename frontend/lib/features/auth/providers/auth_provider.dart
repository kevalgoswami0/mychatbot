import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/repositories/auth_repository.dart';

import '../../chat/providers/chat_providers.dart';
import '../../history/providers/history_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

class AuthNotifier extends AsyncNotifier<UserProfile?> {
  late final AuthRepository _authRepository;
  StreamSubscription<UserProfile?>? _authSubscription;

  void _resetUserState() {
    ref.read(activeConversationIdProvider.notifier).setActiveId(null);
    ref.read(messagesProvider.notifier).resetToEmpty();
    ref.invalidate(conversationsProvider);
    ref.invalidate(userSubscriptionProvider);
  }

  @override
  Future<UserProfile?> build() async {
    _authRepository = ref.watch(authRepositoryProvider);

    _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      state = AsyncData(user);
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return _authRepository.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.login(email, password));
    _resetUserState();
  }

  Future<void> signup(
    String name,
    String email,
    String password, [
    String? confirmPassword,
  ]) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signup(name, email, password, confirmPassword),
    );
    _resetUserState();
  }

  Future<void> continueAsGuest() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.continueAsGuest());
    _resetUserState();
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await _authRepository.logout();
    state = const AsyncData(null);
    _resetUserState();
  }

  Future<String> verifyEmail({required String email, required String otp}) async {
    return await _authRepository.verifyEmail(email: email, otp: otp);
  }

  Future<String> forgotPassword({required String email}) async {
    return await _authRepository.forgotPassword(email: email);
  }

  Future<String> verifyResetOtp({required String email, required String otp}) async {
    return await _authRepository.verifyResetOtp(email: email, otp: otp);
  }

  Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    return await _authRepository.resetPassword(
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  Future<void> updateProfile({String? name}) async {
    final current = state.value;
    if (current == null) return;
    final updated = await _authRepository.updateProfile(name: name);
    state = AsyncData(updated);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserProfile?>(
  AuthNotifier.new,
);

/// Boolean provider indicating if user is authenticated (or guest)
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.value != null;
});

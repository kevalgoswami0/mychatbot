import '../../data/models/user_profile.dart';

/// Abstract contract for Authentication and User management.
abstract class AuthRepository {
  /// Get currently authenticated user, or null if unauthenticated.
  Future<UserProfile?> getCurrentUser();

  /// Authenticate user via email and password credentials.
  Future<UserProfile> login(String email, String password);

  /// Register a new user account.
  Future<UserProfile> signup(
    String name,
    String email,
    String password, [
    String? confirmPassword,
  ]);

  /// Continue without registration as an anonymous guest.
  Future<UserProfile> continueAsGuest();

  /// Sign out the current user and reset state.
  Future<void> logout();

  /// Permanently delete current user account from backend database and local storage.
  Future<void> deleteAccount();

  /// Verify user's email address with 6-digit OTP.
  Future<String> verifyEmail({required String email, required String otp});

  /// Request a password reset OTP for the registered email.
  Future<String> forgotPassword({required String email});

  /// Verify password reset OTP and obtain a password reset token.
  Future<String> verifyResetOtp({required String email, required String otp});

  /// Reset password using reset token and new password.
  Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// Update user profile details (e.g. display name).
  Future<UserProfile> updateProfile({String? name});

  /// Reactive stream of authentication state changes.
  Stream<UserProfile?> get authStateChanges;
}

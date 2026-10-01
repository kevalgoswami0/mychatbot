import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_storage.dart';
import '../models/user_profile.dart';

/// Production-ready AuthRepository implementation with local session caching.
/// Ready to swap mock authentication calls for real JWT/OAuth2 REST endpoints.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required LocalStorage localStorage,
    http.Client? client,
  })  : _storage = localStorage,
        _client = client ?? http.Client() {
    _currentUser = _storage.loadUserProfile();
    _authController.add(_currentUser);
  }

  final LocalStorage _storage;
  final http.Client _client;
  final Uuid _uuid = const Uuid();
  final StreamController<UserProfile?> _authController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;

  @override
  Stream<UserProfile?> get authStateChanges => _authController.stream;

  @override
  Future<UserProfile?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<UserProfile> login(String email, String password) async {
    if (!email.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authLoginEndpoint}');
      AppLogger.info('Calling login API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'email': email.trim(),
                'password': password,
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Login response status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final accessToken = data['access_token'] as String?;
          final refreshToken = data['refresh_token'] as String?;

          await _storage.clearAllChatData();
          await _storage.saveSubscriptionStatus(null);
          await _storage.setSubscriptionPlan('free');

          await _storage.saveAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );

          String userName = '';
          String userId = _uuid.v4();

          // 1. Check if backend returned user object directly
          if (data['user'] is Map) {
            final userMap = data['user'] as Map<String, dynamic>;
            userName = userMap['name']?.toString() ?? '';
            if (userMap['id'] != null) userId = userMap['id'].toString();
          }

          // 2. If not, fetch from GET /users/me using access_token
          if (userName.isEmpty && accessToken != null) {
            try {
              final meUrl = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authProfileEndpoint}');
              final meRes = await _client.get(
                meUrl,
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'accept': '*/*',
                },
              ).timeout(const Duration(seconds: 5));
              if (meRes.statusCode >= 200 && meRes.statusCode < 300) {
                final meData = jsonDecode(meRes.body);
                if (meData is Map && meData['name'] != null) {
                  userName = meData['name'].toString();
                  if (meData['id'] != null) userId = meData['id'].toString();
                }
              }
            } catch (e) {
              AppLogger.warning('Could not fetch user from /users/me: $e');
            }
          }

          // 3. Check previously cached user profile if same email
          if (userName.isEmpty) {
            final cached = _storage.loadUserProfile();
            if (cached != null && cached.email.toLowerCase() == email.trim().toLowerCase()) {
              userName = cached.name;
              userId = cached.id;
            }
          }

          // 4. Fallback only if no name found anywhere
          if (userName.isEmpty) {
            final nameFromEmail = email.split('@').first;
            userName = nameFromEmail.isNotEmpty
                ? nameFromEmail[0].toUpperCase() + nameFromEmail.substring(1)
                : 'User';
          }

          final user = UserProfile(
            id: userId,
            name: userName,
            email: email.trim(),
            isGuest: false,
            createdAt: DateTime.now(),
          );

          _currentUser = user;
          await _storage.saveUserProfile(user);
          _authController.add(user);
          AppLogger.info('User logged in successfully: ${user.name} (${user.email})');
          return user;
        } else {
          throw Exception(_parseErrorMessage(
            response.body,
            'Login failed (${response.statusCode})',
          ));
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your backend connection.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during login: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Login error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 600)); // latency simulation

    final nameFromEmail = email.split('@').first;
    final formattedName = nameFromEmail[0].toUpperCase() + nameFromEmail.substring(1);

    final user = UserProfile(
      id: _uuid.v4(),
      name: formattedName,
      email: email.trim(),
      isGuest: false,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _storage.saveUserProfile(user);
    _authController.add(user);
    AppLogger.info('User logged in successfully: ${user.email}');
    return user;
  }

  @override
  Future<UserProfile> signup(
    String name,
    String email,
    String password, [
    String? confirmPassword,
  ]) async {
    final effectiveConfirmPassword = confirmPassword ?? password;

    if (name.trim().isEmpty) {
      throw Exception('Name cannot be empty.');
    }
    if (name.trim().length < 2) {
      throw Exception('Name must be at least 2 characters.');
    }
    if (!email.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    if (password != effectiveConfirmPassword) {
      throw Exception('Password and confirm password do not match.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authSignupEndpoint}');
      AppLogger.info('Calling signup API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'name': name.trim(),
                'email': email.trim(),
                'password': password,
                'confirm_password': effectiveConfirmPassword,
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Signup response status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Clear any stale tokens and previous user session
          _currentUser = null;
          await _storage.saveAuthTokens(accessToken: null, refreshToken: null);
          await _storage.saveUserProfile(null);
          await _storage.saveSubscriptionStatus(null);
          await _storage.setSubscriptionPlan('free');
          await _storage.clearAllChatData();
          _authController.add(null);

          final user = UserProfile(
            id: _uuid.v4(),
            name: name.trim(),
            email: email.trim(),
            isGuest: false,
            createdAt: DateTime.now(),
          );

          AppLogger.info('User signup initiated, awaiting OTP verification: ${user.email}');
          return user;
        } else {
          String errorMessage = 'Signup failed (${response.statusCode})';
          try {
            final dynamic decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              if (decoded['detail'] != null) {
                if (decoded['detail'] is String) {
                  errorMessage = decoded['detail'] as String;
                } else if (decoded['detail'] is List && (decoded['detail'] as List).isNotEmpty) {
                  final first = (decoded['detail'] as List).first;
                  if (first is Map && first['msg'] != null) {
                    errorMessage = first['msg'].toString();
                  } else {
                    errorMessage = first.toString();
                  }
                }
              } else if (decoded['message'] != null) {
                errorMessage = decoded['message'].toString();
              }
            }
          } catch (_) {
            if (response.body.isNotEmpty) {
              errorMessage = response.body;
            }
          }
          throw Exception(errorMessage);
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your backend connection.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during signup: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}. Please verify the server is running.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Signup error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 700));

    final user = UserProfile(
      id: _uuid.v4(),
      name: name.trim(),
      email: email.trim(),
      isGuest: false,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _storage.saveUserProfile(user);
    _authController.add(user);
    AppLogger.info('User signed up successfully: ${user.email}');
    return user;
  }

  @override
  Future<UserProfile> continueAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 150));

    await _storage.saveAuthTokens(accessToken: null, refreshToken: null);
    await _storage.saveSubscriptionStatus(null);
    await _storage.setSubscriptionPlan('free');
    await _storage.clearAllChatData();

    final guestUser = UserProfile(
      id: _uuid.v4(),
      name: 'Guest User',
      email: 'guest@novachat.ai',
      isGuest: true,
      createdAt: DateTime.now(),
    );

    _currentUser = guestUser;
    await _storage.saveUserProfile(guestUser);
    _authController.add(guestUser);
    AppLogger.info('Signed in as Guest');
    return guestUser;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _currentUser = null;
    await _storage.saveAuthTokens(accessToken: null, refreshToken: null);
    await _storage.saveUserProfile(null);
    await _storage.saveSubscriptionStatus(null);
    await _storage.setSubscriptionPlan('free');
    await _storage.clearAllChatData();
    _authController.add(null);
    AppLogger.info('User logged out and session cleared');
  }

  @override
  Future<void> deleteAccount() async {
    final token = _storage.getAccessToken();

    if (!ApiConfig.useMock && token != null && token.isNotEmpty) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authDeleteAccountEndpoint}');
      AppLogger.info('Calling delete account API: $url');

      try {
        final response = await _client
            .delete(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'accept': '*/*',
              },
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Delete account response: ${response.statusCode}');

        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (response.statusCode != 404) {
            throw Exception(_parseErrorMessage(
              response.body,
              'Failed to delete account (${response.statusCode})',
            ));
          }
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your network connection.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during delete account: $e');
        throw Exception('Unable to reach backend server to delete account.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Delete account error: $e');
      }
    }

    _currentUser = null;
    await _storage.saveUserProfile(null);
    _authController.add(null);
    AppLogger.info('Account deleted and session cleared');
  }

  @override
  Future<String> verifyEmail({required String email, required String otp}) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please provide a valid email address.');
    }
    if (otp.trim().isEmpty) {
      throw Exception('Please enter the 6-digit OTP.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authVerifyEmailEndpoint}');
      AppLogger.info('Calling verify email API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'email': email.trim(),
                'otp': otp.trim(),
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Verify email status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final accessToken = data['access_token'] as String?;
          final refreshToken = data['refresh_token'] as String?;

          await _storage.clearAllChatData();
          await _storage.saveSubscriptionStatus(null);
          await _storage.setSubscriptionPlan('free');

          if (accessToken != null) {
            await _storage.saveAuthTokens(
              accessToken: accessToken,
              refreshToken: refreshToken,
            );
          }

          String userName = '';
          String userId = _uuid.v4();
          if (data['user'] is Map) {
            final userMap = data['user'] as Map<String, dynamic>;
            userName = userMap['name']?.toString() ?? '';
            if (userMap['id'] != null) userId = userMap['id'].toString();
          }

          var currentUser = UserProfile(
            id: userId,
            name: userName.isNotEmpty ? userName : email.split('@').first,
            email: email.trim(),
            isGuest: false,
            createdAt: DateTime.now(),
          );

          _currentUser = currentUser;
          await _storage.saveUserProfile(currentUser);
          await _storage.clearAllChatData();
          _authController.add(currentUser);

          return data['message'] as String? ?? 'Email verified successfully';
        } else {
          throw Exception(_parseErrorMessage(
            response.body,
            'Verification failed (${response.statusCode})',
          ));
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your network.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during verify email: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Verification error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return 'Email verified successfully';
  }

  @override
  Future<String> forgotPassword({required String email}) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authForgotPasswordEndpoint}');
      AppLogger.info('Calling forgot password API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'email': email.trim(),
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Forgot password status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return data['message'] as String? ?? 'Password reset OTP sent to your email';
        } else {
          throw Exception(_parseErrorMessage(
            response.body,
            'Request failed (${response.statusCode})',
          ));
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your network.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during forgot password: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Forgot password error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return 'Password reset OTP sent to your email';
  }

  @override
  Future<String> verifyResetOtp({required String email, required String otp}) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (otp.trim().isEmpty) {
      throw Exception('Please enter the reset OTP.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authVerifyResetOtpEndpoint}');
      AppLogger.info('Calling verify reset OTP API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'email': email.trim(),
                'otp': otp.trim(),
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Verify reset OTP status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final resetToken = data['reset_token'] as String?;
          if (resetToken == null || resetToken.isEmpty) {
            throw Exception('Did not receive reset token from server.');
          }
          return resetToken;
        } else {
          throw Exception(_parseErrorMessage(
            response.body,
            'OTP verification failed (${response.statusCode})',
          ));
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your network.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during verify reset OTP: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('OTP verification error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return 'mock_reset_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    if (resetToken.trim().isEmpty) {
      throw Exception('Reset token is required.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    if (!ApiConfig.useMock) {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authResetPasswordEndpoint}');
      AppLogger.info('Calling reset password API: $url');

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'accept': '*/*',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'reset_token': resetToken.trim(),
                'new_password': newPassword,
              }),
            )
            .timeout(ApiConfig.requestTimeout);

        AppLogger.info('Reset password status: ${response.statusCode}, body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return data['message'] as String? ?? 'Password reset successful';
        } else {
          throw Exception(_parseErrorMessage(
            response.body,
            'Reset failed (${response.statusCode})',
          ));
        }
      } on TimeoutException {
        throw Exception('Connection timed out. Please check your network.');
      } on http.ClientException catch (e) {
        AppLogger.error('ClientException during reset password: $e');
        throw Exception('Unable to reach backend server at ${ApiConfig.baseUrl}.');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Password reset error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return 'Password reset successful';
  }

  String _parseErrorMessage(String body, String defaultMessage) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] != null) {
          if (decoded['detail'] is String) {
            return decoded['detail'] as String;
          } else if (decoded['detail'] is List && (decoded['detail'] as List).isNotEmpty) {
            final first = (decoded['detail'] as List).first;
            if (first is Map && first['msg'] != null) {
              return first['msg'].toString();
            }
            return first.toString();
          }
        } else if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {}
    return body.isNotEmpty ? body : defaultMessage;
  }

  @override
  Future<UserProfile> updateProfile({String? name}) async {
    // TODO(backend): Call PATCH /auth/profile
    if (_currentUser == null) throw Exception('No active session.');
    await Future.delayed(const Duration(milliseconds: 400));

    final updated = _currentUser!.copyWith(
      name: name?.trim() ?? _currentUser!.name,
    );

    _currentUser = updated;
    await _storage.saveUserProfile(updated);
    _authController.add(updated);
    return updated;
  }

  void dispose() {
    _authController.close();
  }
}

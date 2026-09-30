import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatbot/data/datasources/local_storage.dart';
import 'package:chatbot/data/repositories/auth_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepositoryImpl Tests', () {
    late LocalStorage storage;
    late AuthRepositoryImpl authRepo;

    late _MockHttpClient defaultMockClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorage(prefs);
      defaultMockClient = _MockHttpClient((request) async {
        if (request.url.path == '/users/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'test_access_token',
              'refresh_token': 'test_refresh_token',
              'token_type': 'bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"OK"}', 200, headers: {'content-type': 'application/json'});
      });
      authRepo = AuthRepositoryImpl(
        localStorage: storage,
        client: defaultMockClient,
      );
    });

    test('continueAsGuest sets guest user session', () async {
      final user = await authRepo.continueAsGuest();

      expect(user.isGuest, isTrue);
      expect(user.name, 'Guest User');

      final current = await authRepo.getCurrentUser();
      expect(current?.id, user.id);
    });

    test('login validates email format', () async {
      expect(
        () => authRepo.login('invalidemail', '123456'),
        throwsA(isA<Exception>()),
      );
    });

    test('login validates password length', () async {
      expect(
        () => authRepo.login('user@example.com', '123'),
        throwsA(isA<Exception>()),
      );
    });

    test('successful login persists profile and emits on stream', () async {
      final user = await authRepo.login('alex@example.com', 'password123');

      expect(user.email, 'alex@example.com');
      expect(user.isGuest, isFalse);

      final loaded = storage.loadUserProfile();
      expect(loaded?.email, 'alex@example.com');
      expect(storage.getAccessToken(), 'test_access_token');
    });

    test('logout clears user session', () async {
      await authRepo.continueAsGuest();
      expect(await authRepo.getCurrentUser(), isNotNull);

      await authRepo.logout();
      expect(await authRepo.getCurrentUser(), isNull);
      expect(storage.loadUserProfile(), isNull);
    });

    test('signup validates matching confirm_password', () async {
      expect(
        () => authRepo.signup('keval', 'keval@example.com', '123456', 'different'),
        throwsA(
          predicate(
            (e) => e.toString().contains('Password and confirm password do not match'),
          ),
        ),
      );
    });

    test('signup calls POST /users/signup with exact curl payload', () async {
      http.Request? capturedRequest;
      final mockClient = _MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'message': 'Signup successful. Check your email for the verification OTP.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = AuthRepositoryImpl(
        localStorage: storage,
        client: mockClient,
      );

      final user = await testRepo.signup(
        'keval',
        'goswamikeval033@gmail.com',
        '123456',
        '123456',
      );

      expect(user.name, 'keval');
      expect(user.email, 'goswamikeval033@gmail.com');
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/users/signup');
      expect(capturedRequest!.method, 'POST');

      final body = jsonDecode(capturedRequest!.body);
      expect(body['name'], 'keval');
      expect(body['email'], 'goswamikeval033@gmail.com');
      expect(body['password'], '123456');
      expect(body['confirm_password'], '123456');
    });

    test('verifyEmail calls POST /users/verify-email with email and otp', () async {
      http.Request? capturedRequest;
      final mockClient = _MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Email verified successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = AuthRepositoryImpl(localStorage: storage, client: mockClient);
      final result = await testRepo.verifyEmail(email: 'test@example.com', otp: '123456');

      expect(result, 'Email verified successfully');
      expect(capturedRequest?.url.path, '/users/verify-email');
      final body = jsonDecode(capturedRequest!.body);
      expect(body['email'], 'test@example.com');
      expect(body['otp'], '123456');
    });

    test('forgotPassword calls POST /users/forgot-password with email', () async {
      http.Request? capturedRequest;
      final mockClient = _MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Password reset OTP sent to your email'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = AuthRepositoryImpl(localStorage: storage, client: mockClient);
      final result = await testRepo.forgotPassword(email: 'test@example.com');

      expect(result, 'Password reset OTP sent to your email');
      expect(capturedRequest?.url.path, '/users/forgot-password');
      final body = jsonDecode(capturedRequest!.body);
      expect(body['email'], 'test@example.com');
    });

    test('verifyResetOtp calls POST /users/verify-reset-otp and returns reset_token', () async {
      http.Request? capturedRequest;
      final mockClient = _MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'message': 'OTP verified',
            'reset_token': 'mock_jwt_reset_token',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = AuthRepositoryImpl(localStorage: storage, client: mockClient);
      final token = await testRepo.verifyResetOtp(email: 'test@example.com', otp: '654321');

      expect(token, 'mock_jwt_reset_token');
      expect(capturedRequest?.url.path, '/users/verify-reset-otp');
      final body = jsonDecode(capturedRequest!.body);
      expect(body['email'], 'test@example.com');
      expect(body['otp'], '654321');
    });

    test('resetPassword calls POST /users/reset-password with reset_token and new_password', () async {
      http.Request? capturedRequest;
      final mockClient = _MockHttpClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Password reset successful'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = AuthRepositoryImpl(localStorage: storage, client: mockClient);
      final result = await testRepo.resetPassword(
        resetToken: 'mock_jwt_reset_token',
        newPassword: 'newSecretPassword123',
      );

      expect(result, 'Password reset successful');
      expect(capturedRequest?.url.path, '/users/reset-password');
      final body = jsonDecode(capturedRequest!.body);
      expect(body['reset_token'], 'mock_jwt_reset_token');
      expect(body['new_password'], 'newSecretPassword123');
    });
  });
}

class _MockHttpClient extends http.BaseClient {
  _MockHttpClient(this.handler);
  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final httpRequest = http.Request(request.method, request.url)..bodyBytes = bytes;
    httpRequest.headers.addAll(request.headers);
    final response = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

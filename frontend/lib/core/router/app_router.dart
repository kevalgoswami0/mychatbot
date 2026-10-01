import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_durations.dart';
import '../../data/providers/repository_providers.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/auth/verify_reset_otp_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../features/users/users_screen.dart';
import 'route_names.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Custom transition: subtle fade + slight slide (250ms, easeOutCubic)
CustomTransitionPage<T> _buildSmoothPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.standard,
    reverseTransitionDuration: AppDurations.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppDurations.defaultCurve,
      );

      final slideTween = Tween<Offset>(
        begin: const Offset(0.04, 0.0),
        end: Offset.zero,
      );

      final fadeTween = Tween<double>(
        begin: 0.0,
        end: 1.0,
      );

      return SlideTransition(
        position: slideTween.animate(curved),
        child: FadeTransition(
          opacity: fadeTween.animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(localStorageProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshListenable = _AuthRefreshNotifier(authRepo.authStateChanges);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refreshListenable,
    initialLocation: AppRoutes.splashPath,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onboardingDone = storage.isOnboardingCompleted();
      final user = storage.loadUserProfile();

      // Allow splash to perform initial presentation
      if (loc == AppRoutes.splashPath) {
        return null;
      }

      // If onboarding is not done and trying to access protected routes
      if (!onboardingDone && loc != AppRoutes.onboardingPath) {
        return AppRoutes.onboardingPath;
      }

      // If user is unauthenticated and trying to access protected routes
      if (onboardingDone && user == null) {
        const allowedUnauth = [
          AppRoutes.authPath,
          AppRoutes.onboardingPath,
          AppRoutes.verifyEmailPath,
          AppRoutes.forgotPasswordPath,
          AppRoutes.verifyResetOtpPath,
          AppRoutes.resetPasswordPath,
        ];
        if (!allowedUnauth.contains(loc)) {
          return AppRoutes.authPath;
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splash,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboarding,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),

      // Auth
      GoRoute(
        path: AppRoutes.authPath,
        name: AppRoutes.auth,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const AuthScreen(),
        ),
      ),

      // Verify Email
      GoRoute(
        path: AppRoutes.verifyEmailPath,
        name: AppRoutes.verifyEmail,
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? state.uri.queryParameters['email'];
          return _buildSmoothPage(
            context: context,
            state: state,
            child: VerifyEmailScreen(email: email),
          );
        },
      ),

      // Forgot Password
      GoRoute(
        path: AppRoutes.forgotPasswordPath,
        name: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),

      // Verify Reset OTP
      GoRoute(
        path: AppRoutes.verifyResetOtpPath,
        name: AppRoutes.verifyResetOtp,
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? state.uri.queryParameters['email'];
          return _buildSmoothPage(
            context: context,
            state: state,
            child: VerifyResetOtpScreen(email: email),
          );
        },
      ),

      // Reset Password
      GoRoute(
        path: AppRoutes.resetPasswordPath,
        name: AppRoutes.resetPassword,
        pageBuilder: (context, state) {
          String? resetToken;
          String? email;
          if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            resetToken = map['resetToken'] as String?;
            email = map['email'] as String?;
          } else if (state.extra is String) {
            resetToken = state.extra as String;
          }
          resetToken ??= state.uri.queryParameters['reset_token'] ?? state.uri.queryParameters['token'];
          email ??= state.uri.queryParameters['email'];

          return _buildSmoothPage(
            context: context,
            state: state,
            child: ResetPasswordScreen(
              resetToken: resetToken,
              email: email,
            ),
          );
        },
      ),

      // Primary Chat Screen (Bottom navigation removed - top-right menu drawer is used)
      GoRoute(
        path: AppRoutes.chatPath,
        name: AppRoutes.chat,
        pageBuilder: (context, state) {
          final convId = state.uri.queryParameters['id'];
          final user = storage.loadUserProfile();
          return _buildSmoothPage(
            context: context,
            state: state,
            child: ChatScreen(
              key: ValueKey('chat_${user?.id ?? "unauth"}_${convId ?? "new"}'),
              conversationId: convId,
            ),
          );
        },
      ),

      // History
      GoRoute(
        path: AppRoutes.historyPath,
        name: AppRoutes.history,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const HistoryScreen(),
        ),
      ),

      // Users Directory
      GoRoute(
        path: AppRoutes.usersPath,
        name: AppRoutes.users,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const UsersScreen(),
        ),
      ),

      // Profile
      GoRoute(
        path: AppRoutes.profilePath,
        name: AppRoutes.profile,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),

      // Settings (All settings and profile consolidated into ProfileScreen)
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settings,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),

      // Subscriptions
      GoRoute(
        path: AppRoutes.subscriptionPath,
        name: AppRoutes.subscription,
        pageBuilder: (context, state) => _buildSmoothPage(
          context: context,
          state: state,
          child: const SubscriptionScreen(),
        ),
      ),
    ],
  );
});

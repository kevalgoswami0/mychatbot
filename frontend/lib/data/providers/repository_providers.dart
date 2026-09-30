import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/repositories/users_repository.dart';
import '../datasources/local_storage.dart';
import '../datasources/mock_chat_datasource.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/chat_repository_impl.dart';
import '../repositories/subscription_repository_impl.dart';
import '../repositories/users_repository_impl.dart';

/// Provider for LocalStorage instance.
/// Overridden in main.dart once SharedPreferences is initialized.
final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('localStorageProvider must be overridden in main()');
});

/// Provider for MockChatDatasource.
final mockChatDatasourceProvider = Provider<MockChatDatasource>((ref) {
  return MockChatDatasource();
});

/// Provider for ChatRepository.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ChatRepositoryImpl(localStorage: storage);
});

/// Provider for AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AuthRepositoryImpl(localStorage: storage);
});

/// Provider for SubscriptionRepository.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return SubscriptionRepositoryImpl(localStorage: storage);
});

/// Provider for UsersRepository.
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepositoryImpl();
});

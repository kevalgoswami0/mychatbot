import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/backend_user.dart';
import '../../../data/providers/repository_providers.dart';

final usersListProvider = FutureProvider<List<BackendUser>>((ref) async {
  final repo = ref.watch(usersRepositoryProvider);
  return repo.getUsers();
});

class UserSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final userSearchQueryProvider =
    NotifierProvider<UserSearchQueryNotifier, String>(UserSearchQueryNotifier.new);

final filteredUsersProvider = Provider<List<BackendUser>>((ref) {
  final users = ref.watch(usersListProvider).value ?? [];
  final query = ref.watch(userSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return users;
  return users.where((u) {
    return u.name.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query) ||
        u.id.toString().contains(query);
  }).toList();
});

import '../../data/models/backend_user.dart';

/// Contract for fetching user accounts from backend GET /users/.
abstract class UsersRepository {
  /// Fetch list of registered users.
  Future<List<BackendUser>> getUsers();
}

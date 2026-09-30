import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/users_repository.dart';
import '../models/backend_user.dart';

class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<BackendUser>> getUsers() async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersListEndpoint}');
    AppLogger.info('Fetching users list from: $url');

    try {
      final response = await _client.get(
        url,
        headers: {'accept': '*/*'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((item) => BackendUser.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load users (${response.statusCode})');
      }
    } catch (e, st) {
      AppLogger.error('Error fetching users from $url', error: e, stackTrace: st);
      rethrow;
    }
  }
}

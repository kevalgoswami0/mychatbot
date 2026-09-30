import 'package:flutter/foundation.dart';

/// User record returned by backend GET /users/ endpoint.
@immutable
class BackendUser {
  const BackendUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isEmailVerified,
  });

  final int id;
  final String name;
  final String email;
  final bool isEmailVerified;

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? '',
      isEmailVerified: json['is_email_verified'] == true,
    );
  }
}

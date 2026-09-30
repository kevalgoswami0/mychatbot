import 'dart:convert';
import 'package:flutter/foundation.dart';

/// User profile entity.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.isGuest = false,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final bool isGuest;
  final DateTime createdAt;
  final String? avatarUrl;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    bool? isGuest,
    DateTime? createdAt,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isGuest': isGuest,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      isGuest: map['isGuest'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.isGuest == isGuest &&
        other.createdAt == createdAt &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        isGuest.hashCode ^
        createdAt.hashCode ^
        avatarUrl.hashCode;
  }
}

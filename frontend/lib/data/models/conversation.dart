import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

/// Immutable Conversation entity representing an individual chat session.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.model = AppConstants.defaultModelName,
    this.messageCount = 0,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final String model;
  final int messageCount;

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    String? model,
    int? messageCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      model: model ?? this.model,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastMessage': lastMessage,
      'model': model,
      'messageCount': messageCount,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    final rawId = map['id'] ?? map['conversation_id'];

    return Conversation(
      id: rawId?.toString() ?? '',
      title: map['title']?.toString() ?? 'New Chat',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
      lastMessage: map['lastMessage']?.toString() ?? map['last_message']?.toString(),
      model: map['model']?.toString() ?? AppConstants.defaultModelName,
      messageCount: (map['messageCount'] as num?)?.toInt() ??
          (map['message_count'] as num?)?.toInt() ??
          0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Conversation.fromJson(String source) =>
      Conversation.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation &&
        other.id == id &&
        other.title == title &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastMessage == lastMessage &&
        other.model == model &&
        other.messageCount == messageCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        lastMessage.hashCode ^
        model.hashCode ^
        messageCount.hashCode;
  }
}

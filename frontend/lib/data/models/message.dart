import 'dart:convert';
import 'package:flutter/foundation.dart';

enum MessageRole {
  user,
  assistant,
  system;

  String toJson() => name;
  static MessageRole fromJson(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}

enum MessageStatus {
  sending,
  streaming,
  sent,
  failed;

  String toJson() => name;
  static MessageStatus fromJson(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MessageStatus.sent,
    );
  }
}

/// Immutable message model for chat threads.
@immutable
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.errorMessage,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final String? errorMessage;

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get isFailed => status == MessageStatus.failed;
  bool get isSent => status == MessageStatus.sent;

  Message copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    DateTime? createdAt,
    MessageStatus? status,
    String? errorMessage,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role.toJson(),
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toJson(),
      'errorMessage': errorMessage,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    final rawId = map['id'];
    final rawConvId = map['conversationId'] ?? map['conversation_id'];

    return Message(
      id: rawId?.toString() ?? '',
      conversationId: rawConvId?.toString() ?? '',
      role: MessageRole.fromJson(map['role']?.toString() ?? 'user'),
      content: map['content']?.toString() ?? '',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      status: MessageStatus.fromJson(map['status']?.toString() ?? 'sent'),
      errorMessage: map['errorMessage']?.toString() ?? map['error_message']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Message.fromJson(String source) =>
      Message.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.role == role &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        conversationId.hashCode ^
        role.hashCode ^
        content.hashCode ^
        createdAt.hashCode ^
        status.hashCode ^
        errorMessage.hashCode;
  }
}

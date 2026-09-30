import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot/data/models/conversation.dart';
import 'package:chatbot/data/models/message.dart';
import 'package:chatbot/data/models/user_profile.dart';

void main() {
  group('Message Model Tests', () {
    test('Message serialization roundtrip', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.user,
        content: 'Hello, Nova Chat!',
        createdAt: now,
        status: MessageStatus.sent,
      );

      final map = message.toMap();
      final fromMap = Message.fromMap(map);

      expect(fromMap.id, message.id);
      expect(fromMap.conversationId, message.conversationId);
      expect(fromMap.role, message.role);
      expect(fromMap.content, message.content);
      expect(fromMap.status, message.status);
    });

    test('Message copyWith updates correctly', () {
      final message = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.assistant,
        content: 'Initial text',
        createdAt: DateTime.now(),
        status: MessageStatus.streaming,
      );

      final updated = message.copyWith(
        content: 'Completed text',
        status: MessageStatus.sent,
      );

      expect(updated.id, 'msg-1');
      expect(updated.content, 'Completed text');
      expect(updated.status, MessageStatus.sent);
      expect(updated.isStreaming, isFalse);
    });
  });

  group('Conversation Model Tests', () {
    test('Conversation serialization roundtrip', () {
      final now = DateTime.now();
      final conv = Conversation(
        id: 'conv-1',
        title: 'Project Architecture',
        createdAt: now,
        updatedAt: now,
        lastMessage: 'Let us plan the layers.',
      );

      final jsonStr = conv.toJson();
      final fromJson = Conversation.fromJson(jsonStr);

      expect(fromJson.id, conv.id);
      expect(fromJson.title, conv.title);
      expect(fromJson.lastMessage, conv.lastMessage);
    });
  });

  group('UserProfile Model Tests', () {
    test('UserProfile guest session detection', () {
      final guest = UserProfile(
        id: 'guest-1',
        name: 'Guest User',
        email: 'guest@novachat.ai',
        isGuest: true,
        createdAt: DateTime.now(),
      );

      expect(guest.isGuest, isTrue);

      final user = guest.copyWith(isGuest: false, name: 'Alex Morgan');
      expect(user.isGuest, isFalse);
      expect(user.name, 'Alex Morgan');
    });
  });
}

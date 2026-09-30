import '../../data/models/conversation.dart';
import '../../data/models/message.dart';

/// Abstract contract for Chat operations.
/// Defines all required operations for both Mock and Real API implementations.
abstract class ChatRepository {
  /// Retrieve all user conversations ordered by updatedAt descending.
  Future<List<Conversation>> getConversations();

  /// Create a new blank conversation session.
  Future<Conversation> createConversation({String? initialTitle});

  /// Delete a conversation and all its associated messages.
  Future<void> deleteConversation(String id);

  /// Rename conversation title.
  Future<void> renameConversation(String id, String title);

  /// Clear all stored conversations and messages.
  Future<void> clearAllConversations();

  /// Retrieve all messages for a specific conversation.
  Future<List<Message>> getMessages(String conversationId);

  /// Send a user message and stream the assistant's reply token-by-token.
  Stream<String> sendMessage(
    String conversationId,
    String text, {
    String? userMessageId,
    String? assistantMessageId,
  });

  /// Abort/cancel the ongoing message generation stream.
  Future<void> stopGeneration();

  /// Delete an individual message from a conversation.
  Future<void> deleteMessage(String conversationId, String messageId);

  /// Save or replace the full message list for a conversation.
  Future<void> saveMessages(String conversationId, List<Message> messages);

  /// Regenerate the response for a specific bot message.
  Stream<String> regenerateMessage(String conversationId, String messageId);
}

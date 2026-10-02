import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/local_storage.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../datasources/mock_chat_datasource.dart';

import 'package:audioplayers/audioplayers.dart';

/// Production ChatRepository connecting to FastAPI backend REST and WebSocket APIs.
/// Features auto-refreshing JWT authentication, letter-by-letter typewriter streaming,
/// and graceful fallback handling.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required LocalStorage localStorage,
    http.Client? client,
    MockChatDatasource? mockDatasource,
  }) : _storage = localStorage,
       _client = client ?? http.Client(),
       _mockDatasource = mockDatasource ?? MockChatDatasource();

  final LocalStorage _storage;
  final http.Client _client;
  final MockChatDatasource _mockDatasource;
  final Uuid _uuid = const Uuid();

  WebSocketChannel? _activeWsChannel;

  /// Check if a JWT token is expired or close to expiring (within 60 seconds)
  bool _isTokenExpired(String? token) {
    if (token == null || token.trim().isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payloadNormalized = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(payloadNormalized);
      final payloadJson =
          jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      final exp = payloadJson['exp'];
      if (exp is num) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
        return DateTime.now().toUtc().isAfter(
          expiryTime.subtract(const Duration(seconds: 60)),
        );
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Helper to get valid access token, auto-refreshing via POST /users/refresh if expired
  Future<String?> _getValidAccessToken({bool forceRefresh = false}) async {
    final token = _storage.getAccessToken();
    if (!forceRefresh &&
        token != null &&
        token.isNotEmpty &&
        !_isTokenExpired(token)) {
      return token;
    }

    final refreshToken = _storage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        AppLogger.info('Refreshing JWT access token...');
        final res = await _client
            .post(
              Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authRefreshEndpoint}'),
              headers: {'Content-Type': 'application/json', 'accept': '*/*'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          final newToken = data['access_token'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            await _storage.saveAuthTokens(
              accessToken: newToken,
              refreshToken: refreshToken,
            );
            AppLogger.info('Access token refreshed successfully.');
            return newToken;
          }
        } else {
          AppLogger.warning('Token refresh returned status: ${res.statusCode}');
        }
      } catch (e) {
        AppLogger.warning('Token refresh failed: $e');
      }
    }
    return token;
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final token = await _getValidAccessToken(forceRefresh: forceRefresh);
    return {
      'accept': '*/*',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Automatically retries once with refreshed token if request returns 401 Unauthorized
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = await _authHeaders();
    var response = await requestFn(headers).timeout(ApiConfig.requestTimeout);

    if (response.statusCode == 401) {
      AppLogger.info(
        'Received 401 Unauthorized. Retrying with refreshed token...',
      );
      headers = await _authHeaders(forceRefresh: true);
      response = await requestFn(headers).timeout(ApiConfig.requestTimeout);
    }

    return response;
  }

  @override
  Future<List<Conversation>> getConversations() async {
    try {
      final token = await _getValidAccessToken();
      if (token == null || token.isEmpty) {
        return _storage.loadConversations();
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.conversationsEndpoint}',
      );
      AppLogger.info('Fetching conversations from: $url');

      final response = await _authenticatedRequest(
        (headers) => _client.get(url, headers: headers),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final conversations = decoded
              .map((item) => Conversation.fromMap(item as Map<String, dynamic>))
              .toList();

          await _storage.saveConversations(conversations);
          return conversations;
        }
      } else if (response.statusCode == 401) {
        AppLogger.warning(
          'Unauthorized when fetching conversations, returning empty/cached',
        );
        return [];
      }
    } catch (e, st) {
      AppLogger.warning(
        'Failed to fetch remote conversations, loading from cache: $e',
        stackTrace: st,
      );
    }

    try {
      return _storage.loadConversations();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Conversation> createConversation({String? initialTitle}) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.conversationsEndpoint}',
    );
    AppLogger.info('Creating conversation on backend: $url');

    try {
      final response = await _authenticatedRequest(
        (headers) => _client.post(url, headers: headers),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        Conversation conversation = Conversation.fromMap(data);

        if (initialTitle != null &&
            initialTitle.isNotEmpty &&
            initialTitle != 'New Chat') {
          await renameConversation(conversation.id, initialTitle);
          conversation = conversation.copyWith(title: initialTitle);
        }

        final currentList = _storage.loadConversations();
        await _storage.saveConversations([
          conversation,
          ...currentList.where((c) => c.id != conversation.id),
        ]);
        return conversation;
      }
    } catch (e, st) {
      AppLogger.error(
        'Backend createConversation failed, falling back to local: $e',
        stackTrace: st,
      );
    }

    // Local fallback: use timestamp integer string so path parameters in backend never error with 422
    final now = DateTime.now();
    final newConversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: initialTitle ?? 'New Chat',
      createdAt: now,
      updatedAt: now,
      model: AppConstants.defaultModelName,
      messageCount: 0,
    );

    final currentList = _storage.loadConversations();
    final updatedList = [newConversation, ...currentList];
    await _storage.saveConversations(updatedList);
    return newConversation;
  }

  @override
  Future<void> deleteConversation(String id) async {
    final int? convIntId = int.tryParse(id);
    if (convIntId != null) {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.conversationDetailEndpoint(convIntId)}',
      );
      AppLogger.info('Deleting conversation from backend: $url');

      try {
        await _authenticatedRequest(
          (headers) => _client.delete(url, headers: headers),
        );
      } catch (e) {
        AppLogger.warning('Failed to delete conversation on backend: $e');
      }
    }

    final currentList = _storage.loadConversations();
    final updatedList = currentList.where((c) => c.id != id).toList();
    await _storage.saveConversations(updatedList);
    await _storage.deleteMessages(id);
  }

  @override
  Future<void> renameConversation(String id, String title) async {
    final trimmedTitle = title.trim().isEmpty
        ? 'Untitled Conversation'
        : title.trim();
    final int? convIntId = int.tryParse(id);

    if (convIntId != null) {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.conversationDetailEndpoint(convIntId)}',
      );
      AppLogger.info('Renaming conversation on backend: $url');

      try {
        await _authenticatedRequest(
          (headers) => _client.patch(
            url,
            headers: headers,
            body: jsonEncode({'title': trimmedTitle}),
          ),
        );
      } catch (e) {
        AppLogger.warning('Failed to rename conversation on backend: $e');
      }
    }

    final currentList = _storage.loadConversations();
    final updatedList = currentList.map((c) {
      if (c.id == id) {
        return c.copyWith(title: trimmedTitle, updatedAt: DateTime.now());
      }
      return c;
    }).toList();
    await _storage.saveConversations(updatedList);
  }

  @override
  Future<void> clearAllConversations() async {
    final list = _storage.loadConversations();
    for (final c in list) {
      try {
        await deleteConversation(c.id);
      } catch (_) {}
    }
    await _storage.clearAllChatData();
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async {
    if (conversationId.trim().isEmpty) return const [];
    final localMessages = _storage.loadMessages(conversationId);

    final int? convIntId = int.tryParse(conversationId);
    if (convIntId != null) {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.conversationMessagesEndpoint(convIntId)}',
      );
      AppLogger.info('Fetching messages from: $url');

      try {
        final response = await _authenticatedRequest(
          (headers) => _client.get(url, headers: headers),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            final remoteMessages = decoded
                .map((item) => Message.fromMap(item as Map<String, dynamic>))
                .toList();

            if (remoteMessages.isNotEmpty) {
              await _storage.saveMessages(conversationId, remoteMessages);
              return remoteMessages;
            }
          }
        }
      } catch (e, st) {
        AppLogger.warning(
          'Failed to fetch remote messages, using local: $e',
          stackTrace: st,
        );
      }
    }

    return localMessages;
  }

  /// Transforms text chunks into a smoothly paced token/word stream (~2ms per token)
  /// keeping words and markdown headers intact without flickering.
  Stream<String> _streamPaced(Stream<String> rawStream) async* {
    await for (final chunk in rawStream) {
      final matches = RegExp(r'(\s+|[^\s]+)').allMatches(chunk);
      if (matches.isEmpty) {
        yield chunk;
      } else {
        for (final match in matches) {
          final token = match.group(0)!;
          yield token;
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }
    }
  }

  /// Internal generator obtaining raw text chunks from WebSocket, HTTP fallback, or Mock.
  Stream<String> _fetchRawChunks(
    String conversationId,
    String text,
    Message assistantPlaceholder,
  ) async* {
    final token = await _getValidAccessToken();
    final AudioPlayer audioPlayer = AudioPlayer();

    // 1. WebSocket Streaming (FastAPI /users/ws/chat/{id})
    if (token != null && token.isNotEmpty) {
      final wsUrl = ApiConfig.wsChatEndpoint(conversationId, token);
      AppLogger.info('Connecting to WebSocket chat: $wsUrl');

      WebSocketChannel? channel;
      bool receivedAnyChunk = false;

      try {
        channel = WebSocketChannel.connect(Uri.parse(wsUrl));
        _activeWsChannel = channel;

        await channel.ready;

        // Send message JSON payload

        channel.sink.add(
          jsonEncode({'message': text.trim(), 'language': 'en'}),
        );

        AppLogger.info('WebSocket prompt sent, awaiting streaming chunks...');

        await for (final rawMsg in channel.stream) {
          // Handle binary WAV audio
          if (rawMsg is List<int>) {
            AppLogger.info('Received WAV audio: ${rawMsg.length} bytes');

            try {
              await audioPlayer.play(BytesSource(Uint8List.fromList(rawMsg)));

              AppLogger.info('WAV audio playback started');
            } catch (e, st) {
              AppLogger.error(
                'WAV playback failed: $e',
                error: e,
                stackTrace: st,
              );
            }

            continue;
          }

          // Handle JSON messages
          final Map<String, dynamic> data = jsonDecode(rawMsg.toString());

          final type = data['type'] as String?;

          if (type == 'chunk') {
            final chunk = data['content'] as String? ?? '';
            if (chunk.isNotEmpty) {
              receivedAnyChunk = true;
              yield chunk;
            }
          } else if (type == 'message_complete') {
            AppLogger.info('WebSocket streaming completed successfully');
            break;
          } else if (type == 'error') {
            final errMsg = data['message']?.toString() ?? 'An error occurred';
            throw Exception(errMsg);
          }
        }
        return;
      } catch (e, st) {
        AppLogger.error(
          'WebSocket chat stream error: $e',
          error: e,
          stackTrace: st,
        );
        final errString = e.toString().toLowerCase();
        final isLimitError =
            errString.contains('free chat limit') ||
            errString.contains('daily limit') ||
            errString.contains('limit_exceeded') ||
            errString.contains('2 min/day') ||
            errString.contains('10 min/day') ||
            errString.contains('upgrade for unlimited') ||
            (errString.contains('1008') &&
                !errString.contains('rate') &&
                !errString.contains('tpm'));

        // If WebSocket failed before yielding any chunk and is NOT a limit error, attempt HTTP fallback
        if (!receivedAnyChunk && !isLimitError) {
          AppLogger.info('Attempting HTTP fallback chat endpoint...');
          final httpUrl = Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.chatHttpEndpoint}',
          );
          final int? convIntId = int.tryParse(conversationId);
          if (convIntId != null) {
            try {
              final httpRes = await _authenticatedRequest(
                (headers) => _client.post(
                  httpUrl,
                  headers: headers,
                  body: jsonEncode({
                    'conversation_id': convIntId,
                    'message': text.trim(),
                  }),
                ),
              );

              if (httpRes.statusCode >= 200 && httpRes.statusCode < 300) {
                final httpData = jsonDecode(httpRes.body);
                final reply = httpData['response']?.toString() ?? '';
                if (reply.isNotEmpty) {
                  yield reply;
                  return;
                }
              } else if (httpRes.statusCode == 403) {
                throw Exception(
                  'Daily limit reached (2 min). Upgrade to continue.',
                );
              }
            } catch (fallbackErr) {
              final fbErr = fallbackErr.toString().toLowerCase();
              if (fbErr.contains('free chat limit') ||
                  fbErr.contains('2 min/day') ||
                  fbErr.contains('10 min/day') ||
                  fbErr.contains('daily limit')) {
                rethrow;
              }
              AppLogger.warning('HTTP chat fallback failed: $fallbackErr');
            }
          }
        }

        String userFriendlyError =
            'Connection interrupted. Please tap to retry.';
        if (isLimitError) {
          userFriendlyError =
              'Daily limit reached (2 min). Upgrade to continue.';
        } else if (errString.contains('not found')) {
          userFriendlyError =
              'Conversation not found. Please start a new chat.';
        }

        throw Exception(userFriendlyError);
      } finally {
        channel?.sink.close();
        _activeWsChannel = null;
      }
    }

    // 2. Offline / Mock fallback
    await for (final token in _mockDatasource.streamReply(text.trim())) {
      yield token;
    }
  }

  @override
  Stream<String> sendMessage(
    String conversationId,
    String text, {
    String? userMessageId,
    String? assistantMessageId,
  }) async* {
    final now = DateTime.now();
    final effectiveUserMsgId = userMessageId ?? _uuid.v4();
    final userMessage = Message(
      id: effectiveUserMsgId,
      conversationId: conversationId,
      role: MessageRole.user,
      content: text.trim(),
      createdAt: now,
      status: MessageStatus.sent,
    );

    // 1. Save user message locally
    var messages = _storage.loadMessages(conversationId);
    messages.add(userMessage);
    await _storage.saveMessages(conversationId, messages);

    // 2. Update conversation title if first message
    _updateConversationMeta(
      conversationId,
      text.trim(),
      isFirst: messages.length <= 1,
    );

    // 3. Create initial empty assistant message placeholder
    final effectiveAssistantMsgId = assistantMessageId ?? _uuid.v4();
    final assistantPlaceholder = Message(
      id: effectiveAssistantMsgId,
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    messages.add(assistantPlaceholder);
    await _storage.saveMessages(conversationId, messages);

    final StringBuffer fullContent = StringBuffer();

    try {
      // 4. Stream response with smooth token/word pacing
      final stream = _streamPaced(
        _fetchRawChunks(conversationId, text, assistantPlaceholder),
      );

      await for (final token in stream) {
        fullContent.write(token);
        yield token;
      }

      // Finalize assistant message as sent
      final completedMessage = assistantPlaceholder.copyWith(
        content: fullContent.toString(),
        status: MessageStatus.sent,
      );
      _replaceMessage(conversationId, completedMessage);
      _updateConversationMeta(
        conversationId,
        fullContent.toString(),
        isFirst: false,
      );
    } catch (e) {
      final failedMessage = assistantPlaceholder.copyWith(
        content: fullContent.toString().isNotEmpty
            ? fullContent.toString()
            : (e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'An error occurred'),
        status: MessageStatus.failed,
        errorMessage: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'An error occurred',
      );
      _replaceMessage(conversationId, failedMessage);
      rethrow;
    }
  }

  @override
  Future<void> saveMessages(
    String conversationId,
    List<Message> messages,
  ) async {
    await _storage.saveMessages(conversationId, messages);
  }

  @override
  Future<void> stopGeneration() async {
    try {
      _activeWsChannel?.sink.close();
      _activeWsChannel = null;
      _mockDatasource.stopGeneration();
    } catch (_) {}
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final messages = _storage.loadMessages(conversationId);
    final updated = messages.where((m) => m.id != messageId).toList();
    await _storage.saveMessages(conversationId, updated);
  }

  @override
  Stream<String> regenerateMessage(
    String conversationId,
    String messageId,
  ) async* {
    final messages = _storage.loadMessages(conversationId);
    final targetIndex = messages.indexWhere((m) => m.id == messageId);
    if (targetIndex == -1) return;

    String userQuery = 'Provide an alternative response.';
    for (int i = targetIndex - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        userQuery = messages[i].content;
        break;
      }
    }

    final targetMessage = messages[targetIndex].copyWith(
      content: '',
      status: MessageStatus.streaming,
      errorMessage: null,
    );
    _replaceMessage(conversationId, targetMessage);

    final StringBuffer fullContent = StringBuffer();

    try {
      final stream = _streamPaced(
        _fetchRawChunks(conversationId, userQuery, targetMessage),
      );

      await for (final token in stream) {
        fullContent.write(token);
        yield token;
      }

      final completedMessage = targetMessage.copyWith(
        content: fullContent.toString(),
        status: MessageStatus.sent,
      );
      _replaceMessage(conversationId, completedMessage);
      _updateConversationMeta(
        conversationId,
        fullContent.toString(),
        isFirst: false,
      );
    } catch (e) {
      final failedMessage = targetMessage.copyWith(
        content: fullContent.toString(),
        status: MessageStatus.failed,
        errorMessage: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'An error occurred',
      );
      _replaceMessage(conversationId, failedMessage);
      rethrow;
    }
  }

  void _replaceMessage(String conversationId, Message updatedMessage) {
    final messages = _storage.loadMessages(conversationId);
    final idx = messages.indexWhere((m) => m.id == updatedMessage.id);
    if (idx != -1) {
      messages[idx] = updatedMessage;
      _storage.saveMessages(conversationId, messages);
    }
  }

  void _updateConversationMeta(
    String conversationId,
    String lastText, {
    required bool isFirst,
  }) {
    final conversations = _storage.loadConversations();
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final existing = conversations[idx];
      String newTitle = existing.title;
      if (isFirst ||
          existing.title == 'New Conversation' ||
          existing.title == 'New Chat') {
        newTitle = lastText.length > 32
            ? '${lastText.substring(0, 32)}...'
            : lastText;
      }

      conversations[idx] = existing.copyWith(
        title: newTitle,
        lastMessage: lastText.length > 60
            ? '${lastText.substring(0, 60)}...'
            : lastText,
        updatedAt: DateTime.now(),
        messageCount: existing.messageCount + 1,
      );
      _storage.saveConversations(conversations);
    }
  }
}

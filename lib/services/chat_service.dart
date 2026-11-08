import 'package:flutter_chess_app/models/chat_message_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:logger/logger.dart';

/// Talks to the self-hosted backend's `/chat` routes instead of Firestore.
///
/// NOTE: this only persists/reads messages via REST polling. There's no
/// instant push yet (that needs Socket.IO — see backend README, Phase 2),
/// so `getMessages` polls every 3 seconds. Swap this for a socket
/// listener once that's built; the Stream-shaped API here won't need to
/// change for callers.
class ChatService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  /// Kept for compatibility with existing call sites. The backend derives
  /// the actual room key itself from the two participants, so this is only
  /// used locally to figure out "who is the other participant" below.
  String getChatRoomId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}-${sorted[1]}';
  }

  String? _otherUserIdFromRoomId(String chatRoomId, String? myId) {
    final parts = chatRoomId.split('-');
    if (parts.length != 2 || myId == null) return null;
    return parts[0] == myId ? parts[1] : parts[0];
  }

  ChatMessage _fromJson(Map<String, dynamic> json) =>
      ChatMessage.fromMap(json['_id']?.toString() ?? '', json);

  String _otherIdOrThrow(String chatRoomId, String? myId) {
    final otherId = _otherUserIdFromRoomId(chatRoomId, myId);
    if (otherId == null) throw Exception('Could not resolve chat recipient');
    return otherId;
  }

  /// Sends a text message, or a sticker when [sticker] is true (then
  /// `message.text` is the sticker id). [replyToId] quotes another message.
  Future<void> sendMessage(
    String chatRoomId,
    ChatMessage message, {
    bool sticker = false,
    String? replyToId,
  }) async {
    try {
      final myId = await _api.currentUserId;
      final otherId = _otherIdOrThrow(chatRoomId, myId);
      await _api.post('/chat/$otherId/messages', body: {
        'text': message.text,
        if (sticker) 'type': 'sticker',
        if (replyToId != null) 'replyToId': replyToId,
      });
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Invites a friend to WATCH the running game [gameId] (read-only). Leaves a "watch"
  /// bubble in their chat; tapping it opens the spectator screen.
  Future<void> sendWatchInvite({required String gameId, required String friendId}) async {
    try {
      await _api.post('/games/$gameId/watch-invite', body: {'friendId': friendId});
    } catch (e) {
      _logger.e('Error sending watch invite: $e');
      rethrow;
    }
  }

  /// Sets your reaction on a message; pass null to remove it.
  Future<void> reactToMessage(String messageId, String? emoji) async {
    try {
      await _api.put('/chat/messages/$messageId/reaction', body: {'emoji': emoji ?? ''});
    } catch (e) {
      _logger.e('Error reacting to message: $e');
      rethrow;
    }
  }

  /// Deletes one of YOUR messages (for both people).
  Future<void> deleteMessage(String messageId) async {
    try {
      await _api.delete('/chat/messages/$messageId');
    } catch (e) {
      _logger.e('Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> reportUser({
    required String chatRoomId,
    required String reason,
    String? details,
    String? messageId,
  }) async {
    try {
      final myId = await _api.currentUserId;
      final otherId = _otherIdOrThrow(chatRoomId, myId);
      await _api.post('/chat/$otherId/report', body: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        if (messageId != null) 'messageId': messageId,
      });
    } catch (e) {
      _logger.e('Error reporting user: $e');
      rethrow;
    }
  }

  /// Live-updates instantly via the socket's `chat:message` push (see
  /// backend/controllers/chatController.js), with a 3-second poll as a
  /// safety net for messages sent before the socket connected.
  Stream<List<ChatMessage>> getMessages(String chatRoomId) async* {
    final myId = await _api.currentUserId;
    final otherId = _otherUserIdFromRoomId(chatRoomId, myId);
    if (otherId == null) {
      yield [];
      return;
    }

    Future<List<ChatMessage>> fetch() async {
      final result = await _api.get('/chat/$otherId/messages', query: {'limit': 100});
      return (result['messages'] as List)
          .map((j) => _fromJson(Map<String, dynamic>.from(j)))
          .toList()
          .reversed
          .toList();
    }

    while (true) {
      try {
        yield await fetch();
      } catch (e) {
        _logger.e('Error fetching messages: $e');
        yield [];
      }
      // Wait for either the poll interval OR a push event, whichever
      // comes first — pushes make this feel instant, the poll is just
      // a fallback for messages sent before the socket connected.
      await Future.any([
        Future.delayed(const Duration(seconds: 3)),
        GameSocketService.instance.onChatMessage.first,
      ]);
    }
  }

  Future<void> deleteChatMessages(String userId1, String userId2) async {
    try {
      final myId = await _api.currentUserId;
      final otherId = myId == userId1 ? userId2 : userId1;
      await _api.delete('/chat/$otherId');
    } catch (e) {
      _logger.e('Error deleting chat messages: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> markMessagesAsRead(String chatRoomId, String receiverId) async {
    try {
      // receiverId is the other participant.
      return await _api.put('/chat/$receiverId/read');
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
      rethrow;
    }
  }

  /// Polls every 5 seconds instead of a Firestore realtime snapshot.
  /// `currentUserId` param kept for compatibility; unused (see class note).
  Stream<int> getUnreadMessageCount(String chatRoomId, String currentUserId) async* {
    final myId = await _api.currentUserId;
    final otherId = _otherUserIdFromRoomId(chatRoomId, myId);
    if (otherId == null) {
      yield 0;
      return;
    }
    while (true) {
      try {
        final result = await _api.get('/chat/$otherId/unread-count');
        yield result['count'] ?? 0;
      } catch (e) {
        _logger.e('Error fetching unread count: $e');
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}

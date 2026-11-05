import 'package:flutter_chess_app/services/api_client.dart';
import 'package:logger/logger.dart';
import '../models/app_message_model.dart';

/// Talks to the backend's `/messages` (users) and `/admin/messages` (admin)
/// routes. Admin rights are enforced by the server, not by this class.
class MessageService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  // ───────────── user side ─────────────

  /// Newest first, 50 per page. Pass the previous page's `nextCursor` as
  /// [before] to get the next page. Throws on network / server errors.
  Future<MessagesPage> getMessages({String? before}) async {
    final result = await _api.get(
      '/messages',
      query: before == null ? null : {'before': before},
    );
    final list = (result['messages'] as List?) ?? const [];
    return MessagesPage(
      messages: list
          .map((m) => AppMessage.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      hasMore: result['hasMore'] == true,
      nextCursor: result['nextCursor']?.toString(),
    );
  }

  Future<int> getUnreadCount() async {
    try {
      final result = await _api.get('/messages/unread-count');
      return (result['unread'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _logger.e('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Full text of one message (does not count as click / read by itself).
  Future<AppMessage> getMessage(String id) async {
    final result = await _api.get('/messages/$id');
    return AppMessage.fromJson(
      Map<String, dynamic>.from(result['message'] as Map),
    );
  }

  /// User tapped the message in the list. Failures are ignored on purpose:
  /// tracking must never block the user from opening a message.
  Future<void> trackClick(String id) async {
    try {
      await _api.post('/messages/$id/click');
    } catch (e) {
      _logger.e('Error tracking message click: $e');
    }
  }

  /// User viewed the opened message.
  Future<void> trackRead(String id) async {
    try {
      await _api.post('/messages/$id/read');
    } catch (e) {
      _logger.e('Error tracking message read: $e');
    }
  }

  // ───────────── admin side ─────────────

  Future<List<AdminMessage>> adminGetMessages() async {
    final result = await _api.get('/admin/messages');
    final list = (result['messages'] as List?) ?? const [];
    return list
        .map((m) => AdminMessage.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<AdminMessageDetail> adminGetMessage(String id) async {
    final result = await _api.get('/admin/messages/$id');
    final message = AdminMessage.fromJson(
      Map<String, dynamic>.from(result['message'] as Map),
    );
    final receipts = ((result['receipts'] as List?) ?? const [])
        .map(
          (r) => MessageReceiptInfo.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    return AdminMessageDetail(message: message, receipts: receipts);
  }

  /// [audience]: 'all' | 'registered' | 'user' (then [targetUserId] is required).
  /// Returns the push status: 'queued' | 'not_configured' | 'off'.
  Future<String> adminSend({
    required String title,
    required String body,
    required String audience,
    String? targetUserId,
    bool sendPush = true,
  }) async {
    final result = await _api.post(
      '/admin/messages',
      body: {
        'title': title,
        'body': body,
        'audience': audience,
        if (targetUserId != null) 'targetUserId': targetUserId,
        'sendPush': sendPush,
      },
    );
    return result['push']?.toString() ?? 'off';
  }

  Future<List<MessageUserHit>> adminSearchUsers(String query) async {
    final result = await _api.get('/admin/message-users', query: {'q': query});
    return ((result['users'] as List?) ?? const [])
        .map((u) => MessageUserHit.fromJson(Map<String, dynamic>.from(u as Map)))
        .toList();
  }

  Future<void> adminSetActive(String id, bool isActive) async {
    await _api.put('/admin/messages/$id', body: {'isActive': isActive});
  }

  Future<void> adminDelete(String id) async {
    await _api.delete('/admin/messages/$id');
  }
}

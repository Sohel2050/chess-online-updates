import 'package:flutter_chess_app/utils/constants.dart';

class ChatReply {
  final String messageId;
  final String senderId;
  final String text;

  const ChatReply({
    required this.messageId,
    required this.senderId,
    required this.text,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  /// 'text' | 'sticker' | 'invite' | 'watch'. For a sticker, [text] is the sticker id.
  final String type;
  final ChatReply? replyTo;

  /// userId -> emoji (one reaction per person).
  final Map<String, String> reactions;
  final String? inviteGameId;
  final String? inviteGameMode;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
    this.replyTo,
    this.reactions = const {},
    this.inviteGameId,
    this.inviteGameMode,
  });

  bool get isSticker => type == 'sticker';
  bool get isInvite => type == 'invite';
  /// "Watch my game" invite: [inviteGameId] is the game to spectate.
  bool get isWatch => type == 'watch';

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final rawTimestamp = data[Constants.timestamp];

    ChatReply? reply;
    final rawReply = data['replyTo'];
    if (rawReply is Map) {
      reply = ChatReply(
        messageId: rawReply['messageId']?.toString() ?? '',
        senderId: rawReply['senderId']?.toString() ?? '',
        text: rawReply['text']?.toString() ?? '',
      );
    }

    final reactions = <String, String>{};
    final rawReactions = data['reactions'];
    if (rawReactions is List) {
      for (final r in rawReactions) {
        if (r is Map && r['userId'] != null && r['emoji'] != null) {
          reactions[r['userId'].toString()] = r['emoji'].toString();
        }
      }
    }

    return ChatMessage(
      id: id,
      senderId: data[Constants.senderId] ?? '',
      text: data[Constants.text] ?? '',
      timestamp: rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.tryParse(rawTimestamp?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      isRead: data[Constants.isRead] ?? false,
      type: data['type']?.toString() ?? 'text',
      replyTo: reply,
      reactions: reactions,
      inviteGameId: data['inviteGameId']?.toString(),
      inviteGameMode: data['inviteGameMode']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      Constants.senderId: senderId,
      Constants.text: text,
      Constants.timestamp: timestamp.toIso8601String(),
      Constants.isRead: isRead,
    };
  }
}

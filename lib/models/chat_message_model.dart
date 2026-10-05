import 'package:flutter_chess_app/utils/constants.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final rawTimestamp = data[Constants.timestamp];
    return ChatMessage(
      id: id,
      senderId: data[Constants.senderId] ?? '',
      text: data[Constants.text] ?? '',
      timestamp: rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now(),
      isRead: data[Constants.isRead] ?? false,
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

DateTime _parseDate(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

DateTime? _parseDateOrNull(dynamic value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

/// A message from the admin as a normal user sees it (Settings -> Messages).
class AppMessage {
  final String id;
  final String title;
  final String preview;
  final String body; // empty in list results, filled by getMessage()
  final DateTime createdAt;
  final bool isRead;
  final bool isClicked;

  const AppMessage({
    required this.id,
    required this.title,
    required this.preview,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.isClicked,
  });

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      preview: json['preview']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      isRead: json['isRead'] == true,
      isClicked: json['isClicked'] == true,
    );
  }
}

/// One page of the user's message list (50 at a time).
class MessagesPage {
  final List<AppMessage> messages;
  final bool hasMore;
  final String? nextCursor;

  const MessagesPage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });
}

/// A user found by the admin's search when sending to one person.
class MessageUserHit {
  final String id;
  final String displayName;
  final String? email;
  final bool isGuest;

  const MessageUserHit({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isGuest,
  });

  factory MessageUserHit.fromJson(Map<String, dynamic> json) {
    return MessageUserHit(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString(),
      isGuest: json['isGuest'] == true,
    );
  }

  String get label => email == null ? displayName : '$displayName ($email)';
}

/// A message as the admin sees it, including read / click numbers.
class AdminMessage {
  final String id;
  final String title;
  final String preview;
  final String body;
  final String audience; // 'all' | 'registered'
  final bool isActive;
  final DateTime createdAt;
  final int clickCount;
  final int readCount;
  final int recipients;
  final String? targetName; // set when audience == 'user'

  const AdminMessage({
    required this.id,
    required this.title,
    required this.preview,
    required this.body,
    required this.audience,
    required this.isActive,
    required this.createdAt,
    required this.clickCount,
    required this.readCount,
    required this.recipients,
    this.targetName,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      preview: json['preview']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      audience: json['audience']?.toString() ?? 'all',
      isActive: json['isActive'] != false,
      createdAt: _parseDate(json['createdAt']),
      clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
      readCount: (json['readCount'] as num?)?.toInt() ?? 0,
      recipients: (json['recipients'] as num?)?.toInt() ?? 0,
      targetName: json['targetName']?.toString(),
    );
  }

  String get audienceLabel {
    if (audience == 'user') return 'To: ${targetName ?? 'one user'}';
    return audience == 'registered' ? 'Registered users only' : 'All users';
  }
}

/// One user's interaction with a message (admin detail screen).
class MessageReceiptInfo {
  final String userId;
  final String displayName;
  final String? email;
  final bool isGuest;
  final DateTime? clickedAt;
  final DateTime? readAt;

  const MessageReceiptInfo({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.clickedAt,
    required this.readAt,
  });

  factory MessageReceiptInfo.fromJson(Map<String, dynamic> json) {
    return MessageReceiptInfo(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      email: json['email']?.toString(),
      isGuest: json['isGuest'] == true,
      clickedAt: _parseDateOrNull(json['clickedAt']),
      readAt: _parseDateOrNull(json['readAt']),
    );
  }
}

class AdminMessageDetail {
  final AdminMessage message;
  final List<MessageReceiptInfo> receipts;

  const AdminMessageDetail({required this.message, required this.receipts});
}

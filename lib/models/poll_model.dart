class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List)
          .map((option) => PollOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDateTime(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? _parseDateTime(json['expiresAt'])
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    // Handle Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((option) => option.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}

class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({required this.id, required this.text, this.votes = 0});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      text: json['text'] as String,
      votes: json['votes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'votes': votes};
  }
}

class UserVote {
  final String userId;
  final String pollId;
  final String optionId;
  final DateTime votedAt;

  UserVote({
    required this.userId,
    required this.pollId,
    required this.optionId,
    required this.votedAt,
  });

  factory UserVote.fromJson(Map<String, dynamic> json) {
    return UserVote(
      userId: json['userId'] as String,
      pollId: json['pollId'] as String,
      optionId: json['optionId'] as String,
      votedAt: json['votedAt'] is DateTime
          ? json['votedAt']
          : DateTime.tryParse(json['votedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'pollId': pollId,
      'optionId': optionId,
      'votedAt': votedAt.toIso8601String(),
    };
  }
}

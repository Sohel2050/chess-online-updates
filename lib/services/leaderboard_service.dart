import 'package:logger/logger.dart';
import 'api_client.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String? photoUrl;
  final int level; // computed on the server from the player's XP
  final int points;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.level,
    required this.points,
    required this.isMe,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: j['userId']?.toString() ?? '',
        displayName: j['displayName']?.toString() ?? 'Player',
        photoUrl: j['photoUrl']?.toString(),
        level: (j['level'] as num?)?.toInt() ?? 1,
        points: (j['points'] as num?)?.toInt() ?? 0,
        isMe: j['isMe'] == true,
      );
}

class LeaderboardData {
  final List<LeaderboardEntry> entries;
  final int? myRank; // null = no points yet this week
  final int myPoints;
  final String weekKey;

  /// Time left until the weekly reset, measured with the SERVER's clock (the phone's clock may be wrong).
  final Duration untilReset;

  const LeaderboardData({
    required this.entries,
    required this.myRank,
    required this.myPoints,
    required this.weekKey,
    required this.untilReset,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> j) {
    final resetAt = DateTime.tryParse(j['resetAt']?.toString() ?? '');
    final serverTime = DateTime.tryParse(j['serverTime']?.toString() ?? '');
    final left = (resetAt != null && serverTime != null)
        ? resetAt.difference(serverTime)
        : Duration.zero;
    final me = j['me'] is Map ? Map<String, dynamic>.from(j['me'] as Map) : <String, dynamic>{};
    return LeaderboardData(
      entries: ((j['entries'] as List?) ?? const [])
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      myRank: (me['rank'] as num?)?.toInt(),
      myPoints: (me['points'] as num?)?.toInt() ?? 0,
      weekKey: j['weekKey']?.toString() ?? '',
      untilReset: left.isNegative ? Duration.zero : left,
    );
  }
}

class LeaderboardService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  /// Top 50 of everyone this week + my own rank. Null if the request failed (offline etc.).
  Future<LeaderboardData?> getWeekly() => _load('/leaderboard/weekly');

  /// Only my friends and me this week. Null if the request failed.
  Future<LeaderboardData?> getFriends() => _load('/leaderboard/friends');

  Future<LeaderboardData?> _load(String path) async {
    try {
      final result = await _api.get(path);
      return LeaderboardData.fromJson(result);
    } catch (e) {
      _logger.e('Error loading $path: $e');
      return null;
    }
  }
}

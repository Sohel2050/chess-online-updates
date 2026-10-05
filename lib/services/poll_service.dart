import 'package:flutter_chess_app/services/api_client.dart';
import 'package:logger/logger.dart';
import '../models/poll_model.dart';

/// Talks to the backend's `/polls` routes instead of Firestore.
class PollService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  // Get active poll
  Future<Poll?> getActivePoll() async {
    try {
      final result = await _api.get('/polls/active');
      final pollJson = result['poll'];
      if (pollJson == null) return null;
      final json = Map<String, dynamic>.from(pollJson);
      // Backend uses Mongo's `_id`; Poll.fromJson expects `id`.
      json['id'] = json['_id']?.toString() ?? '';
      return Poll.fromJson(json);
    } catch (e) {
      _logger.e('Error getting active poll: $e');
      return null;
    }
  }

  // Check if user has voted on a poll
  Future<UserVote?> getUserVote(String userId, String pollId) async {
    try {
      final result = await _api.get('/polls/$pollId/my-vote');
      final voteJson = result['vote'];
      if (voteJson == null) return null;
      final json = Map<String, dynamic>.from(voteJson);
      return UserVote(
        userId: json['userId'] ?? userId,
        pollId: json['pollId']?.toString() ?? pollId,
        optionId: json['optionId'] ?? '',
        votedAt: json['votedAt'] != null ? DateTime.parse(json['votedAt']) : DateTime.now(),
      );
    } catch (e) {
      _logger.e('Error getting user vote: $e');
      return null;
    }
  }

  // Cast a vote
  Future<bool> castVote(String userId, String pollId, String optionId) async {
    try {
      await _api.post('/polls/$pollId/vote', body: {'optionId': optionId});
      return true;
    } catch (e) {
      _logger.e('Error casting vote: $e');
      return false;
    }
  }

  // Get poll results with vote counts
  Future<Map<String, int>> getPollResults(String pollId) async {
    try {
      final result = await _api.get('/polls/$pollId/results');
      return Map<String, int>.from(result['results'] ?? {});
    } catch (e) {
      _logger.e('Error getting poll results: $e');
      return {};
    }
  }

  /// Polling-based "live" poll results (every 5s) — same Stream-shaped API
  /// the Firestore version exposed. True push updates would need a
  /// dedicated Socket.IO event (e.g. `poll:updated`) — not added yet since
  /// poll results aren't latency-sensitive.
  Stream<Map<String, int>> streamPollResults(String pollId) async* {
    while (true) {
      yield await getPollResults(pollId);
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}

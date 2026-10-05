import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';

/// Talks to the self-hosted backend's `/ranking` routes instead of running
/// a Firestore `orderBy(rating).startAfterDocument()` query directly from
/// the screen. Uses simple page-number pagination (backend handles the
/// `skip`/`limit` math) instead of Firestore's cursor documents.
class RankingService {
  final ApiClient _api = ApiClient.instance;

  /// Returns one page of the leaderboard for [ratingType]
  /// (e.g. Constants.classicalRating), 1-indexed [page].
  Future<List<ChessUser>> getLeaderboardPage({
    required String ratingType,
    required int page,
    int pageSize = 50,
  }) async {
    final result = await _api.get('/ranking', query: {
      'type': ratingType,
      'page': page,
      'limit': pageSize,
    });
    final entries = result['leaderboard'] as List;
    return entries.map((e) {
      final json = Map<String, dynamic>.from(e);
      final rating = json['rating'] ?? 1200;
      return ChessUser(
        uid: json['userId']?.toString(),
        displayName: json['displayName'] ?? 'Player',
        photoUrl: json['photoUrl'],
        classicalRating: ratingType == 'classicalRating' ? rating : 1200,
        blitzRating: ratingType == 'blitzRating' ? rating : 1200,
        tempoRating: ratingType == 'tempoRating' ? rating : 1200,
        gamesPlayed: json['gamesPlayed'] ?? 0,
        gamesWon: json['gamesWon'] ?? 0,
      );
    }).toList();
  }

  Future<int?> getTotalPlayerCount() async {
    try {
      final result = await _api.get('/ranking/count');
      return result['count'];
    } catch (_) {
      return null;
    }
  }
}

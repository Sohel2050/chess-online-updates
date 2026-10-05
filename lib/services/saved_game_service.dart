import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:logger/logger.dart';

/// Talks to the backend's `/saved-games` routes instead of Firestore's
/// `gameHistory` collection. Still returns/accepts `SavedGame` objects
/// unchanged (including `Timestamp` for `createdAt`, which works fine as a
/// plain value type without an active Firestore connection).
class SavedGameService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  SavedGame _fromJson(Map<String, dynamic> json) {
    return SavedGame(
      gameId: json['_id']?.toString() ?? '',
      userId: json['userId'] ?? '',
      opponentId: json['opponentId'] ?? '',
      opponentDisplayName: json['opponentDisplayName'] ?? '',
      initialFen: json['initialFen'] ?? '',
      moves: List<String>.from(json['moves'] ?? []),
      result: json['result'] ?? 'unknown',
      winnerColor: json['winnerColor'] ?? 'none',
      gameMode: json['gameMode'] ?? 'classical',
      initialWhitesTime: json['initialWhitesTime'] ?? 0,
      initialBlacksTime: json['initialBlacksTime'] ?? 0,
      finalWhitesTime: json['finalWhitesTime'] ?? 0,
      finalBlacksTime: json['finalBlacksTime'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  /// Saves a game to the backend.
  Future<void> saveGame(SavedGame game) async {
    try {
      await _api.post('/saved-games', body: {
        'opponentId': game.opponentId,
        'opponentDisplayName': game.opponentDisplayName,
        'initialFen': game.initialFen,
        'moves': game.moves,
        'result': game.result,
        'winnerColor': game.winnerColor,
        'gameMode': game.gameMode,
        'initialWhitesTime': game.initialWhitesTime,
        'initialBlacksTime': game.initialBlacksTime,
        'finalWhitesTime': game.finalWhitesTime,
        'finalBlacksTime': game.finalBlacksTime,
      });
      _logger.i('Game saved successfully: ${game.gameId}');
    } catch (e) {
      _logger.e('Error saving game: $e');
      throw Exception('Failed to save game.');
    }
  }

  /// Retrieves a list of saved games for a specific user.
  /// `userId` is kept for call-site compatibility — the backend always
  /// returns the logged-in user's own games (identified via JWT).
  Future<List<SavedGame>> getSavedGamesForUser(String userId) async {
    try {
      final result = await _api.get('/saved-games');
      return (result['games'] as List)
          .map((j) => _fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      _logger.e('Error getting saved games for user $userId: $e');
      throw Exception('Failed to retrieve saved games.');
    }
  }

  /// Retrieves a single saved game by its ID.
  Future<SavedGame?> getSavedGameById(String gameId) async {
    try {
      final result = await _api.get('/saved-games/$gameId');
      return _fromJson(Map<String, dynamic>.from(result['game']));
    } catch (e) {
      _logger.e('Error getting saved game by ID $gameId: $e');
      return null;
    }
  }
}

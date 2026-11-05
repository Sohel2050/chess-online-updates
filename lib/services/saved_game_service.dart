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
      playerColor: json['playerColor']?.toString() ?? '',
    );
  }

  /// Saves a game to the backend.
  Future<void> saveGame(SavedGame game) async {
    try {
      await _api.post('/saved-games', body: {
        // Same id every time: a retry (or the server's own copy) never duplicates the game.
        'gameId': game.gameId,
        'playerColor': game.playerColor,
        'opponentId': game.opponentId,
        'opponentDisplayName': game.opponentDisplayName,
        'initialFen': game.initialFen,
        'moves': game.moves,
        'result': game.result,
        'winnerColor': game.winnerColor.toLowerCase(), // server expects white / black / none
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

  /// The saved copy of a just-finished online game, looked up by the game's
  /// room id. The server saves it when the game ends, so a retry or two may
  /// be needed right after the final move.
  Future<SavedGame?> getSavedGameByRoomId(String roomId) async {
    // The app's own upload retries after 0s / 2s / 6s, so keep looking for ~12s.
    const attempts = 7;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final result = await _api.get('/saved-games/by-game/$roomId');
        return _fromJson(Map<String, dynamic>.from(result['game']));
      } catch (_) {
        if (attempt < attempts - 1) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  /// Uploads the engine review of a game. [id] may be the saved game's database id
  /// or the online room id. [encodedReview] is `GameReviewResult.encode()`.
  /// Returns false on any failure (the review still works from the device cache).
  Future<bool> saveReview(String id, String encodedReview) async {
    if (id.isEmpty) return false;
    try {
      await _api.put('/saved-games/${Uri.encodeComponent(id)}/review', body: {'review': encodedReview});
      return true;
    } catch (e) {
      _logger.w('Could not upload the review of $id: $e');
      return false;
    }
  }

  /// The review saved on the server for this game, as the encoded text
  /// (`GameReviewResult.decode`), or null if there is none / the call failed.
  Future<String?> getReview(String id) async {
    if (id.isEmpty) return null;
    try {
      final result = await _api.get('/saved-games/${Uri.encodeComponent(id)}/review');
      final r = result['review'];
      return r is String && r.isNotEmpty ? r : null;
    } catch (_) {
      return null; // 404 = no review yet
    }
  }

  // ---- PGN import and share links ----

  /// A saved game from the server's JSON (used by the import screens).
  SavedGame gameFromJson(Map<String, dynamic> json) => _fromJson(json);

  /// Server-checked import of PGN text (one or many games). Throws [ApiException] with a readable message
  /// (for example: Move 2 "Ke3" is not legal here.) when the text is not a valid game.
  Future<List<SavedGame>> importPgn(String pgn) async {
    final result = await _api.post('/saved-games/import-pgn', body: {'pgn': pgn});
    return (result['games'] as List).map((j) => _fromJson(Map<String, dynamic>.from(j))).toList();
  }

  /// Copies the game behind a share link (its 8-character code) into my saved games.
  Future<SavedGame> importSharedCode(String code) async {
    final result = await _api.post('/shared/${Uri.encodeComponent(code)}/import');
    return _fromJson(Map<String, dynamic>.from(result['game']));
  }

  /// Makes (or returns the existing) public link for one of my saved games. Null when it failed.
  Future<String?> createShareLink(String savedGameId) async {
    try {
      final result = await _api.post('/shared', body: {'savedGameId': savedGameId});
      final url = result['url'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (e) {
      _logger.w('Could not create a share link: $e');
      return null;
    }
  }
}

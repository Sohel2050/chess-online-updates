import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:logger/logger.dart';

/// Talks to the backend's `/games` invite routes — replaces the Firestore
/// `notifications/{userId}/invites` subcollection that
/// `GameService.streamGameInvites` used to read.
class GameInviteService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  /// Sends a private-game invite to a friend. Returns the created room's
  /// `roomCode` (also embedded in the returned GameRoom), which the friend
  /// uses to join once they accept.
  Future<GameRoom?> sendInvite({required String friendId, required String gameMode}) async {
    try {
      final result = await _api.post('/games/invite', body: {
        'friendId': friendId,
        'gameMode': gameMode,
      });
      return GameRoom.fromSocketJson(Map<String, dynamic>.from(result['room']));
    } catch (e) {
      _logger.e('Error sending game invite: $e');
      return null;
    }
  }

  /// Live-updates instantly via the socket's `game:inviteReceived` push,
  /// with a 5-second poll as a safety net.
  Stream<List<GameRoom>> streamGameInvites(String userId) async* {
    while (true) {
      try {
        final result = await _api.get('/games/invites');
        final invites = (result['invites'] as List)
            .map((j) => GameRoom.fromSocketJson(Map<String, dynamic>.from(j)))
            .toList();
        yield invites;
      } catch (e) {
        _logger.e('Error fetching game invites: $e');
        yield [];
      }
      await Future.any([
        Future.delayed(const Duration(seconds: 5)),
        GameSocketService.instance.onGameInviteReceived.first,
      ]);
    }
  }

  Future<void> declineInvite(String gameId) async {
    try {
      await _api.delete('/games/invites/$gameId');
    } catch (e) {
      _logger.e('Error declining game invite: $e');
      rethrow;
    }
  }
}

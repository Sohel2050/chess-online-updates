import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:logger/logger.dart';

/// Talks to the self-hosted backend's `/friends` routes instead of
/// Firestore. `currentUserId` parameters are kept for call-site
/// compatibility but are unused — the backend identifies the caller from
/// their JWT, not from a parameter, so it can't be spoofed.
class FriendService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  ChessUser _userFromJson(Map<String, dynamic> json) {
    return ChessUser(
      uid: json['_id']?.toString(),
      displayName: json['displayName'] ?? 'Player',
      photoUrl: json['photoUrl'],
      classicalRating: json['classicalRating'] ?? 1200,
      isOnline: json['isOnline'] ?? false,
    );
  }

  Future<void> sendFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      await _api.post('/friends/request/$friendUserId');
    } catch (e) {
      _logger.e('Error sending friend request: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      await _api.post('/friends/accept/$friendUserId');
    } catch (e) {
      _logger.e('Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> declineFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      await _api.post('/friends/decline/$friendUserId');
    } catch (e) {
      _logger.e('Error declining friend request: $e');
      rethrow;
    }
  }

  Future<void> removeFriend({
    required String currentUserId,
    required String friendUserId,
  }) async {
    try {
      await _api.delete('/friends/$friendUserId');
    } catch (e) {
      _logger.e('Error removing friend: $e');
      rethrow;
    }
  }

  Future<void> blockUser({
    required String currentUserId,
    required String userIdToBlock,
  }) async {
    try {
      await _api.post('/friends/block/$userIdToBlock');
    } catch (e) {
      _logger.e('Error blocking user: $e');
      rethrow;
    }
  }

  Future<void> unblockUser({
    required String currentUserId,
    required String userIdToUnblock,
  }) async {
    try {
      await _api.post('/friends/unblock/$userIdToUnblock');
    } catch (e) {
      _logger.e('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Live-updates instantly via the socket's friend-request push events,
  /// with a 5-second poll as a safety net.
  Stream<List<ChessUser>> getFriends(String userId) async* {
    while (true) {
      try {
        final result = await _api.get('/friends');
        final list = (result['friends'] as List)
            .map((j) => _userFromJson(Map<String, dynamic>.from(j)))
            .toList();
        yield list;
      } catch (e) {
        _logger.e('Error fetching friends: $e');
        yield [];
      }
      await Future.any([
        Future.delayed(const Duration(seconds: 5)),
        GameSocketService.instance.onFriendEvent.first,
      ]);
    }
  }

  Stream<List<ChessUser>> getFriendRequests(String userId) async* {
    while (true) {
      try {
        final result = await _api.get('/friends/requests');
        final list = (result['received'] as List)
            .map((j) => _userFromJson(Map<String, dynamic>.from(j)))
            .toList();
        yield list;
      } catch (e) {
        _logger.e('Error fetching friend requests: $e');
        yield [];
      }
      await Future.any([
        Future.delayed(const Duration(seconds: 5)),
        GameSocketService.instance.onFriendEvent.first,
      ]);
    }
  }

  Future<List<ChessUser>> searchUsers(String query, String currentUserId) async {
    try {
      final result = await _api.get('/friends/search', query: {'q': query});
      return (result['users'] as List)
          .map((j) => _userFromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      _logger.e('Error searching users: $e');
      return [];
    }
  }

  Future<bool> isFriend(String userId1, String userId2) async {
    try {
      final result = await _api.get('/friends/is-friend/$userId2');
      return result['isFriend'] == true;
    } catch (e) {
      _logger.e('Error checking friend status: $e');
      return false;
    }
  }

  /// Not exposed as a separate backend list endpoint yet (blocked users
  /// aren't returned anywhere except implicitly via the request/friend
  /// filtering on the server). Returns an empty stream for now — add a
  /// `GET /friends/blocked` backend route if this screen needs real data.
  Stream<List<ChessUser>> getBlockedUsers(String userId) async* {
    yield [];
  }
}

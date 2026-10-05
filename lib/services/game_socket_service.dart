import 'dart:async';
import 'package:async/async.dart' show StreamGroup;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:logger/logger.dart';

/// Thin wrapper around the backend's Socket.IO game namespace (see
/// backend/sockets/gameHandlers.js). Replaces the Firestore
/// `.snapshots()` listeners `game_provider.dart`/`game_service.dart` used
/// for real-time matchmaking, move sync, resign/draw/rematch, and private
/// rooms.
///
/// This class only handles the *connection and event plumbing* — wiring
/// its streams into `GameProvider`'s existing state (timers, board state,
/// UI updates) is a separate, larger integration step. Each public stream
/// here corresponds 1:1 to a server-emitted event so that integration can
/// be done incrementally, method by method.
class GameSocketService {
  GameSocketService._internal();
  static final GameSocketService instance = GameSocketService._internal();
  factory GameSocketService() => instance;

  io.Socket? _socket;
  final Logger _logger = Logger();

  final _gameStartController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _opponentMoveController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _opponentDisconnectedRawController = StreamController<Map<String, dynamic>>.broadcast();
  final _opponentReconnectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _matchmakingWaitingController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteController = StreamController<Map<String, dynamic>>.broadcast();

  /// Emitted when a match is found (matchmaking) or a private room fills
  /// up — payload: `{ room: <GameRoom JSON> }`.
  Stream<Map<String, dynamic>> get onGameStart => _gameStartController.stream;

  /// Emitted on non-move state changes (draw offered/responded, rematch
  /// offered) — payload: `{ room: <GameRoom JSON> }`.
  Stream<Map<String, dynamic>> get onGameUpdate => _gameUpdateController.stream;

  /// Emitted when the opponent makes a move — payload:
  /// `{ move, fen, room }`.
  Stream<Map<String, dynamic>> get onOpponentMove => _opponentMoveController.stream;

  /// Emitted when the game ends (checkmate reported, resignation, draw,
  /// timeout) — payload: `{ room, reason }`.
  Stream<Map<String, dynamic>> get onGameEnded => _gameEndedController.stream;

  /// Emitted when the opponent's socket disconnects — payload:
  /// `{ userId, graceMs }`. They have `graceMs` milliseconds to reconnect
  /// (via `rejoinGame`) before the game is auto-forfeited to you — the
  /// game does NOT end immediately, so keep the UI in a "waiting to
  /// reconnect" state rather than ending the game on this event alone.
  Stream<Map<String, dynamic>> get onOpponentDisconnected => _opponentDisconnectedRawController.stream;

  /// Emitted if the opponent reconnects within the grace period —
  /// payload: `{ userId }`.
  Stream<Map<String, dynamic>> get onOpponentReconnected => _opponentReconnectedController.stream;

  Stream<void> get onMatchmakingWaiting => _matchmakingWaitingController.stream;
  Stream<String> get onError => _errorController.stream;

  /// Pushed the instant someone sends you a chat message (payload: `{ message }`).
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;

  /// Pushed on friend-request events — `{ fromUserId }` for a new request,
  /// `{ byUserId }` for one of your requests being accepted.
  Stream<Map<String, dynamic>> get onFriendEvent => _friendEventController.stream;

  /// Pushed the instant a friend sends you a private-game invite
  /// (payload: `{ room }`).
  Stream<Map<String, dynamic>> get onGameInviteReceived => _gameInviteController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects to the backend's Socket.IO server using the same JWT issued
  /// by /auth/login|signup|guest. Call once (e.g. when entering the online
  /// game flow); safe to call again if already connected (no-op).
  Future<void> connect() async {
    if (isConnected) return;
    final token = await ApiClient.instance.token;
    if (token == null) {
      throw Exception('Not logged in — cannot open a game socket without a token');
    }

    final socket = io.io(
      ApiClient.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => _logger.i('Game socket connected'));
    socket.onConnectError((e) => _logger.e('Game socket connect error: $e'));
    socket.onDisconnect((_) => _logger.w('Game socket disconnected'));

    socket.on('game:start', (data) => _gameStartController.add(Map<String, dynamic>.from(data)));
    socket.on('game:update', (data) => _gameUpdateController.add(Map<String, dynamic>.from(data)));
    socket.on('game:opponentMove', (data) => _opponentMoveController.add(Map<String, dynamic>.from(data)));
    socket.on('game:ended', (data) => _gameEndedController.add(Map<String, dynamic>.from(data)));
    socket.on('game:opponentDisconnected', (data) {
      _opponentDisconnectedRawController.add(Map<String, dynamic>.from(data));
    });
    socket.on('game:opponentReconnected', (data) {
      _opponentReconnectedController.add(Map<String, dynamic>.from(data));
    });
    socket.on('matchmaking:waiting', (_) => _matchmakingWaitingController.add(null));
    socket.on('privateGame:created', (data) => _gameStartController.add(Map<String, dynamic>.from(data)));
    socket.on('chat:message', (data) => _chatMessageController.add(Map<String, dynamic>.from(data)));
    socket.on('friend:requestReceived', (data) => _friendEventController.add(Map<String, dynamic>.from(data)));
    socket.on('friend:requestAccepted', (data) => _friendEventController.add(Map<String, dynamic>.from(data)));
    socket.on('game:inviteReceived', (data) => _gameInviteController.add(Map<String, dynamic>.from(data)));
    socket.on('error', (data) {
      final message = data is Map ? (data['message']?.toString() ?? 'Unknown error') : data.toString();
      _errorController.add(message);
    });

    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ---- Matchmaking ----

  void joinMatchmaking({required String gameMode, required bool ratingBasedSearch}) {
    _socket?.emit('matchmaking:join', {
      'gameMode': gameMode,
      'ratingBasedSearch': ratingBasedSearch,
    });
  }

  void cancelMatchmaking() => _socket?.emit('matchmaking:cancel');

  // ---- Private rooms ----

  void createPrivateGame(String gameMode) {
    _socket?.emit('privateGame:create', {'gameMode': gameMode});
  }

  void joinPrivateGame(String roomCode) {
    _socket?.emit('privateGame:join', {'roomCode': roomCode});
  }

  // ---- In-game ----

  /// Rejoin the server-side room for an already-active game (e.g. after
  /// reconnecting) so this socket starts receiving its events again.
  void rejoinGame(String gameId) => _socket?.emit('game:join', {'gameId': gameId});

  void sendMove({
    required String gameId,
    required String move,
    required String fen,
    int? whitesTimeRemaining,
    int? blacksTimeRemaining,
  }) {
    _socket?.emit('game:move', {
      'gameId': gameId,
      'move': move,
      'fen': fen,
      if (whitesTimeRemaining != null) 'whitesTimeRemaining': whitesTimeRemaining,
      if (blacksTimeRemaining != null) 'blacksTimeRemaining': blacksTimeRemaining,
    });
  }

  void reportGameEnd({required String gameId, String? winnerId, required String reason}) {
    _socket?.emit('game:end', {'gameId': gameId, 'winnerId': winnerId, 'reason': reason});
  }

  void updateScores({required String gameId, required int player1Score, required int player2Score}) {
    _socket?.emit('game:updateScores', {
      'gameId': gameId,
      'player1Score': player1Score,
      'player2Score': player2Score,
    });
  }

  void resign(String gameId) => _socket?.emit('game:resign', {'gameId': gameId});

  void offerDraw(String gameId) => _socket?.emit('game:offerDraw', {'gameId': gameId});

  void respondToDraw({required String gameId, required bool accepted}) {
    _socket?.emit('game:drawResponse', {'gameId': gameId, 'accepted': accepted});
  }

  void offerRematch(String gameId) => _socket?.emit('game:rematchOffer', {'gameId': gameId});

  void respondToRematch({required String gameId, required bool accepted}) {
    _socket?.emit('game:rematchResponse', {'gameId': gameId, 'accepted': accepted});
  }

  // ---- Audio room (in-game voice chat invite/join/leave state) ----

  void inviteToAudioRoom(String gameId) => _socket?.emit('audioRoom:invite', {'gameId': gameId});

  void respondToAudioRoomInvite({required String gameId, required bool accepted}) {
    _socket?.emit('audioRoom:respond', {'gameId': gameId, 'accepted': accepted});
  }

  void joinAudioRoom(String gameId) => _socket?.emit('audioRoom:join', {'gameId': gameId});

  void leaveAudioRoom(String gameId) => _socket?.emit('audioRoom:leave', {'gameId': gameId});

  void endAudioRoom(String gameId) => _socket?.emit('audioRoom:end', {'gameId': gameId});

  // ---- Spectating ----

  /// Joins a game as a read-only spectator and returns a live stream of
  /// the room's state (parsed via `GameRoom.fromSocketJson`). Replaces the
  /// old `GameService.streamGameRoom(gameId)` Firestore listener used by
  /// `spectator_screen.dart`.
  Stream<Map<String, dynamic>> spectateGame(String gameId) {
    _socket?.emit('spectate:join', {'gameId': gameId});
    // `game:update`, `game:opponentMove`, and `game:ended` all carry a
    // `room` field — merge them into one stream of room snapshots.
    return StreamGroup.merge([onGameUpdate, onOpponentMove, onGameEnded, onGameStart]);
  }

  void dispose() {
    disconnect();
    _gameStartController.close();
    _gameUpdateController.close();
    _opponentMoveController.close();
    _gameEndedController.close();
    _opponentDisconnectedRawController.close();
    _opponentReconnectedController.close();
    _matchmakingWaitingController.close();
    _errorController.close();
    _chatMessageController.close();
    _friendEventController.close();
    _gameInviteController.close();
  }
}

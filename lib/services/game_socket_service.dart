import 'dart:async';
import 'package:async/async.dart' show StreamGroup;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/crash_reporter.dart';
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
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _matchmakingWaitingController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _dailyUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _clubEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveStatsController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, int> _statsSubs = {}; // watched mode ('' = all modes) -> how many widgets watch it
  final _chatTypingController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteDeclinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameInviteCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  // Live needs the opponent's agreement: request / accepted / declined / cancelled (payload has gameId).
  final _liveRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _liveAnswerController = StreamController<Map<String, dynamic>>.broadcast(); // adds `accepted: bool`
  final _liveCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _spectatorCountController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, int> _lastSpectatorCount = {};

  /// Latest known number of viewers of [gameId] (0 if unknown).
  int lastSpectatorCount(String gameId) => _lastSpectatorCount[gameId] ?? 0;
  final _spectateEndedController = StreamController<Map<String, dynamic>>.broadcast();

  /// An emoji reaction was sent in a game you are in or watching — payload:
  /// `{ gameId, fromUserId, fromName, targetId, emoji, isSpectator, counts }`.
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;

  /// How many people are watching — payload: `{ gameId, count }`.
  Stream<Map<String, dynamic>> get onSpectatorCount => _spectatorCountController.stream;

  /// The players switched Live OFF (or you may not watch) — payload: `{ gameId, reason }`.
  Stream<Map<String, dynamic>> get onSpectateEnded => _spectateEndedController.stream;

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

  /// Server's answer to "is my opponent really connected right now?" — payload:
  /// `{ gameId, userId, online }`. Sent when we (re)join a game.
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;

  /// Emits `true`/`false` whenever OUR OWN socket connects/disconnects.
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  Stream<void> get onMatchmakingWaiting => _matchmakingWaitingController.stream;
  Stream<String> get onError => _errorController.stream;

  /// Pushed the instant someone sends you a chat message (payload: `{ message }`).
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;

  /// The Play screen's live counters, pushed by the server whenever they change —
  /// payload: `{ gameMode ('' = all), online, waiting, games, playing }`.
  Stream<Map<String, dynamic>> get onLiveStats => _liveStatsController.stream;

  /// Start receiving [onLiveStats] for one game mode (null = all modes). Counted: call
  /// [unsubscribeLiveStats] once for every call to this. Re-sent automatically after a reconnect.
  void subscribeLiveStats(String? gameMode) {
    final key = gameMode ?? '';
    final n = _statsSubs[key] ?? 0;
    _statsSubs[key] = n + 1;
    if (n == 0) _socket?.emit('stats:subscribe', {if (key.isNotEmpty) 'gameMode': key});
  }

  void unsubscribeLiveStats(String? gameMode) {
    final key = gameMode ?? '';
    final n = _statsSubs[key] ?? 0;
    if (n <= 0) return;
    if (n == 1) {
      _statsSubs.remove(key);
      _socket?.emit('stats:unsubscribe', {if (key.isNotEmpty) 'gameMode': key});
    } else {
      _statsSubs[key] = n - 1;
    }
  }

  /// Live club chat events: `{ event: 'message', clubId, message }` and `{ event: 'deleted', clubId, id }`.
  Stream<Map<String, dynamic>> get onClubEvent => _clubEventController.stream;

  /// `{ fromUserId, isTyping }` while a friend is typing to you.
  Stream<Map<String, dynamic>> get onChatTyping => _chatTypingController.stream;

  /// Tells [toUserId] that you started/stopped typing. Not stored anywhere.
  void sendTyping(String toUserId, bool isTyping) {
    _socket?.emit('chat:typing', {'toUserId': toUserId, 'isTyping': isTyping});
  }

  /// Pushed on friend-request events — `{ fromUserId }` for a new request,
  /// `{ byUserId }` for one of your requests being accepted.
  Stream<Map<String, dynamic>> get onFriendEvent => _friendEventController.stream;

  /// A daily (correspondence) game changed on the server: new move, draw offer, resign, result...
  /// Payload: {gameId: "..."}.
  Stream<Map<String, dynamic>> get onDailyUpdate => _dailyUpdateController.stream;

  /// Pushed the instant a friend sends you a private-game invite
  /// (payload: `{ room }`).
  Stream<Map<String, dynamic>> get onGameInviteReceived => _gameInviteController.stream;

  /// Pushed to the invited friend when the sender cancelled (or replaced) the invite.
  Stream<Map<String, dynamic>> get onGameInviteCancelled => _gameInviteCancelledController.stream;

  /// Pushed to the host when the invited friend declines the invite.
  Stream<Map<String, dynamic>> get onGameInviteDeclined => _gameInviteDeclinedController.stream;

  /// The opponent wants this game Live: `{ gameId, fromUserId, fromName, kind }`. Answer with [respondToLive].
  Stream<Map<String, dynamic>> get onLiveRequest => _liveRequestController.stream;

  /// The opponent answered my Live request: `{ gameId, byName, accepted }`.
  Stream<Map<String, dynamic>> get onLiveAnswer => _liveAnswerController.stream;

  /// The opponent withdrew their Live request.
  Stream<Map<String, dynamic>> get onLiveRequestCancelled => _liveCancelledController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects to the backend's Socket.IO server using the same JWT issued
  /// by /auth/login|signup|guest. Call once (e.g. when entering the online
  /// game flow); safe to call again if already connected (no-op).
  Future<void> connect() async {
    if (isConnected) return;
    // A socket already exists but is only reconnecting: reuse it. Creating another one made every
    // event arrive twice (two sockets feeding the same streams).
    if (_socket != null) {
      _socket!.connect();
      return;
    }
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

    socket.onConnect((_) {
      _logger.i('Game socket connected');
      _connectionController.add(true);
      // A new connection has no live-counter subscriptions yet: ask again for the ones the screens watch.
      for (final key in _statsSubs.keys) {
        socket.emit('stats:subscribe', {if (key.isNotEmpty) 'gameMode': key});
      }
      // After a network drop Socket.IO reconnects with a NEW connection that
      // is not in the game's room any more: rejoin it, or no further moves
      // or results would ever arrive.
      final gameId = _activeGameId;
      if (gameId != null) {
        rejoinGame(gameId);
        // A fresh socket defaults to "foreground" on the server: tell it if we are actually in the background.
        if (!_appInForeground) setForeground(false);
      }
    });
    socket.onConnectError((e) {
      _logger.e('Game socket connect error: $e');
      CrashReporter.log('game socket connect error'); // breadcrumb only: shows on the next crash
    });
    socket.onDisconnect((_) {
      _logger.w('Game socket disconnected');
      _connectionController.add(false);
    });

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
    socket.on('game:presence', (data) {
      _presenceController.add(Map<String, dynamic>.from(data));
    });
    socket.on('matchmaking:waiting', (_) => _matchmakingWaitingController.add(null));
    socket.on('privateGame:created', (data) => _gameStartController.add(Map<String, dynamic>.from(data)));
    socket.on('chat:message', (data) => _chatMessageController.add(Map<String, dynamic>.from(data)));
    socket.on('stats:live', (data) {
      if (data is Map) _liveStatsController.add(Map<String, dynamic>.from(data));
    });
    socket.on('club:message', (data) => _clubEventController.add({...Map<String, dynamic>.from(data), 'event': 'message'}));
    socket.on('club:message_deleted', (data) => _clubEventController.add({...Map<String, dynamic>.from(data), 'event': 'deleted'}));
    socket.on('chat:typing', (data) => _chatTypingController.add(Map<String, dynamic>.from(data)));
    socket.on('daily:update', (data) {
      _dailyUpdateController.add(data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    });
    socket.on('friend:requestReceived', (data) => _friendEventController.add(Map<String, dynamic>.from(data)));
    socket.on('friend:requestAccepted', (data) => _friendEventController.add(Map<String, dynamic>.from(data)));
    socket.on('reaction:new', (data) => _reactionController.add(Map<String, dynamic>.from(data)));
    socket.on('game:spectators', (data) {
      final map = Map<String, dynamic>.from(data);
      // Remember the latest count per game, so a screen that opens AFTER the
      // update still shows the right number (the stream itself has no replay).
      final id = map['gameId']?.toString();
      final count = (map['count'] as num?)?.toInt();
      if (id != null && count != null) _lastSpectatorCount[id] = count;
      _spectatorCountController.add(map);
    });
    socket.on('spectate:ended', (data) => _spectateEndedController.add(Map<String, dynamic>.from(data)));
    socket.on('game:inviteReceived', (data) => _gameInviteController.add(Map<String, dynamic>.from(data)));
    socket.on('game:inviteCancelled', (data) => _gameInviteCancelledController.add(data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{}));
    socket.on('game:inviteDeclined', (data) => _gameInviteDeclinedController.add(data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{}));
    socket.on('live:request', (data) => _liveRequestController.add(Map<String, dynamic>.from(data)));
    socket.on('live:accepted', (data) => _liveAnswerController.add({...Map<String, dynamic>.from(data), 'accepted': true}));
    socket.on('live:declined', (data) => _liveAnswerController.add({...Map<String, dynamic>.from(data), 'accepted': false}));
    socket.on('live:requestCancelled', (data) => _liveCancelledController.add(data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{}));
    socket.on('error', (data) {
      final message = data is Map ? (data['message']?.toString() ?? 'Unknown error') : data.toString();
      _errorController.add(message);
    });

    socket.connect();
  }

  void disconnect() {
    _activeGameId = null;
    _statsSubs.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ---- Matchmaking ----

  void joinMatchmaking({
    required String gameMode,
    required bool ratingBasedSearch,
    List<String>? gameModes,
  }) {
    _socket?.emit('matchmaking:join', {
      'gameMode': gameMode,
      // Every mode the player accepts; the server plays whichever one both players share.
      'gameModes': gameModes ?? [gameMode],
      'ratingBasedSearch': ratingBasedSearch,
    });
  }

  void cancelMatchmaking() => _socket?.emit('matchmaking:cancel');

  /// Tells the server this player is still waiting (sent every few seconds while the waiting dialog is open).
  void matchmakingKeepAlive() => _socket?.emit('matchmaking:keepalive');

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
  void rejoinGame(String gameId) {
    _activeGameId = gameId;
    _socket?.emit('game:join', {'gameId': gameId});
  }

  /// The online game this device is playing (rejoined automatically after a reconnect).
  String? _activeGameId;

  bool _appInForeground = true;

  /// Tells the server the app went to the background / came back, so the opponent sees us
  /// as Offline / Online. The connection itself stays open (no forfeit).
  void setForeground(bool foreground) {
    _appInForeground = foreground;
    final gameId = _activeGameId;
    if (gameId != null) _socket?.emit('game:foreground', {'gameId': gameId, 'foreground': foreground});
  }

  /// Asks the server to re-check whether the opponent is connected (answer arrives on [onPresence]).
  void requestPresence(String gameId) => _socket?.emit('game:presence', {'gameId': gameId});
  void setActiveGame(String? gameId) => _activeGameId = gameId;

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

  void offerTakeback(String gameId) => _socket?.emit('game:offerTakeback', {'gameId': gameId});

  void respondToTakeback({required String gameId, required bool accepted}) {
    _socket?.emit('game:takebackResponse', {'gameId': gameId, 'accepted': accepted});
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

  /// A player turns emoji reactions OFF/ON for themselves in this game.
  void setReactionsEnabled(String gameId, bool enabled) =>
      _socket?.emit('game:setReactions', {'gameId': gameId, 'enabled': enabled});

  void leaveSpectate(String gameId) {
    _lastSpectatorCount.remove(gameId);
    _socket?.emit('spectate:leave', {'gameId': gameId});
  }

  // ---- Live watching + emoji reactions ----

  /// A player turns public Live watching on/off for their running game.
  void setPublicWatch(String gameId, bool enabled) =>
      _socket?.emit('game:setPublicWatch', {'gameId': gameId, 'enabled': enabled});

  /// The opponent's Live request: accept (Live turns on) or decline (Live stays off).
  void respondToLive({required String gameId, required bool accepted}) =>
      _socket?.emit('live:respond', {'gameId': gameId, 'accepted': accepted});

  /// Sends an emoji reaction ([emoji] is a key from `kReactions`). Players always react to the
  /// opponent; a spectator must pass [targetId] (one of the two players).
  void sendReaction({required String gameId, required String emoji, String? targetId}) =>
      _socket?.emit('reaction:send', {'gameId': gameId, 'emoji': emoji, if (targetId != null) 'targetId': targetId});

  void dispose() {
    disconnect();
    _reactionController.close();
    _spectatorCountController.close();
    _spectateEndedController.close();
    _gameStartController.close();
    _gameUpdateController.close();
    _opponentMoveController.close();
    _gameEndedController.close();
    _opponentDisconnectedRawController.close();
    _opponentReconnectedController.close();
    _presenceController.close();
    _connectionController.close();
    _matchmakingWaitingController.close();
    _errorController.close();
    _chatMessageController.close();
    _friendEventController.close();
    _chatTypingController.close();
    _gameInviteController.close();
    _gameInviteDeclinedController.close();
    _gameInviteCancelledController.close();
    _liveRequestController.close();
    _liveAnswerController.close();
    _liveCancelledController.close();
  }
}

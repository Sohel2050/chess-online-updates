import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/captured_piece_tracker.dart';
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/services/game_invite_service.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/stockfish/uci_commands.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';

// Custom game result for timeout
class WonGameTimeout extends bishop.WonGame {
  const WonGameTimeout({required super.winner});
}

// Custom game result for resignation
class WonGameResignation extends bishop.WonGame {
  const WonGameResignation({required super.winner});
}

// Custom game result for draw by agreement
class DrawnGameAgreement extends bishop.DrawnGame {
  const DrawnGameAgreement();

  @override
  String toString() => 'DrawnGameAgreement';

  @override
  String get readable => '${super.readable} by agreement';
}

// Custom game result for aborted game
class WonGameAborted extends bishop.WonGame {
  const WonGameAborted({required super.winner});
}

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  Stockfish? _stockfish;
  bool _aiThinking = false;
  /// True while Stockfish is computing a move to play FOR the human
  /// (the "AI Move" button — different from the CPU opponent's own move).
  bool _aiMoveRequestedForPlayer = false;
  bool get aiMoveRequestedForPlayer => _aiMoveRequestedForPlayer;
  bool _flipBoard = false;
  bool _stockfishInitialized = false;
  final Logger _logger = Logger();

  final SavedGameService _savedGameService = SavedGameService();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final FriendService _friendService = FriendService();
  final GameSocketService _gameSocketService = GameSocketService();
  StreamSubscription<Map<String, dynamic>>? _socketGameStartSub;
  StreamSubscription<Map<String, dynamic>>? _socketGameUpdateSub;
  StreamSubscription<Map<String, dynamic>>? _socketOpponentMoveSub;
  StreamSubscription<Map<String, dynamic>>? _socketGameEndedSub;

  bool _vsCPU = false;
  bool _localMultiplayer = false;
  bool _isOnlineGame = false;
  bool _isHost = false; // True if this player created the game room
  bool _isLoading = false;
  bool _isOpponentFriend = false;
  bool _playWhitesTimer = true;
  bool _playBlacksTimer = true;
  int _gameLevel = 1;
  int _incrementalValue = 0;
  int _player = Squares.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  Timer? _firstMoveCountdownTimer;
  int _whitesScore = 0;
  int _blacksScore = 0;
  String _gameId = '';
  String _selectedTimeControl = '';
  GameRoom? _onlineGameRoom;
  StreamSubscription<GameRoom>? gameRoomSubscription;

  /// Broadcasts every online-game-room update this provider receives from
  /// the socket (see `_initGameSocketListeners`/`onOnlineGameRoomUpdate`),
  /// so screens (e.g. `game_screen.dart`'s opponent-online-status and
  /// audio-room listeners) can subscribe without going through
  /// `GameService`/Firestore directly.
  final StreamController<GameRoom> _onlineGameRoomController =
      StreamController<GameRoom>.broadcast();
  Stream<GameRoom> get onlineGameRoomUpdates => _onlineGameRoomController.stream;
  StreamSubscription<List<ChessUser>>? _friendRequestSubscription;

  bool _drawOfferReceived = false;
  bool _drawOfferRejected = false; // For the player who offered the draw
  bool _rematchOfferSent = false; // Track if current user sent a rematch offer
  bool _rematchPending =
      false; // Track if rematch is accepted and ready to start
  bool _searchCancelled =
      false; // Flag to track if online game search was cancelled
  bool _friendRequestReceived = false;
  String? _friendRequestSenderId;
  bool _scoresUpdatedForCurrentGame = false;
  bool _gameOverProcessed = false;

  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;

  // saved time
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;

  // Time control variables
  Duration? _timePerMove;
  Duration? _bonusTime;
  Duration? _bonusThreshold;
  DateTime? _turnStartTime;

  // Online game scores
  int _player1OnlineScore = 0;
  int _player2OnlineScore = 0;

  // Audio player for timer tick sound
  late AudioPlayer _audioPlayer;
  Set<int> _playedTimerSounds =
      {}; // Track which second thresholds have played audio
  bool _audioPlayerInitialized = false;

  // Captured pieces
  // These lists will hold the captured pieces for each player
  // They will be used to display captured pieces in the UI
  // and calculate material advantage
  // They will be updated whenever a piece is captured
  List<String> _whiteCapturedPieces = [];
  List<String> _blackCapturedPieces = [];
  List<String> _moveHistory = [];
  List<String> _fenHistory = []; // Track FEN positions for undo functionality
  int _undoCount = 0; // Track number of undos performed

  // Game over notifier
  final ValueNotifier<bishop.GameResult?> _gameResultNotifier = ValueNotifier(
    null,
  );

  // Getters
  bishop.Game get game => _game;

  SquaresState get state => _state;

  bool get aiThinking => _aiThinking;

  bool get flipBoard => _flipBoard;

  Logger get logger => _logger;

  bool get vsCPU => _vsCPU;

  bool get localMultiplayer => _localMultiplayer;

  bool get isOnlineGame => _isOnlineGame;

  bool get isHost => _isHost;

  bool get isLoading => _isLoading;

  bool get isOpponentFriend => _isOpponentFriend;

  bool get playWhitesTimer => _playWhitesTimer;

  bool get playBlacksTimer => _playBlacksTimer;

  int get gameLevel => _gameLevel;

  int get incrementalValue => _incrementalValue;

  int get player => _player;

  Timer? get whitesTimer => _whitesTimer;

  Timer? get blacksTimer => _blacksTimer;

  int get whitesScore => _whitesScore;

  int get blacksScore => _blacksScore;

  String get gameId => _gameId;

  String get selectedTimeControl => _selectedTimeControl;

  GameRoom? get onlineGameRoom => _onlineGameRoom;

  Duration get whitesTime => _whitesTime;

  Duration get blacksTime => _blacksTime;

  Duration get savedWhitesTime => _savedWhitesTime;

  Duration get savedBlacksTime => _savedBlacksTime;

  int get player1OnlineScore => _player1OnlineScore;

  int get player2OnlineScore => _player2OnlineScore;

  List<String> get whiteCapturedPieces => _whiteCapturedPieces;

  List<String> get blackCapturedPieces => _blackCapturedPieces;

  List<String> get moveHistory => _moveHistory;

  bool get canUndo => _moveHistory.isNotEmpty && _vsCPU;

  ChatService get chatService => _chatService;

  bool get drawOfferReceived => _drawOfferReceived;
  bool get rematchOfferSent => _rematchOfferSent;
  bool get rematchPending => _rematchPending;

  bool get drawOfferRejected => _drawOfferRejected;

  bool get friendRequestReceived => _friendRequestReceived;

  String? get friendRequestSenderId => _friendRequestSenderId;

  StreamSubscription<GameRoom>? get geGgameRoomSubscription =>
      gameRoomSubscription;

  bishop.GameResult? get gameResult => _gameResultNotifier.value;

  ValueNotifier<bishop.GameResult?> get gameResultNotifier =>
      _gameResultNotifier;

  bool get isGameOver => _game.gameOver || _gameResultNotifier.value != null;

  // First move countdown getters - now handled by the widget

  int get firstMoveCountdownPlayer {
    if (!_isOnlineGame || _onlineGameRoom == null) return Squares.white;

    if (_onlineGameRoom!.moves.isEmpty) {
      return Squares.white; // White's turn for first move
    } else if (_onlineGameRoom!.moves.length == 1) {
      return Squares.black; // Black's turn for first move
    }
    return Squares.white; // Default
  }

  // Helper to check if we should show first move countdown
  bool get shouldShowFirstMoveCountdown {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      return false;
    }

    final shouldShow =
        _onlineGameRoom!.status == Constants.statusActive &&
        _onlineGameRoom!.moves.length <= 1 &&
        !isGameOver; // Don't show countdown after game is over

    if (shouldShow) {
      _logger.i(
        'FIRST MOVE COUNTDOWN: Should show=true, player=${firstMoveCountdownPlayer == Squares.white ? "White" : "Black"}, moves=${_onlineGameRoom!.moves.length}',
      );
    }

    return shouldShow;
  }

  // Calculate material advantage
  int get materialAdvantage {
    int whitePoints = _calculateMaterialPoints(_whiteCapturedPieces);
    int blackPoints = _calculateMaterialPoints(_blackCapturedPieces);
    return whitePoints - blackPoints;
  }

  // Get material advantage from player's perspective
  int getMaterialAdvantageForPlayer(int? playerColor) {
    int advantage = materialAdvantage;
    return playerColor == Squares.white ? advantage : -advantage;
  }

  int _calculateMaterialPoints(List<String> pieces) {
    int points = 0;
    for (String piece in pieces) {
      switch (piece.toLowerCase()) {
        case 'p':
          points += 1;
          break;
        case 'n':
        case 'b':
          points += 3;
          break;
        case 'r':
          points += 5;
          break;
        case 'q':
          points += 9;
          break;
        // King has no point value in material calculation
      }
    }
    return points;
  }

  /// Initialize audio player for timer tick sound
  Future<void> _initializeAudioPlayer() async {
    if (_audioPlayerInitialized) return;

    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer.setAsset('assets/audio/timer_tick.mp3');
      _audioPlayerInitialized = true;
      _logger.i('Audio player initialized successfully for timer ticks');
    } catch (e) {
      _logger.e('Failed to initialize audio player: $e');
      _audioPlayerInitialized = false;
    }
  }

  /// Play timer tick sound
  Future<void> playTimerTickSound() async {
    try {
      // Ensure audio player is initialized
      if (!_audioPlayerInitialized) {
        _logger.d('Audio player not initialized, initializing now...');
        await _initializeAudioPlayer();
      }

      if (_audioPlayerInitialized) {
        try {
          // Seek to beginning and play without stopping first to avoid audio clicks/pops
          await _audioPlayer.seek(Duration.zero);
          unawaited(_audioPlayer.play());
          _logger.d('Timer tick sound played successfully');
        } catch (playError) {
          _logger.e('Error playing audio: $playError');
        }
      } else {
        _logger.w(
          'Audio player initialization failed, cannot play timer sound',
        );
      }
    } catch (e) {
      _logger.e('Unexpected error in playTimerTickSound: $e');
    }
  }

  /// Resigns the current game, setting the game result to a win for the opponent.
  Future<void> resignGame({String? userId}) async {
    final winnerColor = _game.state.turn == Squares.white
        ? Squares.black
        : Squares.white;
    final winnerId = _isOnlineGame && _onlineGameRoom != null
        ? (_isHost ? _onlineGameRoom!.player2Id : _onlineGameRoom!.player1Id)
        : null; // For local/CPU, winnerId is not relevant for Firestore

    _gameResultNotifier.value = WonGameResignation(winner: winnerColor);
    _stopTimers(); // Stop timers immediately on resignation

    if (_isOnlineGame && _onlineGameRoom != null && winnerId != null) {
      _gameSocketService.resign(_onlineGameRoom!.gameId);
    }

    // Ensure the game is saved when resigned
    if (userId != null) {
      checkGameOver(userId: userId);
    }

    notifyListeners();
  }

  /// Ends the game as a draw. This is used for local multiplayer draw agreements.
  void endGameAsDraw() {
    _gameResultNotifier.value = const DrawnGameAgreement();
    _stopTimers();
    checkGameOver();
    notifyListeners();
  }

  /// Offers a draw in the current game.
  Future<void> offerDraw() async {
    // For local multiplayer, the draw is handled in the UI (_showDrawOfferDialog)
    // and calls endGameAsDraw() directly.
    // This method is now only for online games.
    if (_localMultiplayer) {
      return;
    }
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Draw offer only available in online games.');
      return;
    }

    final String offeringPlayerId = _isHost
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id!;

    _gameSocketService.offerDraw(_onlineGameRoom!.gameId);
    _logger.i('Draw offer initiated by $offeringPlayerId');
    notifyListeners();
  }

  /// Handles a draw offer (accept or decline).
  Future<void> handleDrawOffer(bool accepted) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle draw offer: Not an online game.');
      return;
    }
    // When an offer is handled, the widget should disappear.
    _drawOfferReceived = false;

    if (accepted) {
      // Set the game result to draw by agreement
      _gameResultNotifier.value = DrawnGameAgreement();
    }

    _gameSocketService.respondToDraw(gameId: _onlineGameRoom!.gameId, accepted: accepted);
    if (!accepted) {
      // If declined, ensure the timer for the current player continues.
      _startTimer();
    }
    notifyListeners();
  }

  /// Clears the local draw-offer-rejection flag. There's no corresponding
  /// server state to clean up anymore — `drawOfferStatus` on the room just
  /// gets overwritten next time a draw is offered.
  Future<void> clearDrawOfferRejection() async {
    _drawOfferRejected = false;
    notifyListeners();
  }

  /// Offers a rematch after a game.
  /// Returns error message if failed, null if successful.
  Future<String?> offerRematch() async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Rematch offer only available in online games.');
      return 'Rematch is only available for online games';
    }

    // Prevent multiple rematch offers from the same user
    if (_rematchOfferSent) {
      _logger.w('Rematch offer already sent. Waiting for opponent response.');
      return null; // Not an error, just already sent
    }

    final String offeringPlayerId = _isHost
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id!;

    try {
      _rematchOfferSent = true;
      _gameSocketService.offerRematch(_onlineGameRoom!.gameId);
      _logger.i('Rematch offer initiated by $offeringPlayerId');
      notifyListeners();
      return null; // Success
    } catch (e) {
      _rematchOfferSent = false; // Reset flag on error
      _logger.e('Error offering rematch: $e');
      return 'Failed to send rematch offer';
    }
  }

  /// Handles a rematch offer (accept or decline).
  /// Returns error message if failed, null if successful.
  Future<String?> handleRematch(bool accepted) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle rematch offer: Not an online game.');
      return 'Rematch is only available for online games';
    }

    // Immediately reset the sent flag when cancelling or declining
    if (!accepted) {
      _rematchOfferSent = false;
    }

    try {
      _gameSocketService.respondToRematch(gameId: _onlineGameRoom!.gameId, accepted: accepted);
      // On acceptance, the server creates a brand-new GameRoom and emits
      // `game:start` to both players — handled by _handleSocketGameStart,
      // which resets local board/timer state for the new game.
      notifyListeners();
      return null; // Success
    } catch (e) {
      _logger.e('Error handling rematch: $e');
      notifyListeners();
      return 'Failed to handle rematch';
    }
  }

  /// Handles a friend request (accept or decline).
  Future<void> handleFriendRequest(
    String currentUserId,
    String friendUserId,
    bool accepted,
  ) async {
    if (accepted) {
      await _friendService.acceptFriendRequest(
        currentUserId: currentUserId,
        friendUserId: friendUserId,
      );
      _isOpponentFriend = true;
    } else {
      await _friendService.declineFriendRequest(
        currentUserId: currentUserId,
        friendUserId: friendUserId,
      );
    }
    _friendRequestReceived = false;
    _friendRequestSenderId = null;
    notifyListeners();
  }

  // Audio Room Management Methods
  // These sync state (who's invited/in the room) via the game socket —
  // reusing the same `game:update` event/stream that draw/rematch offers
  // use, already wired into `onOnlineGameRoomUpdate` by
  // `_initGameSocketListeners`. The actual voice audio is LiveKit,
  // entirely separate (see game_screen.dart / livekit_token_service.dart).

  /// Invites the opponent to join the audio room
  Future<void> inviteToAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Audio room invitation only available in online games.');
      return;
    }

    _gameSocketService.inviteToAudioRoom(_onlineGameRoom!.gameId);
    _logger.i('Audio room invitation sent by $currentUserId');
    notifyListeners();
  }

  /// Handles an audio room invitation (accept or decline)
  Future<void> handleAudioRoomInvitation(
    String currentUserId,
    bool accepted,
  ) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle audio room invitation: Not an online game.');
      return;
    }

    _gameSocketService.respondToAudioRoomInvite(
      gameId: _onlineGameRoom!.gameId,
      accepted: accepted,
    );
    _logger.i(
      'Audio room invitation ${accepted ? 'accepted' : 'declined'} by $currentUserId',
    );
    notifyListeners();
  }

  /// Joins the audio room
  Future<void> joinAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot join audio room: Not an online game.');
      return;
    }

    _gameSocketService.joinAudioRoom(_onlineGameRoom!.gameId);
    _logger.i('User $currentUserId joined audio room');
    notifyListeners();
  }

  /// Leaves the audio room
  Future<void> leaveAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot leave audio room: Not an online game.');
      return;
    }

    _gameSocketService.leaveAudioRoom(_onlineGameRoom!.gameId);
    _logger.i('User $currentUserId left audio room');
    notifyListeners();
  }

  /// Ends the audio room for all participants
  Future<void> endAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot end audio room: Not an online game.');
      return;
    }

    _gameSocketService.endAudioRoom(_onlineGameRoom!.gameId);
    _logger.i('Audio room ended by $currentUserId');
    notifyListeners();
  }

  /// Checks if the current user is in the audio room
  bool isUserInAudioRoom(String userId) {
    if (_onlineGameRoom == null) return false;
    return _onlineGameRoom!.audioRoomParticipants.contains(userId);
  }

  /// Checks if there's a pending audio room invitation for the current user
  bool hasAudioRoomInvitation(String userId) {
    if (_onlineGameRoom == null) return false;
    return _onlineGameRoom!.audioRoomStatus ==
            Constants.audioStatusInvitePending &&
        _onlineGameRoom!.audioRoomInvitedBy != userId;
  }

  /// Gets the user who invited to the audio room
  String? getAudioRoomInviter() {
    if (_onlineGameRoom == null) return null;
    return _onlineGameRoom!.audioRoomInvitedBy;
  }

  /// Gets the current audio room status
  String getAudioRoomStatus() {
    if (_onlineGameRoom == null) return Constants.audioStatusNone;
    return _onlineGameRoom!.audioRoomStatus;
  }

  /// Gets the list of audio room participants
  List<String> getAudioRoomParticipants() {
    if (_onlineGameRoom == null) return [];
    return _onlineGameRoom!.audioRoomParticipants;
  }

  // Initialize Stockfish safely
  Future<void> initializeStockfish() async {
    if (_stockfishInitialized || _localMultiplayer || _isOnlineGame) return;

    try {
      // Initialize Stockfish
      _stockfish = Stockfish();

      // Load Stockfish binary
      await waitForStockfish();

      // Set Stockfish options
      _setupStockfishListener();

      // Set Stockfish to use the default engine
      _stockfishInitialized = true;
    } catch (e) {
      _stockfish = null;
      _stockfishInitialized = false;
    }
  }

  @override
  void dispose() {
    disposeStockfish();
    _stopTimers();
    _stopAudioPlayer(); // Stop any playing audio
    if (_audioPlayerInitialized) {
      _audioPlayer.dispose();
      _audioPlayerInitialized = false;
    }
    gameRoomSubscription?.cancel();
    _onlineGameRoomController.close();
    _friendRequestSubscription?.cancel();
    _socketGameStartSub?.cancel();
    _socketGameUpdateSub?.cancel();
    _socketOpponentMoveSub?.cancel();
    _socketGameEndedSub?.cancel();
    _gameSocketService.dispose();
    super.dispose();
  }

  /// Connects the game socket (if not already) and wires its event streams
  /// into the existing online-game state machine. Safe to call multiple
  /// times — subscriptions are replaced, not stacked.
  Future<void> _initGameSocketListeners() async {
    await _gameSocketService.connect();

    _socketGameStartSub?.cancel();
    _socketGameStartSub = _gameSocketService.onGameStart.listen((data) {
      final room = GameRoom.fromSocketJson(Map<String, dynamic>.from(data['room']));
      _applyNewOnlineGameRoom(room);
    });

    _socketGameUpdateSub?.cancel();
    _socketGameUpdateSub = _gameSocketService.onGameUpdate.listen((data) {
      onOnlineGameRoomUpdate(GameRoom.fromSocketJson(Map<String, dynamic>.from(data['room'])));
    });

    _socketOpponentMoveSub?.cancel();
    _socketOpponentMoveSub = _gameSocketService.onOpponentMove.listen((data) {
      onOnlineGameRoomUpdate(GameRoom.fromSocketJson(Map<String, dynamic>.from(data['room'])));
    });

    _socketGameEndedSub?.cancel();
    _socketGameEndedSub = _gameSocketService.onGameEnded.listen((data) {
      onOnlineGameRoomUpdate(GameRoom.fromSocketJson(Map<String, dynamic>.from(data['room'])));
    });
  }

  /// Sets up local board/timer state for a brand-new online game — used
  /// both for the very first game (matchmaking/private room found) and for
  /// a freshly-created rematch room. Mirrors the setup block that used to
  /// live inline in `startOnlineGameSearch` after finding/creating a
  /// Firestore game room.
  void _applyNewOnlineGameRoom(GameRoom room) {
    _onlineGameRoom = room;
    _gameId = room.gameId;
    _isHost = room.player1Id == (_currentUserIdForSocket ?? '');
    _player = _isHost ? Squares.white : Squares.black;
    _isOnlineGame = true;

    _whitesTime = Duration(milliseconds: room.whitesTimeRemaining);
    _blacksTime = Duration(milliseconds: room.blacksTimeRemaining);
    _player1OnlineScore = room.player1Score;
    _player2OnlineScore = room.player2Score;

    _game = bishop.Game(fen: room.fen);
    _state = _game.squaresState(_player);
    for (var moveString in room.moves) {
      _game.makeSquaresMove(_convertMoveStringToMove(moveString: moveString));
    }

    if (room.status == Constants.statusActive &&
        ((_isHost && _game.state.turn == Squares.white) ||
            (!_isHost && _game.state.turn == Squares.black))) {
      _startTimer();
    }

    if (room.moves.isEmpty && room.status == Constants.statusActive) {
      _startFirstMoveCountdown(forPlayer: Squares.white);
    } else if (room.moves.length == 1 && room.status == Constants.statusActive) {
      _startFirstMoveCountdown(forPlayer: Squares.black);
    }

    setLoading(false);
    notifyListeners();
  }

  // Set right before joining matchmaking / creating or joining a private
  // room, so _applyNewOnlineGameRoom can tell which side of the room is us.
  String? _currentUserIdForSocket;

  // Disposes the Stockfish engine instance and resets the initialization flag.
  // This is useful for cleaning up when a CPU game ends and the user
  // wants to return to the main menu, without destroying the GameProvider.
  void disposeStockfish() {
    if (_stockfish != null) {
      _stockfish!.dispose();
      _stockfish = null;
      _stockfishInitialized = false;
      _logger.i('Stockfish engine disposed.');
    }
  }

  Future<void> setVsCPU(bool value) async {
    _vsCPU = value;
    _isOnlineGame = false;
    _localMultiplayer = false;
    notifyListeners();
  }

  void setLocalMultiplayer(bool value) {
    _localMultiplayer = value;
    _isOnlineGame = false; // Cannot be both local and online
    _vsCPU = false;
    notifyListeners();
  }

  void setIsOnlineGame(bool value) {
    _isOnlineGame = value;
    _localMultiplayer = false; // Cannot be both local and online
    _vsCPU = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setGameLevel(int level) {
    _gameLevel = level;
    notifyListeners();
  }

  void setPlayer(int playerColor) {
    _player = playerColor;
    notifyListeners();
  }

  void setTimeControl(String timeControl) {
    _selectedTimeControl = timeControl;
    _parseTimeControl(timeControl);
    notifyListeners();
  }

  void _parseTimeControl(String timeControl) {
    // Reset all time control variables
    _timePerMove = null;
    _bonusTime = null;
    _bonusThreshold = null;
    _incrementalValue = 0;

    if (timeControl.contains('sec/move')) {
      // Format: "60 sec/move"
      final seconds = int.tryParse(timeControl.split(' ')[0]) ?? 60;
      _timePerMove = Duration(seconds: seconds);
      _whitesTime = _timePerMove!;
      _blacksTime = _timePerMove!;
    } else if (timeControl.contains('bonus')) {
      // Format: "3 min + 5s bonus 3s"
      final parts = timeControl.replaceAll('s', '').split(' ');
      final minutes = int.tryParse(parts[0]) ?? 3;
      final bonusSeconds = int.tryParse(parts[3]) ?? 5;
      final thresholdSeconds = int.tryParse(parts[5]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _bonusTime = Duration(seconds: bonusSeconds);
      _bonusThreshold = Duration(seconds: thresholdSeconds);
    } else if (timeControl.contains('min + ') && timeControl.contains('sec')) {
      // Format: "5 min + 3 sec" - Legacy increment
      final parts = timeControl.split(' ');
      final minutes = int.tryParse(parts[0]) ?? 5;
      final increment = int.tryParse(parts[4]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _incrementalValue = increment;
    } else if (timeControl.contains('min')) {
      // Format: "3 min"
      final minutes = int.tryParse(timeControl.split(' ')[0]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _incrementalValue = 0;
    }

    // Save initial times
    _savedWhitesTime = _whitesTime;
    _savedBlacksTime = _blacksTime;
  }

  String getFormattedTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  // Start the timer for the current player
  void _startTimer() {
    _stopTimers(); // Stop any existing timers
    _turnStartTime = DateTime.now();

    // Clear played timer sounds for this new timer period
    _playedTimerSounds.clear();

    if (_timePerMove != null) {
      if (_game.state.turn == Squares.white) {
        _whitesTime = _timePerMove!;
      } else {
        _blacksTime = _timePerMove!;
      }
    }

    if (_game.state.turn == Squares.white) {
      _playWhitesTimer = true;
      _playBlacksTimer = false;
      _whitesTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_whitesTime.inSeconds > 0) {
          _whitesTime = _whitesTime - const Duration(seconds: 1);

          // Play timer tick sound when time is 10 seconds or less
          if (_whitesTime.inSeconds <= 10 && _whitesTime.inSeconds > 0) {
            if (!_playedTimerSounds.contains(_whitesTime.inSeconds)) {
              _playedTimerSounds.add(_whitesTime.inSeconds);
              playTimerTickSound();
            }
          }
        } else {
          _whitesTime = Duration.zero;
          if (!_gameOverProcessed) {
            _gameResultNotifier.value = WonGameTimeout(winner: Squares.black);
            _stopTimers();
            // Use post-frame callback to avoid build-time issues
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final String? userId = _isOnlineGame && _onlineGameRoom != null
                  ? (_isHost
                        ? _onlineGameRoom!.player1Id
                        : _onlineGameRoom!.player2Id)
                  : null;
              checkGameOver(userId: userId);
            });
          }
        }
        notifyListeners();
      });
    } else {
      _playBlacksTimer = true;
      _playWhitesTimer = false;
      _blacksTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_blacksTime.inSeconds > 0) {
          _blacksTime = _blacksTime - const Duration(seconds: 1);

          // Play timer tick sound when time is 10 seconds or less
          if (_blacksTime.inSeconds <= 10 && _blacksTime.inSeconds > 0) {
            if (!_playedTimerSounds.contains(_blacksTime.inSeconds)) {
              _playedTimerSounds.add(_blacksTime.inSeconds);
              playTimerTickSound();
            }
          }
        } else {
          _blacksTime = Duration.zero;
          if (!_gameOverProcessed) {
            _gameResultNotifier.value = WonGameTimeout(winner: Squares.white);
            _stopTimers();
            // Use post-frame callback to avoid build-time issues
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final String? userId = _isOnlineGame && _onlineGameRoom != null
                  ? (_isHost
                        ? _onlineGameRoom!.player1Id
                        : _onlineGameRoom!.player2Id)
                  : null;
              checkGameOver(userId: userId);
            });
          }
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // Stop both timers
  void _stopTimers() {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    _firstMoveCountdownTimer?.cancel();
    _whitesTimer = null;
    _blacksTimer = null;
    _firstMoveCountdownTimer = null;
    _playWhitesTimer = false;
    _playBlacksTimer = false;
    _playedTimerSounds.clear();
  }

  /// Stop audio player playback
  void _stopAudioPlayer() {
    if (_audioPlayerInitialized) {
      try {
        _audioPlayer.stop();
        _logger.i('Audio player stopped');
      } catch (e) {
        _logger.e('Error stopping audio player: $e');
      }
    }
  }

  /// Public method to stop all game activities (timers and audio)
  /// Called when leaving the game screen to prevent sounds continuing in background
  void stopGameActivity() {
    _stopTimers();
    _stopAudioPlayer();
    _logger.i('Game activity stopped - all timers and audio halted');
  }

  // Reset the game state
  void resetGame(bool isNewGame) {
    _scoresUpdatedForCurrentGame = false; // Reset for the new game
    _gameOverProcessed = false; // Reset game over processing flag
    _rematchPending = false; // Clear rematch pending flag
    _stopTimers();
    _gameResultNotifier.value = null;
    // For online games, the subscription should persist to receive updates.
    // It is cancelled in dispose() or cancelOnlineGameSearch().

    // Clear captured pieces and move history
    _whiteCapturedPieces.clear();
    _blackCapturedPieces.clear();
    _moveHistory.clear();
    _fenHistory.clear();
    _undoCount = 0;

    // Pre-initialize audio player for timer sounds to ensure smooth playback
    if (!_audioPlayerInitialized) {
      _initializeAudioPlayer().catchError((e) {
        _logger.e('Failed to pre-initialize audio player in resetGame: $e');
      });
    }

    // Reset scores only if it's a completely new game, not a rematch
    if (isNewGame) {
      if (_isOnlineGame) {
        _player1OnlineScore = 0;
        _player2OnlineScore = 0;
      } else {
        _whitesScore = 0;
        _blacksScore = 0;
      }
    }

    // For a rematch or new game, swap sides.
    if (isNewGame) {
      _player = _player == Squares.white ? Squares.black : Squares.white;
    }

    // For online games, times are set from the GameRoom update
    if (!_isOnlineGame) {
      if (_timePerMove != null) {
        _whitesTime = _timePerMove!;
        _blacksTime = _timePerMove!;
      } else {
        _whitesTime = _savedWhitesTime;
        _blacksTime = _savedBlacksTime;
      }
    }

    _game = bishop.Game(variant: bishop.Variant.standard());

    // Initialize state correctly for local multiplayer or online game
    if (_localMultiplayer || _isOnlineGame) {
      // Start with white's turn
      final currentTurn = _game.state.turn; // This will be white initially
      final dynamicState = _game.squaresState(currentTurn);
      final baseState = _game.squaresState(_player);

      _state = SquaresState(
        player: currentTurn,
        state: PlayState.ourTurn,
        size: dynamicState.size,
        board: baseState.board,
        moves: dynamicState.moves,
        history: dynamicState.history,
        hands: dynamicState.hands,
        gates: dynamicState.gates,
      );
    } else {
      _state = _game.squaresState(_player);
    }

    notifyListeners();

    // Lets add a delay to start timer - not starting it immediately
    // Allow white to think for a bit before starting the timer
    Future.delayed(const Duration(milliseconds: 500), () {
      _startTimer();
    });

    // If player is black and playing vs CPU, let CPU make the first move
    if (_vsCPU && _player == Squares.black && !_localMultiplayer) {
      makeStockfishMove();
    }
  }

  // Flip the board
  void flipTheBoard() {
    _flipBoard = !_flipBoard;
    notifyListeners();
  }

  // Undo the last move(s) in VS CPU mode
  // For VS CPU, undoes both the player's last move and the CPU's response
  Future<bool> undoLastMove() async {
    if (!_vsCPU || _moveHistory.isEmpty || _fenHistory.isEmpty) {
      return false;
    }

    try {
      // For VS CPU mode, we need to undo 2 moves (player + CPU response)
      // If only 1 move was made, undo just that move
      int movesToUndo = _moveHistory.length >= 2 ? 2 : 1;

      for (int i = 0; i < movesToUndo && _fenHistory.isNotEmpty; i++) {
        // Remove the last move from history
        if (_moveHistory.isNotEmpty) {
          _moveHistory.removeLast();
        }

        // Restore to previous FEN
        String previousFen = _fenHistory.removeLast();
        _game = bishop.Game(fen: previousFen);

        // Update the game state
        _state = _game.squaresState(_player);
      }

      // Stop Stockfish thinking if it's in progress
      if (_aiThinking) {
        _aiThinking = false;
        _searchCancelled = true;
        if (_stockfish != null) {
          _stockfish!.stdin = 'stop';
        }
      }

      _undoCount++;
      _logger.i(
        'Undo performed. Moves undone: $movesToUndo. Total undos: $_undoCount',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Error undoing move: $e');
      return false;
    }
  }

  // Set AI thinking state
  void setAiThinking(bool thinking) {
    _aiThinking = thinking;
    notifyListeners();
  }

  // Check for game over conditions
  void checkGameOver({String? userId}) {
    if (isGameOver && !_gameOverProcessed) {
      _gameOverProcessed = true; // Set flag to prevent multiple processing
      _stopTimers();
      if (_gameResultNotifier.value == null) {
        _gameResultNotifier.value = _game.result;
      }

      // Update scores for online games when the game officially ends.
      if (_isOnlineGame && _onlineGameRoom != null) {
        _updateOnlineScoresOnGameOver();

        // Update game status in Firestore for online games to prevent auto-rematch bug
        // This is especially important for timeout scenarios
        if (_gameResultNotifier.value != null) {
          // Fire-and-forget update to not block the game over flow
          _updateGameStatusInFirestore();
        }
      }

      notifyListeners();

      // Save game and update user stats for all game types (not just online)
      // For local games, we'll use a placeholder userId if none provided
      String gameUserId = userId ?? 'local_user';
      if (gameUserId.isNotEmpty && gameUserId != 'local_user') {
        _saveCurrentGame(gameUserId);
      } else if (_vsCPU || _localMultiplayer) {
        // For CPU and local multiplayer games, save with a generic user ID
        // This ensures all games are tracked in the saved games collection
        _saveCurrentGame('local_user');
      }
    }
  }

  /// Updates the game status to 'completed' in Firestore
  /// Called when game ends to prevent false rematch detection
  Future<void> _updateGameStatusInFirestore() async {
    if (_onlineGameRoom == null || _gameResultNotifier.value == null) return;

    try {
      String? winnerId;
      String reason = 'gameOver';
      if (_gameResultNotifier.value is bishop.WonGame) {
        final winner = (_gameResultNotifier.value as bishop.WonGame).winner;
        winnerId = winner == _onlineGameRoom!.player1Color
            ? _onlineGameRoom!.player1Id
            : _onlineGameRoom!.player2Id;
        reason = _gameResultNotifier.value is WonGameResignation
            ? 'resignation'
            : _gameResultNotifier.value is WonGameTimeout
                ? 'timeout'
                : 'checkmate';
      } else if (_gameResultNotifier.value is bishop.DrawnGame) {
        reason = 'draw';
      }

      _gameSocketService.reportGameEnd(
        gameId: _onlineGameRoom!.gameId,
        winnerId: winnerId,
        reason: reason,
      );
      _logger.i('Reported game end to server: $reason');
    } catch (e) {
      _logger.e('Error reporting game end to server: $e');
      // Continue with game over handling even if this fails
    }
  }

  // Make squares move
  Future<bool> makeSquaresMove(Move move, {String userId = ''}) async {
    // In online games, ensure it's the player's turn to move.
    if (_isOnlineGame) {
      final isOurTurn = _game.state.turn == _player;

      // Prevent non-white players from making the first move when no moves have been made
      if (_onlineGameRoom!.moves.isEmpty && _player != Squares.white) {
        _logger.w(
          'Only white can make the first move. Current player color: $_player',
        );
        return false;
      }

      if (!isOurTurn) {
        _logger.w('Not your turn to move.');
        return false; // Prevent move if it's not our turn
      }
    }

    // First move countdown is now handled by the widget

    // Store current FEN before making the move (for undo functionality)
    if (_vsCPU) {
      _fenHistory.add(_game.fen);
    }

    bool result = _game.makeSquaresMove(move);
    if (result) {
      // Track move in algebraic notation
      if (_game.history.isNotEmpty) {
        String moveNotation = _getMoveNotation(move);
        if (moveNotation.isNotEmpty) {
          _moveHistory.add(moveNotation);
        }
      }

      // Update state based on game type
      if (_localMultiplayer) {
        // For local multiplayer, dynamically create state based on current turn
        final currentTurn = _game.state.turn;
        final dynamicState = _game.squaresState(currentTurn);
        final baseState = _game.squaresState(_player);

        _state = SquaresState(
          player: currentTurn,
          state: PlayState.ourTurn,
          size: dynamicState.size,
          board: baseState.board,
          moves: dynamicState.moves,
          history: dynamicState.history,
          hands: dynamicState.hands,
          gates: dynamicState.gates,
        );
      } else if (_isOnlineGame) {
        // For online games, update state from our player's perspective
        _state = _game.squaresState(_player);
      } else {
        // For other modes, use the standard approach
        _state = _game.squaresState(_player);
      }

      // Add increment/bonus time after a successful move
      if (_timePerMove != null) {
        // For per-move modes, the timer is reset in _startTimer for the next player
      } else if (_bonusTime != null &&
          _bonusThreshold != null &&
          _turnStartTime != null) {
        final moveDuration = DateTime.now().difference(_turnStartTime!);
        if (moveDuration <= _bonusThreshold!) {
          if (_game.state.turn == Squares.white) {
            // Bonus for black who just moved
            _blacksTime += _bonusTime!;
          } else {
            // Bonus for white who just moved
            _whitesTime += _bonusTime!;
          }
        }
      } else if (_incrementalValue > 0) {
        if (_game.state.turn == Squares.white) {
          _blacksTime += Duration(seconds: _incrementalValue);
        } else {
          _whitesTime += Duration(seconds: _incrementalValue);
        }
      }

      //debugPieceSymbols(); // Debugging piece symbols after the move
      // Update captured pieces after the move
      updateCapturedPieces();

      // If online game, sync the move to the opponent via the game socket.
      if (_isOnlineGame && _onlineGameRoom != null) {
        final updatedMoves = List<String>.from(_onlineGameRoom!.moves);
        updatedMoves.add(move.toString()); // Store move as string

        _onlineGameRoom = _onlineGameRoom!.copyWith(
          fen: _game.fen,
          moves: updatedMoves,
          whitesTimeRemaining: _whitesTime.inMilliseconds,
          blacksTimeRemaining: _blacksTime.inMilliseconds,
        );

        _gameSocketService.sendMove(
          gameId: _onlineGameRoom!.gameId,
          move: move.toString(),
          fen: _game.fen,
          whitesTimeRemaining: _whitesTime.inMilliseconds,
          blacksTimeRemaining: _blacksTime.inMilliseconds,
        );

        if (_game.gameOver) {
          // _updateGameStatusInFirestore() (called from checkGameOver below)
          // reports the final result over the socket separately.
        }

        _logger.i(
          'Move sent to server for game: ${_onlineGameRoom!.gameId}, '
          'move: ${move.toString()}, '
          'fen: ${_game.fen}',
        );
      }

      // Check game over after all updates, passing userId if available
      final String? userId = _isOnlineGame && _onlineGameRoom != null
          ? (_isHost ? _onlineGameRoom!.player1Id : _onlineGameRoom!.player2Id)
          : null;
      checkGameOver(userId: userId);

      if (!_game.gameOver) {
        _startTimer(); // Restart timer for the next player
      }
      notifyListeners();
    }

    _logger.i('Move made: ${move.from} to ${move.to}, result: $result');
    return result;
  }

  // Helper method to convert move to algebraic notation (for local history)
  String _getMoveNotation(Move move) {
    // Use bishop's toAlgebraic for more complete notation
    return move.algebraic();
  }

  // convert move string to move format
  Move _convertMoveStringToMove({required String moveString}) {
    // Split the move string intp its components
    List<String> parts = moveString.split('-');

    // Extract 'from' and 'to'
    int from = int.parse(parts[0]);
    int to = int.parse(parts[1].split('[')[0]);

    // Extract 'promo' and 'piece' if available
    String? promo;
    String? piece;
    if (moveString.contains('[')) {
      String extras = moveString.split('[')[1].split(']')[0];
      List<String> extraList = extras.split(',');
      promo = extraList[0];
      if (extraList.length > 1) {
        piece = extraList[1];
      }
    }

    // Create and return a new Move object
    return Move(from: from, to: to, promo: promo, piece: piece);
  }

  void updateCapturedPieces() {
    try {
      // Get current FEN from your game
      String currentFEN = _game.fen;

      Map<String, List<String>> captured =
          CapturedPiecesTracker.getCapturedPieces(currentFEN);

      _whiteCapturedPieces = captured['whiteCaptured']!;
      _blackCapturedPieces = captured['blackCaptured']!;

      _logger.i(
        'Captured pieces updated: '
        'White captured: ${_whiteCapturedPieces.join(', ')}, '
        'Black captured: ${_blackCapturedPieces.join(', ')}',
      );
    } catch (e) {
      _logger.e('Error updating captured pieces: $e');
      // Fallback to empty lists if there's an error
      _whiteCapturedPieces.clear();
      _blackCapturedPieces.clear();
    }
  }

  // Wait until Stockfish is ready
  Future<void> waitForStockfish() async {
    // If Stockfish is not initialized, do nothing
    if (_stockfish == null) return;

    // Wait until Stockfish is ready
    // Add timeout to prevent infinite waiting
    int attempts = 0;
    const maxAttempts = 60; // 30 seconds max

    while (_stockfish!.state.value != StockfishState.ready &&
        attempts < maxAttempts) {
      // Wait for a short duration before checking again
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw Exception('Stockfish initialization timeout');
    }
  }

  // Make a move using Stockfish AI
  /// Configures Stockfish engine based on game level
  void _configureStockfishLevel() {
    if (_stockfish == null) return;

    // Skill Level configuration (0-20 scale)
    // UCI Depth limits
    // Thinking time
    final config = _getStockfishLevelConfig(_gameLevel);

    _logger.i(
      'Configuring Stockfish - Level: $_gameLevel, Skill: ${config['skill']}, Depth: ${config['depth']}, Time: ${config['time']}ms',
    );

    // Set Skill Level (0-20)
    _stockfish!.stdin = UCICommands.buildSetOption(
      UCICommands.skillLevel,
      config['skill'],
    );

    // Set Depth limit
    if (config['depth'] != null) {
      _stockfish!.stdin = UCICommands.buildSetOption(
        UCICommands.depth,
        config['depth'],
      );
    }

    // Set MultiPV for weaker levels (show multiple best moves)
    if (_gameLevel == 0) {
      _stockfish!.stdin = UCICommands.buildSetOption(UCICommands.multiPV, 4);
    } else if (_gameLevel == 1) {
      _stockfish!.stdin = UCICommands.buildSetOption(UCICommands.multiPV, 2);
    }

    // Set Threads - reduce for easier levels
    int threads = _gameLevel == 0 ? 1 : (_gameLevel == 1 ? 2 : 4);
    _stockfish!.stdin = UCICommands.buildSetOption(
      UCICommands.threads,
      threads,
    );
  }

  /// Returns Stockfish configuration for the given level
  Map<String, dynamic> _getStockfishLevelConfig(int level) {
    switch (level) {
      case 0: // Beginner - very weak
        return {
          'skill': 0, // Weakest
          'depth': 4, // Very shallow
          'time': 300, // 300ms thinking time
        };
      case 1: // Easy - weak
        return {
          'skill': 4, // Weak beginner
          'depth': 8, // Shallow
          'time': 700, // 700ms thinking time
        };
      case 2: // Normal - intermediate
        return {
          'skill': 12, // Intermediate
          'depth': null, // No limit
          'time': 2000, // 2s thinking time
        };
      case 3: // Hard - strong
      default:
        return {
          'skill': 20, // Maximum strength
          'depth': null, // No limit
          'time': 3000, // 3s thinking time
        };
    }
  }

  Future<void> makeStockfishMove() async {
    if (_stockfish == null || !_stockfishInitialized) {
      _logger.i('Stockfish not initialized, skipping AI move');
      return;
    }

    try {
      await waitForStockfish();

      // Check if it's AI's turn
      bool isAiTurn =
          _state.state == PlayState.theirTurn ||
          (_vsCPU && _player == Squares.black && _game.state.moveNumber == 1);

      if (isAiTurn && !_aiThinking) {
        _logger.i('AI is thinking...');
        setAiThinking(true);

        // Get current position in FEN format
        _stockfish!.stdin = '${UCICommands.position} ${_game.fen}';

        // Configure Stockfish based on difficulty level
        _configureStockfishLevel();

        // Get the thinking time for this level
        final config = _getStockfishLevelConfig(_gameLevel);
        final thinkingTime = config['time'] as int;

        // Send the go command with thinking time
        _stockfish!.stdin = '${UCICommands.goMoveTime} $thinkingTime';
      }
    } catch (e) {
      _logger.e('Error making Stockfish move: $e');
      setAiThinking(false);
    }
  }

  /// "AI Move" button: asks Stockfish for the best move in the CURRENT
  /// position and plays it as if the human made it (updates moveHistory,
  /// timers, captured pieces, checks for game over — same as a normal tap
  /// move), then lets the CPU opponent respond as usual. Only valid in
  /// vsCPU mode, on the human's own turn.
  Future<void> requestAiMoveForCurrentPlayer() async {
    if (!_vsCPU) {
      _logger.w('AI Move is only available in vs-Computer games');
      return;
    }
    if (_stockfish == null || !_stockfishInitialized) {
      _logger.i('Stockfish not initialized, cannot suggest a move');
      return;
    }
    if (_aiThinking || _aiMoveRequestedForPlayer) {
      return; // already thinking (either for the CPU or for this request)
    }

    final isAiTurn =
        _state.state == PlayState.theirTurn ||
        (_vsCPU && _player == Squares.black && _game.state.moveNumber == 1);
    if (isAiTurn) {
      _logger.i('Not the player\'s turn, ignoring AI Move request');
      return;
    }

    try {
      await waitForStockfish();

      _logger.i('AI Move requested: computing best move for the player...');
      _aiMoveRequestedForPlayer = true;
      notifyListeners();

      _stockfish!.stdin = '${UCICommands.position} ${_game.fen}';

      // Always play at full strength for this — it's a move the player
      // explicitly asked the AI to make on their behalf, not the CPU
      // opponent's move (which is throttled by the selected difficulty).
      _stockfish!.stdin = UCICommands.buildSetOption(UCICommands.skillLevel, 20);
      _stockfish!.stdin = '${UCICommands.goMoveTime} 1500';
    } catch (e) {
      _logger.e('Error requesting AI move for player: $e');
      _aiMoveRequestedForPlayer = false;
      notifyListeners();
    }
  }

  void _setupStockfishListener() {
    if (_stockfish == null) return;

    _stockfish!.stdout.listen((event) {
      _logger.i('Stockfish output: $event');

      // Check if it's AI's turn and not already thinking
      bool isAiTurn =
          _state.state == PlayState.theirTurn ||
          (_vsCPU && _player == Squares.black && _game.state.moveNumber == 1);

      _logger.i('Is AI turn: $isAiTurn, AI thinking: $_aiThinking');

      // Handle the "AI Move" button's request (AI playing FOR the human on
      // their own turn) separately from the CPU opponent's own move above.
      if (_aiMoveRequestedForPlayer && event.contains(UCICommands.bestMove)) {
        final suggestedMove = event.split(' ')[1];
        _logger.i('AI-suggested move for player: $suggestedMove');

        if (_vsCPU) {
          _fenHistory.add(_game.fen);
        }

        _game.makeMoveString(suggestedMove);

        if (_game.history.isNotEmpty) {
          _moveHistory.add(suggestedMove);
        }

        _aiMoveRequestedForPlayer = false;
        _state = _game.squaresState(_player);
        updateCapturedPieces();

        if (_timePerMove == null &&
            _bonusTime != null &&
            _bonusThreshold != null &&
            _turnStartTime != null) {
          final moveDuration = DateTime.now().difference(_turnStartTime!);
          if (moveDuration <= _bonusThreshold!) {
            if (_game.state.turn == Squares.white) {
              _blacksTime += _bonusTime!;
            } else {
              _whitesTime += _bonusTime!;
            }
          }
        } else if (_incrementalValue > 0) {
          if (_game.state.turn == Squares.white) {
            _blacksTime += Duration(seconds: _incrementalValue);
          } else {
            _whitesTime += Duration(seconds: _incrementalValue);
          }
        }

        checkGameOver(userId: 'cpu_game_user');
        if (!_game.gameOver) {
          _startTimer();
          // Now let the actual CPU opponent respond, same as after any
          // normal human move (mirrors _onMove in game_screen.dart).
          makeStockfishMove();
        }
        notifyListeners();
        return;
      }

      if (isAiTurn && _aiThinking && event.contains(UCICommands.bestMove)) {
        // Extract the best move from Stockfish output
        final bestMove = event.split(' ')[1];
        _logger.i('Best move from Stockfish: $bestMove');

        // Store current FEN before making the CPU move (for undo functionality)
        if (_vsCPU) {
          _fenHistory.add(_game.fen);
        }

        // Make the move in the game
        _game.makeMoveString(bestMove);

        // Add the CPU's move to move history
        if (_game.history.isNotEmpty) {
          _moveHistory.add(bestMove);
          _logger.i('Added CPU move to history: $bestMove');
        }

        setAiThinking(false);

        _state = _game.squaresState(_player);

        // Update captured pieces after CPU move
        updateCapturedPieces();

        // Add increment/bonus time after a successful move
        if (_timePerMove != null) {
          // For per-move modes, the timer is reset in _startTimer for the next player
        } else if (_bonusTime != null &&
            _bonusThreshold != null &&
            _turnStartTime != null) {
          final moveDuration = DateTime.now().difference(_turnStartTime!);
          if (moveDuration <= _bonusThreshold!) {
            if (_game.state.turn == Squares.white) {
              // Bonus for black who just moved
              _blacksTime += _bonusTime!;
            } else {
              // Bonus for white who just moved
              _whitesTime += _bonusTime!;
            }
          }
        } else if (_incrementalValue > 0) {
          if (_game.state.turn == Squares.white) {
            _blacksTime += Duration(seconds: _incrementalValue);
          } else {
            _whitesTime += Duration(seconds: _incrementalValue);
          }
        }

        _logger.i('Move made: $bestMove');

        // For CPU games, we need to pass a user ID to ensure the game is saved
        checkGameOver(userId: 'cpu_game_user');
        if (!_game.gameOver) {
          _startTimer(); // Restart timer for the next player
        }
        notifyListeners();
      }
    });
  }

  /// Initiates the online game search or creation process.
  Future<void> startOnlineGameSearch({
    required String userId,
    required String displayName,
    String? photoUrl,
    required String playerFlag,
    required int userRating,
    required String gameMode,
    required bool ratingBasedSearch,
    BuildContext? context,
  }) async {
    // Reset cancellation flag for new search
    _searchCancelled = false;

    setLoading(true);
    setIsOnlineGame(true); // Set online game mode

    setTimeControl(gameMode);

    try {
      if (context != null) {
        updateLoadingMessage(
          context,
          'Searching for available games...',
          showCancelButton: true,
        );
      }

      _currentUserIdForSocket = userId;
      await _initGameSocketListeners();

      // Note: matchmaking is now instant-or-queued on the server (see
      // backend/sockets/gameHandlers.js) instead of a find-or-create
      // Firestore query. `_applyNewOnlineGameRoom` (fed by the
      // `onGameStart` stream wired in `_initGameSocketListeners`) takes
      // over from here once the server finds/creates the match — it sets
      // `_isHost`/`_player` from the room's player1Id/player2Id, applies
      // historical moves, and starts timers, mirroring what this method
      // used to do inline for the Firestore-found/created game.
      if (context != null) {
        updateLoadingMessage(
          context,
          'Searching for available games...',
          showCancelButton: true,
        );
      }

      _gameSocketService.joinMatchmaking(gameMode: gameMode, ratingBasedSearch: ratingBasedSearch);

      // Set up friend request listener (opponent identity isn't known yet;
      // this re-checks once _onlineGameRoom is populated by game:start).
      _friendRequestSubscription?.cancel();
      _friendRequestSubscription = _friendService
          .getFriendRequests(userId)
          .listen((requests) {
            final opponentId = _isHost
                ? _onlineGameRoom?.player2Id
                : _onlineGameRoom?.player1Id;
            if (opponentId != null) {
              final requestExists = requests.any((req) => req.uid == opponentId);
              _friendRequestReceived = requestExists;
              _friendRequestSenderId = requestExists ? opponentId : null;
              notifyListeners();
            }
          });
    } catch (e) {
      _logger.e('Error during online game search/creation: $e');
      setLoading(false);
      // Handle error, e.g., show a snackbar
      rethrow;
    }
  }

  Future<void> createPrivateGameRoom({
    required String gameMode,
    required String player1Id,
    required String player2Id,
    required String player1DisplayName,
    String? player1PhotoUrl,
    required String playerFlag,
    required int player1Rating,
  }) async {
    setLoading(true);
    setIsOnlineGame(true); // Set online game mode

    setTimeControl(gameMode);

    _isHost = true;
    _player = Squares.white; // Current user will be white
    _isOpponentFriend = await _friendService.isFriend(player1Id, player2Id);

    _currentUserIdForSocket = player1Id;
    await _initGameSocketListeners();

    // This overload addresses the invite to a specific friend, so it's
    // created via REST (`POST /games/invite`) rather than the anonymous
    // `privateGame:create` socket event — the friend may not even have the
    // app open right now, and REST lets them see it later via
    // `GameInviteService.streamGameInvites`. Once created, this socket
    // rejoins that room's channel (`game:join`) so it still receives
    // `game:start` the moment the friend accepts and joins.
    final room = await GameInviteService().sendInvite(
      friendId: player2Id,
      gameMode: gameMode,
    );

    if (room == null) {
      setLoading(false);
      _logger.e('Failed to create friend invite for $player2Id');
      return;
    }

    _gameSocketService.rejoinGame(room.gameId);

    setLoading(false);
    notifyListeners();
  }

  Future<bool> joinPrivateGameRoom({
    required String userId,
    required String displayName,
    String? photoUrl,
    required String playerFlag,
    required int userRating,
    required String gameMode,
    required String roomCode,
  }) async {
    // Set loading
    setLoading(true);
    setIsOnlineGame(true);
    setTimeControl(gameMode);

    try {
      _currentUserIdForSocket = userId;
      await _initGameSocketListeners();

      final errorCompleter = Completer<String?>();
      late final StreamSubscription errorSub;
      late final StreamSubscription startSub;
      errorSub = _gameSocketService.onError.listen((message) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(message);
      });
      startSub = _gameSocketService.onGameStart.listen((_) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(null);
      });

      _gameSocketService.joinPrivateGame(roomCode);

      // Wait briefly for either a `game:start` (success, handled by
      // _applyNewOnlineGameRoom via _initGameSocketListeners) or an
      // `error` event (room not found / already started) from the server.
      final error = await errorCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'Could not reach the room. Please try again.',
      );
      errorSub.cancel();
      startSub.cancel();

      setLoading(false);
      if (error != null) {
        _logger.w('Failed to join private room $roomCode: $error');
        return false;
      }
      return true;
    } catch (e) {
      _logger.e('Error during online game joining: $e');
      setLoading(false);
      return false;
    }
  }

  Future<void> declineGameInvite(String gameId, String userId) async {
    try {
      // Private-room invites are no longer created as separate Firestore
      // notification documents — declining just means not calling
      // joinPrivateGameRoom. Nothing server-side to clean up per invite.
      notifyListeners();
    } catch (e) {
      _logger.e('Error declining game invite: $e');
      rethrow;
    }
  }

  /// Handles updates received from the online game room stream.
  void onOnlineGameRoomUpdate(GameRoom updatedRoom) {
    // Let any external listeners (e.g. game_screen.dart's opponent-online
    // and audio-room listeners) know about this update too.
    if (!_onlineGameRoomController.isClosed) {
      _onlineGameRoomController.add(updatedRoom);
    }

    // Stop overwriting finished game state, but allow rematch and draw-related updates
    if (_gameResultNotifier.value != null) {
      // Still allow updates if this involves a rematch offer/acceptance or draw rejection
      final hasRematchOffer = updatedRoom.rematchOfferedBy != null;
      final rematchOfferCleared =
          _onlineGameRoom?.rematchOfferedBy != null &&
          updatedRoom.rematchOfferedBy == null;
      final rematchBeingAccepted =
          updatedRoom.status == Constants.statusActive &&
          updatedRoom.rematchOfferedBy == null;
      final hasDrawRejectionChange =
          (_onlineGameRoom?.drawOfferStatus != updatedRoom.drawOfferStatus) &&
          updatedRoom.drawOfferStatus == Constants.drawOfferStatusRejected;

      if (!hasRematchOffer &&
          !rematchOfferCleared &&
          !rematchBeingAccepted &&
          !hasDrawRejectionChange) {
        _logger.i(
          'ONLINE UPDATE: Game already finished, ignoring update (not rematch/draw-related)',
        );
        return;
      }

      _logger.i(
        'ONLINE UPDATE: Game finished but processing rematch/draw-related update (hasRematchOffer=$hasRematchOffer, rematchOfferCleared=$rematchOfferCleared)',
      );
    }

    _logger.i(
      'ONLINE UPDATE: Received update for game ${updatedRoom.gameId} - Status: ${updatedRoom.status}, Moves: ${updatedRoom.moves.length}, FEN: ${updatedRoom.fen}',
    );

    // If the game room is null or the ID doesn't match, ignore the update
    if (_onlineGameRoom == null ||
        _onlineGameRoom!.gameId != updatedRoom.gameId) {
      _logger.w(
        'ONLINE UPDATE: Ignoring update - gameRoom is null: ${_onlineGameRoom == null}, or ID mismatch: ${_onlineGameRoom?.gameId} vs ${updatedRoom.gameId}',
      );
      return;
    }

    final bool wasGameOver = isGameOver;
    _logger.i(
      'ONLINE UPDATE: Was game over: $wasGameOver, Is game over now: ${_game.gameOver}',
    );

    // Capture previous state BEFORE updating _onlineGameRoom
    final previousRematchOffer = _onlineGameRoom?.rematchOfferedBy;

    _onlineGameRoom = updatedRoom;
    _gameId = updatedRoom.gameId;

    // Update local game state based on Firestore updates
    // Always update times and scores, even if FEN hasn't changed (e.g., draw offer)
    _whitesTime = Duration(milliseconds: updatedRoom.whitesTimeRemaining);
    _blacksTime = Duration(milliseconds: updatedRoom.blacksTimeRemaining);
    _player1OnlineScore = updatedRoom.player1Score;
    _player2OnlineScore = updatedRoom.player2Score;

    // --- Rematch Logic ---
    // Track rematch offer changes for proper state management
    final currentRematchOffer = updatedRoom.rematchOfferedBy;

    // Detect rematch cancellation/rejection: rematch offer was cleared
    if (previousRematchOffer != null && currentRematchOffer == null) {
      _logger.i(
        '⚠️ REMATCH CANCELLED/REJECTED: Rematch offer cleared (was: $previousRematchOffer, now: null)',
      );
      // Clear the sent flag if we had sent the offer
      if (_rematchOfferSent) {
        _rematchOfferSent = false;
        _logger.i('  → Cleared _rematchOfferSent flag (user had sent offer)');
      }
      // Explicitly notify listeners to update the dialog immediately
      notifyListeners();
      _logger.i(
        '  → Called notifyListeners() for rematch cancellation/rejection',
      );
      // Don't return - allow further processing below
    }

    // Detect rematch acceptance: game was over and now it's active
    if (wasGameOver &&
        updatedRoom.status == Constants.statusActive &&
        updatedRoom.rematchOfferedBy == null) {
      _logger.i(
        'REMATCH DEBUG: Rematch detected - game was over: $wasGameOver, status: ${updatedRoom.status}, rematchOfferedBy: ${updatedRoom.rematchOfferedBy}',
      );

      // Clear the rematch offer flag since rematch was accepted
      _rematchOfferSent = false;

      // Set rematch pending flag instead of immediately resetting the game
      // This allows the game screen to close the dialog first and preserve the final position
      _rematchPending = true;

      // Explicitly reset timers for the rematch
      _whitesTime = Duration(milliseconds: updatedRoom.initialWhitesTime);
      _blacksTime = Duration(milliseconds: updatedRoom.initialBlacksTime);

      // Assign player color based on host status (not room lookup since _onlineGameRoom is already updated)
      _player = _isHost
          ? updatedRoom.player1Color
          : (updatedRoom.player2Color ?? Squares.black);

      _logger.i(
        'REMATCH DEBUG: Set rematch pending flag. Will reset game after dialog is closed.',
      );
      notifyListeners();
      return; // Exit early to avoid conflicting logic below
    }

    // Only update game board if the FEN has changed (meaning a move was made by opponent)
    if (_game.fen != updatedRoom.fen) {
      _logger.i('Updating game FEN from Firestore: ${updatedRoom.fen}');
      // Check if there's a new move (opponent's move)
      if (updatedRoom.moves.length > _moveHistory.length) {
        // Get the latest move from the opponent
        final latestMoveString = updatedRoom.moves.last;
        _logger.i('Latest move from Firestore: $latestMoveString');
        final latestMove = _convertMoveStringToMove(
          moveString: latestMoveString,
        );

        _logger.i(
          'Converted latest move: from ${latestMove.from} to ${latestMove.to}, '
          'promo: ${latestMove.promo}, piece: ${latestMove.piece}',
        );

        // Apply only the new move to our local game
        _game.makeSquaresMove(latestMove);
        _state = _game.squaresState(_player);

        // Update move history with the new move
        _moveHistory.add(_getMoveNotation(latestMove));

        // Update captured pieces and check game over
        updateCapturedPieces();

        // Only check game over if the game is actually over to prevent multiple calls
        if (_game.gameOver) {
          checkGameOver();
        }

        // Handle timer switching
        _stopTimers();

        // Start timer for the current player if game is not over
        if (!_game.gameOver &&
            ((_isHost && _game.state.turn == Squares.white) ||
                (!_isHost && _game.state.turn == Squares.black))) {
          _startTimer();
        }
      }
    }

    // Handle status changes (e.g., opponent joined, game ended)
    if (updatedRoom.status == Constants.statusActive &&
        !_game.gameOver &&
        _gameResultNotifier.value == null) {
      _logger.i('ONLINE UPDATE: Game is active and not over');
      _logger.i(
        'GAME ACTIVATION: Status changed to active, moves: ${updatedRoom.moves.length}',
      );
      // If the game is just starting, initiate the first move countdown for White.
      if (updatedRoom.moves.isEmpty) {
        _logger.i('GAME ACTIVATION: Game starting - White to move (0 moves)');
        _startFirstMoveCountdown(forPlayer: Squares.white);
      }
      // If White has made a move, but Black hasn't, start countdown for Black.
      else if (updatedRoom.moves.length == 1) {
        _logger.i('GAME ACTIVATION: After White move - Black to move (1 move)');
        _startFirstMoveCountdown(forPlayer: Squares.black);
      }
      // If both players have made their first moves, the widget will handle hiding itself

      // Ensure timer is running if game becomes active and it's our turn
      if (((_isHost && _game.state.turn == Squares.white) ||
          (!_isHost && _game.state.turn == Squares.black))) {
        _startTimer();
      }
    } else if (updatedRoom.status == Constants.statusCompleted ||
        updatedRoom.status == Constants.statusAborted) {
      _logger.i(
        'ONLINE UPDATE: Game ended - Status: ${updatedRoom.status}, WinnerId: ${updatedRoom.winnerId}',
      );
      _stopTimers();
      if (updatedRoom.status == Constants.statusAborted) {
        _logger.i('ONLINE UPDATE: Setting game result to aborted');
        _gameResultNotifier.value = WonGameAborted(
          winner: updatedRoom.player1Color == Squares.white
              ? Squares.black
              : Squares.white,
        );
      }
      // Set game result based on winnerId or status
      else if (updatedRoom.winnerId != null) {
        _logger.i(
          'ONLINE UPDATE: Setting game result based on winnerId: ${updatedRoom.winnerId}',
        );
        final winnerColor = updatedRoom.player1Id == updatedRoom.winnerId
            ? updatedRoom.player1Color
            : updatedRoom.player2Color;
        if (winnerColor != null) {
          _gameResultNotifier.value = WonGameResignation(winner: winnerColor);
          _logger.i(
            'ONLINE UPDATE: Game result set to resignation with winner color: $winnerColor',
          );
        }
      } else if (updatedRoom.status == Constants.statusCompleted) {
        _logger.i('ONLINE UPDATE: Setting game result to draw');
        // If game is completed and there's no winner, it's a draw.
        _gameResultNotifier.value = const DrawnGameAgreement();
      }
      checkGameOver();
    }

    // Handle draw offers from opponent
    final currentUserId = _isHost
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id;
    _drawOfferReceived =
        updatedRoom.drawOfferedBy != null &&
        updatedRoom.drawOfferedBy != currentUserId &&
        updatedRoom.drawOfferStatus == Constants.drawOfferStatusPending;

    if (_drawOfferReceived) {
      _logger.i(
        'ONLINE UPDATE: Draw offer received from opponent: ${updatedRoom.drawOfferedBy}',
      );
    }

    // Handle draw offer rejection
    if (updatedRoom.drawOfferStatus == Constants.drawOfferStatusRejected &&
        updatedRoom.drawOfferedBy == currentUserId) {
      _logger.i(
        '⚠️ DRAW OFFER REJECTED: Your draw offer was declined by opponent for game ${_onlineGameRoom?.gameId}',
      );
      _drawOfferRejected = true;
    } else if (updatedRoom.drawOfferStatus !=
        Constants.drawOfferStatusRejected) {
      // Clear the rejection flag if the status is no longer rejected
      if (_drawOfferRejected) {
        _logger.i('✓ Draw rejection flag cleared');
      }
      _drawOfferRejected = false;
    }

    // Handle rematch offers from opponent
    if (updatedRoom.rematchOfferedBy != null &&
        updatedRoom.rematchOfferedBy != currentUserId) {
      _logger.i(
        'ONLINE UPDATE: Rematch offer received from opponent: ${updatedRoom.rematchOfferedBy}',
      );
      // Show rematch offer dialog
      // This will be handled in GameScreen, just notify listeners
    }

    notifyListeners();
  }

  /// Waits for the game to become active (opponent joined)
  Future<void> waitForGameToStart() async {
    // If game is already active, return immediately
    if (_onlineGameRoom?.status == Constants.statusActive) {
      _logger.i('Game is already active, returning immediately');
      return;
    }

    _logger.i('Waiting for game $_gameId to become active...');

    final completer = Completer<void>();

    late final StreamSubscription startSub;
    late final StreamSubscription errorSub;

    startSub = _gameSocketService.onGameStart.listen((_) {
      // `_applyNewOnlineGameRoom` (wired in `_initGameSocketListeners`) has
      // already updated `_onlineGameRoom`/status by the time this fires.
      _logger.i('Game $_gameId is now active!');
      if (!completer.isCompleted) completer.complete();
    });
    errorSub = _gameSocketService.onError.listen((message) {
      _logger.w('Game setup error while waiting to start: $message');
      if (!completer.isCompleted) completer.completeError(message);
    });

    try {
      await completer.future.timeout(
        const Duration(minutes: 5), // 5 minute timeout
        onTimeout: () {
          _logger.w('Timed out waiting for opponent to join');

          // NOTE: there's no backend "cancel/delete private room" event
          // yet (see backend/sockets/gameHandlers.js) — a room nobody
          // ever joins is simply left in MongoDB with status "waiting".
          // Harmless (never surfaces in matchmaking, since matchmaking
          // uses its own in-memory queue, not this collection), but not
          // actively cleaned up. Add a `privateGame:cancel` event later
          // if you want this tidied up immediately instead of relying on
          // the admin panel's stale-game cleanup.
          _gameSocketService.cancelMatchmaking();

          throw TimeoutException(
            'Timed out waiting for opponent',
            const Duration(minutes: 5),
          );
        },
      );
    } catch (e) {
      _logger.e('Error in waitForGameToStart: $e');
      rethrow;
    } finally {
      startSub.cancel();
      errorSub.cancel();
    }
  }

  /// Starts a 30-second countdown for the first move in an online game.
  /// This is now handled by the FirstMoveCountdownWidget itself.
  void _startFirstMoveCountdown({required int forPlayer}) {
    // The countdown is now handled by the FirstMoveCountdownWidget
    // This method is kept for compatibility but doesn't start a timer
    final playerName = forPlayer == Squares.white ? 'White' : 'Black';
    _logger.i(
      '⏱️ FIRST MOVE COUNTDOWN: Triggered for $playerName player (${forPlayer == Squares.white ? "White" : "Black"})',
    );
  }

  /// Handles the timeout for the first move.
  Future<void> handleFirstMoveTimeout({required int winner}) async {
    if (!_isOnlineGame || _onlineGameRoom == null) return;

    _gameResultNotifier.value = WonGameTimeout(winner: winner);
    _stopTimers();

    final winnerId = winner == _onlineGameRoom!.player1Color
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id;

    // Report the timeout result to the server so both players' clients
    // agree the game ended (same `game:end` event used elsewhere for
    // resignation/checkmate/abort).
    if (winnerId != null) {
      _gameSocketService.reportGameEnd(
        gameId: _onlineGameRoom!.gameId,
        winnerId: winnerId,
        reason: 'timeout',
      );
      _logger.i('Reported first-move-timeout game end to server');
    }

    // Determine the current user's ID for saving the game
    final currentUserId = _isHost
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id;

    if (currentUserId != null) {
      checkGameOver(userId: currentUserId);
    } else {
      checkGameOver();
    }
    notifyListeners();
  }

  /// Aborts the game.
  Future<void> _abortGame() async {
    if (!_isOnlineGame || _onlineGameRoom == null) return;

    // Black wins by abortion
    final winnerColor = _onlineGameRoom!.player1Color == Squares.white
        ? Squares.black
        : Squares.white;
    _gameResultNotifier.value = WonGameAborted(winner: winnerColor);
    _stopTimers();

    final winnerId = winnerColor == _onlineGameRoom!.player1Color
        ? _onlineGameRoom!.player1Id
        : _onlineGameRoom!.player2Id;
    _gameSocketService.reportGameEnd(
      gameId: _onlineGameRoom!.gameId,
      winnerId: winnerId,
      reason: 'aborted',
    );
    checkGameOver();
    notifyListeners();
  }

  Future<void> cancelOnlineGameSearch({bool isFriend = false}) async {
    try {
      // Set flag to signal that search was cancelled
      _searchCancelled = true;

      _gameSocketService.cancelMatchmaking();

      // NOTE: there's no backend event yet to explicitly delete an
      // unclaimed private room (see the comment in `waitForGameToStart`) —
      // it's just abandoned in MongoDB with status "waiting", which is
      // harmless since matchmaking uses its own separate in-memory queue.

      // Reset game state
      _onlineGameRoom = null;
      _gameId = '';
      _isHost = false;
      setIsOnlineGame(false);
      setLoading(false);

      notifyListeners();
    } catch (e) {
      _logger.e('Error canceling online game search: $e');
      setLoading(false);
    }
  }

  void updateLoadingMessage(
    BuildContext context,
    String message, {
    bool showCancelButton = false,
  }) {
    if (context.mounted) {
      LoadingDialog.updateMessage(
        context,
        message,
        showOnlineCount: true,
        showCancelButton: showCancelButton,
        onCancel: showCancelButton ? () => cancelOnlineGameSearch() : null,
      );
    }
  }

  /// Saves the current game to Firestore and updates user statistics.
  /// This method should be called when a game concludes (win, loss, draw).
  Future<void> _saveCurrentGame(String userId) async {
    if (_gameResultNotifier.value == null) {
      _logger.w('Attempted to save game, but gameResult is null.');
      return;
    }

    String result = 'unknown';
    String winnerColor = Constants.none;
    String opponentId = '';
    String opponentDisplayName = 'CPU'; // Default for CPU games

    if (_isOnlineGame && _onlineGameRoom != null) {
      if (_isHost) {
        opponentId = _onlineGameRoom!.player2Id ?? '';
        opponentDisplayName = _onlineGameRoom!.player2DisplayName ?? 'Opponent';
      } else {
        opponentId = _onlineGameRoom!.player1Id;
        opponentDisplayName = _onlineGameRoom!.player1DisplayName;
      }
    } else if (_vsCPU) {
      opponentId = 'stockfish_ai'; // A placeholder ID for AI
      opponentDisplayName = 'CPU (Level $_gameLevel)';
    } else if (_localMultiplayer) {
      opponentId = 'local_player'; // A placeholder ID for local multiplayer
      opponentDisplayName = 'Local Player';
    }

    if (_gameResultNotifier.value is bishop.WonGame) {
      final winner = (_gameResultNotifier.value as bishop.WonGame).winner;
      winnerColor = winner == Squares.white ? Constants.white : Constants.black;
      if ((winner == Squares.white && _player == Squares.white) ||
          (winner == Squares.black && _player == Squares.black)) {
        result = Constants.win;
      } else {
        result = Constants.loss;
      }
    } else if (_gameResultNotifier.value is bishop.DrawnGame) {
      result = Constants.draw;
      winnerColor = Constants.none;
    }

    final savedGame = SavedGame(
      gameId: _gameId.isNotEmpty ? _gameId : const Uuid().v4(),
      userId: userId,
      opponentId: opponentId,
      opponentDisplayName: opponentDisplayName,
      initialFen: _game.variant.startPosition!,
      moves: _moveHistory,
      result: result,
      winnerColor: winnerColor,
      gameMode: _selectedTimeControl,
      initialWhitesTime: _savedWhitesTime.inMilliseconds,
      initialBlacksTime: _savedBlacksTime.inMilliseconds,
      finalWhitesTime: _whitesTime.inMilliseconds,
      finalBlacksTime: _blacksTime.inMilliseconds,
      createdAt: DateTime.now(),
    );

    try {
      await _savedGameService.saveGame(savedGame);
      _logger.i('Game saved successfully to Firestore.');

      // Update user statistics only for real users (not local/CPU placeholders)
      if (userId != 'local_user' && userId != 'cpu_game_user') {
        await _userService.updateUserStatsAfterGame(
          userId: userId,
          gameResult: result,
          gameMode: _selectedTimeControl,
          gameId: savedGame.gameId,
          opponentId: opponentId,
        );
        _logger.i('User statistics updated successfully.');
      } else {
        _logger.i('Skipped user stats update for local/CPU game.');
      }
    } catch (e) {
      _logger.e('Failed to save game or update user stats: $e');
    }
  }

  void _updateOnlineScoresOnGameOver() {
    if (_scoresUpdatedForCurrentGame || _gameResultNotifier.value == null) {
      return; // Ensure scores are updated only once per game
    }

    int newP1Score = _onlineGameRoom!.player1Score;
    int newP2Score = _onlineGameRoom!.player2Score;

    if (_gameResultNotifier.value is bishop.WonGame) {
      final winner = (_gameResultNotifier.value as bishop.WonGame).winner;
      if (winner == _onlineGameRoom!.player1Color) {
        newP1Score++;
      } else {
        newP2Score++;
      }
    }
    // No score change for a draw

    // Update local state immediately for UI responsiveness
    _player1OnlineScore = newP1Score;
    _player2OnlineScore = newP2Score;

    // Report to the server so both players' clients (and the persisted
    // GameRoom) agree on scores — same `game:update` event used elsewhere.
    _gameSocketService.updateScores(
      gameId: _onlineGameRoom!.gameId,
      player1Score: newP1Score,
      player2Score: newP2Score,
    );

    _scoresUpdatedForCurrentGame = true;
    _logger.i('Updated scores on game over: P1: $newP1Score, P2: $newP2Score');
  }

  /// Deletes all chat messages between two users.
  Future<void> deleteChatMessages(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      await _chatService.deleteChatMessages(currentUserId, otherUserId);
      _logger.i(
        'Chat messages between $currentUserId and $otherUserId deleted.',
      );
    } catch (e) {
      _logger.e('Error deleting chat messages: $e');
    }
  }
}

import 'package:flutter_chess_app/utils/debug_log.dart';
import 'package:flutter_chess_app/providers/streak_provider.dart';
import 'package:flutter_chess_app/providers/mission_provider.dart';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/widgets/floating_message_button.dart';
import 'package:flutter_chess_app/services/game_analyzer.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/services/monetization_service.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:flutter_chess_app/widgets/monetization_ads_widget.dart'
    show MonetizationAdsWidget, MonetizationAdType;
import 'package:flutter_chess_app/services/permission_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_chess_app/services/sound_service.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/audio_access_dialog.dart';
import 'package:flutter_chess_app/widgets/audio_controls_widget.dart';
import 'package:flutter_chess_app/widgets/audio_room_invitation_dialog.dart';
import 'package:flutter_chess_app/widgets/captured_piece_widget.dart';
import 'package:flutter_chess_app/widgets/confirmation_dialog.dart';
import 'package:flutter_chess_app/widgets/draw_offer_widget.dart';
import 'package:flutter_chess_app/widgets/takeback_offer_widget.dart';
import 'package:flutter_chess_app/widgets/friend_request_widget.dart';
import 'package:flutter_chess_app/widgets/rematch_offer_widget.dart';
import 'package:flutter_chess_app/widgets/first_move_countdown_widget.dart';
import 'package:flutter_chess_app/widgets/game_over_dialog.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/unread_badge_widget.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:flutter_chess_app/widgets/reaction_widgets.dart';
import 'package:flutter_chess_app/widgets/live_watch_sheet.dart';
import 'package:flutter_chess_app/widgets/move_arrow_overlay.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/report_game_dialog.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:flutter_chess_app/services/livekit_token_service.dart';

class GameScreen extends StatefulWidget {
  final ChessUser user;
  const GameScreen({super.key, required this.user});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameProvider _gameProvider;
  bool _appInForeground = true; // game sounds only play while true
  late AudioPlayer _checkmateSoundPlayer;
  late AudioPlayer _messageSoundPlayer;

  // Game over handling flag
  bool _gameOverHandled = false;
  // Options > Confirm Moves: the move the player picked, waiting for Confirm / Cancel.
  Move? _pendingMove;
  String? _pendingFen; // position the pending move was picked in (a changed position cancels it)
  int _seenNewGameCounter = 0; // see _handleRematchStateChange
  bool _isGameOverDialogShowing = false;

  // Audio room state variables
  bool _isInAudioRoom = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerMuted = false;
  bool _hasTemporaryAudioAccess = false; // For rewarded ad access
  // Admin-controlled: whether the voice-chat ad-gate is active at all,
  // independent of the general ads toggle (see AdminService.watchVoiceChatAdGateEnabled).
  bool _voiceChatAdGateEnabled = true;
  StreamSubscription<bool>? _voiceChatAdGateSub;
  bool _isVoiceEngineInitialized = false;
  String? _currentAudioRoomId;
  StreamSubscription<GameRoom>? _audioRoomSubscription;

  // Audio stream management
  lk.Room? _voiceRoom;

  // Message notification variables
  StreamSubscription<int>? _unreadMessageSubscription;
  // Online training games: own engine for live warnings (see GameAnalyzer).
  GameAnalyzer? _trainingAnalyzer;
  bool _trainingStarting = false;
  int _previousUnreadCount = 0;

  // Rematch offer state
  bool _showRematchOffer = false;
  String? _rematchOffererName;
  bool _rematchExplicitlyAccepted = false;

  // Banner ads are now handled by MonetizationBannerWidget

  // Opponent online status comes from GameProvider.isOpponentOnline (real socket presence).

  @override
  void initState() {
    super.initState();
    FloatingMessageController.hide();
    WidgetsBinding.instance.addObserver(this);
    _gameProvider = context.read<GameProvider>();
    _gameProvider.setGameSoundsAllowed(true); // sounds belong to this screen only
    _checkmateSoundPlayer = AudioPlayer();
    _messageSoundPlayer = AudioPlayer();
    _gameProvider.gameResultNotifier.addListener(_handleGameOver);
    _gameProvider.addListener(_handleRematchStateChange);

    // Live-updating admin toggle for the voice-chat ad-gate.
    _voiceChatAdGateSub = AdminService().watchVoiceChatAdGateEnabled().listen((enabled) {
      if (mounted) setState(() => _voiceChatAdGateEnabled = enabled);
    });

    // We make sure to reset the game state when entering the game screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider.resetGame(false); // Start the game and timer
      _gameProvider.trackGameStart();
      _gameOverHandled = false; // Reset the game over flag for new games
      _endAdHandled = false; // new game: one ad allowed again
      _rematchExplicitlyAccepted = false; // Reset rematch flag for new games

      // GameProvider already processes socket room updates centrally.
      // Do not subscribe this screen back into onOnlineGameRoomUpdate:
      // that method republishes to onlineGameRoomUpdates and would create
      // a feedback loop. Audio-room updates use their separate listener below.
    });

    // Listen for draw offer rejection
    _gameProvider.addListener(_handleDrawOfferRejection);
    _gameProvider.addListener(_handleTakebackRejection);

    // Set up audio room monitoring for online games
    if (_gameProvider.isOnlineGame && _gameProvider.onlineGameRoom != null) {
      _setupAudioRoomListener();
    }

    // Set up message sound notification for online games
    if (_gameProvider.isOnlineGame && _gameProvider.onlineGameRoom != null) {
      _setupMessageSoundNotification();
    }
  }

  /// Silences every game sound the moment the app leaves the foreground, and
  /// lets them work again only when the player comes back to this screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    _gameProvider.setGameSoundsAllowed(foreground);
    _gameProvider.setAppForeground(foreground); // opponent sees Offline while we are away
    if (!foreground) {
      _checkmateSoundPlayer.stop();
      _messageSoundPlayer.stop();
    }
  }

  @override
  void dispose() {
    _trainingAnalyzer?.dispose();
    _trainingAnalyzer = null;
    FloatingMessageController.show();
    WidgetsBinding.instance.removeObserver(this);
    _gameProvider.gameResultNotifier.removeListener(_handleGameOver);
    _gameProvider.removeListener(_handleDrawOfferRejection);
    _gameProvider.removeListener(_handleTakebackRejection);
    _gameProvider.removeListener(_handleRematchStateChange);
    _voiceChatAdGateSub?.cancel();

    // Stop all game activity (timers and audio) to prevent sounds continuing after leaving screen
    _gameProvider.stopGameActivity();

    // Cleanup audio room if still connected
    if (_isInAudioRoom) {
      _cleanupVoiceEngine().catchError((e) {
        // Handle cleanup error silently in dispose
      });
    }

    // Cancel audio room subscription
    _audioRoomSubscription?.cancel();

    // Cancel message subscription
    _unreadMessageSubscription?.cancel();

    // Dispose audio players
    _checkmateSoundPlayer.dispose();
    _messageSoundPlayer.dispose();

    // Banner ads are now handled by MonetizationBannerWidget

    super.dispose();
  }

  void _setupAudioRoomListener() {
    if (_gameProvider.onlineGameRoom == null) return;

    _audioRoomSubscription = _gameProvider.onlineGameRoomUpdates.listen(
      (gameRoom) => _handleAudioRoomUpdates(gameRoom),
      onError: (error) {
        _gameProvider.logger.e(
          'Error listening to audio room updates: $error',
        );
      },
    );
  }

  void _setupMessageSoundNotification() {
    if (_gameProvider.onlineGameRoom == null) return;

    final opponentId =
        _gameProvider.onlineGameRoom!.player1Id == widget.user.uid
        ? _gameProvider.onlineGameRoom!.player2Id
        : _gameProvider.onlineGameRoom!.player1Id;

    if (opponentId == null) return;

    final chatRoomId = _gameProvider.chatService.getChatRoomId(
      widget.user.uid!,
      opponentId,
    );

    _unreadMessageSubscription = _gameProvider.chatService
        .getUnreadMessageCount(chatRoomId, widget.user.uid!)
        .listen((unreadCount) {
          // Play sound only when unread count increases (new message received)
          if (unreadCount > _previousUnreadCount) {
            dlog('📨 New message received - unread count: $unreadCount');
            _playMessageSound();
            _flyMessageToChatIcon();
          }
          _previousUnreadCount = unreadCount;
        });
  }

  final GlobalKey _chatIconKey = GlobalKey();

  /// A small bubble leaves the board centre, flies to the chat icon in the
  /// top bar and fades away. Ignores touches, so it never blocks a move.
  void _flyMessageToChatIcon() {
    if (!mounted) return;
    final iconBox = _chatIconKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (iconBox == null || !iconBox.attached || overlay == null) return;
    final size = MediaQuery.of(context).size;
    final start = Offset(size.width / 2, size.height / 2);
    final end = iconBox.localToGlobal(iconBox.size.center(Offset.zero));
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
          onEnd: () => entry.remove(),
          builder: (_, t, __) {
            // slight curve: sideways bulge in the middle of the flight
            final pos = Offset.lerp(start, end, t)! +
                Offset(40 * (1 - (2 * t - 1) * (2 * t - 1)), 0);
            final scale = t < 0.2 ? 0.6 + 2 * t : 1.0 - 0.7 * ((t - 0.2) / 0.8);
            final opacity = t < 0.85 ? 1.0 : (1 - t) / 0.15;
            return Positioned(
              left: pos.dx - 20,
              top: pos.dy - 20,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF22C55E),
                    child: Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _playMessageSound() async {
    if (!mounted || !_appInForeground || !SoundService.instance.audible) return;
    try {
      dlog('🔊 Attempting to play message sound...');
      await _messageSoundPlayer.setAsset('assets/audio/message.wav');
      await _messageSoundPlayer.play();
      dlog('✅ Message sound played successfully');
    } catch (e) {
      dlog('❌ Error playing message sound: $e');
      _gameProvider.logger.e('Error playing message sound: $e');
    }
  }

  void _handleAudioRoomUpdates(GameRoom gameRoom) {
    final currentUserId = widget.user.uid!;
    final audioRoomStatus = gameRoom.audioRoomStatus;
    final audioRoomParticipants = gameRoom.audioRoomParticipants;
    final audioRoomInvitedBy = gameRoom.audioRoomInvitedBy;

    // Handle audio room invitation
    if (audioRoomStatus == Constants.audioStatusInvitePending &&
        audioRoomInvitedBy != currentUserId) {
      _showAudioRoomInvitation(gameRoom);
    }

    // Handle when audio room becomes active
    if (audioRoomStatus == Constants.audioStatusActive &&
        audioRoomParticipants.contains(currentUserId) &&
        !_isInAudioRoom) {
      _autoJoinAudioRoom();
    }

    // Handle when audio room ends or user is removed from audio room
    if (audioRoomStatus == Constants.audioStatusEnded && _isInAudioRoom) {
      _autoLeaveAudioRoom();
    } else if (!audioRoomParticipants.contains(currentUserId) &&
        _isInAudioRoom) {
      _autoLeaveAudioRoom();
    }

    // Notify user when opponent starts audio
    if (audioRoomStatus == Constants.audioStatusInvitePending &&
        audioRoomInvitedBy != currentUserId) {
      _showAudioStartedNotification(gameRoom);
    }
  }

  void _showAudioRoomInvitation(GameRoom gameRoom) async {
    final invitingUserId = gameRoom.audioRoomInvitedBy;
    if (invitingUserId == null) return;

    // Get inviting user details
    final invitingUser = gameRoom.player1Id == invitingUserId
        ? ChessUser(
            uid: gameRoom.player1Id,
            displayName: gameRoom.player1DisplayName,
            photoUrl: gameRoom.player1PhotoUrl,
            countryCode: gameRoom.player1Flag,
          )
        : ChessUser(
            uid: gameRoom.player2Id,
            displayName: gameRoom.player2DisplayName ?? 'Opponent',
            photoUrl: gameRoom.player2PhotoUrl,
            countryCode: gameRoom.player2Flag,
          );

    final result = await AudioRoomInvitationDialog.show(
      context: context,
      invitingUser: invitingUser,
    );

    if (result == AudioRoomAction.join) {
      await _handleAudioRoomJoin();
    } else if (result == AudioRoomAction.reject) {
      await _gameProvider.handleAudioRoomInvitation(widget.user.uid!, false);
    }
  }

  void _showAudioStartedNotification(GameRoom gameRoom) {
    final invitingUserName = gameRoom.player1Id == gameRoom.audioRoomInvitedBy
        ? gameRoom.player1DisplayName
        : gameRoom.player2DisplayName ?? 'Opponent';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            _assetIcon(AssetsManager.micIcon, 24, Icons.mic),
            const SizedBox(width: 8),
            Expanded(child: Text('$invitingUserName started audio room')),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Join',
          textColor: Colors.white,
          onPressed: _handleAudioRoomJoin,
        ),
      ),
    );
  }

  Future<void> _handleAudioRoomJoin() async {
    // Check microphone permission first
    final permissionService = PermissionService();
    final permissionResult = await permissionService
        .requestMicrophonePermission(context);

    if (permissionResult == PermissionResult.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice chat'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else if (permissionResult == PermissionResult.permanentlyDenied) {
      await permissionService.handlePermanentlyDeniedPermission(
        context,
        'Microphone',
      );
      return;
    }

    // Check if user has premium or temporary access
    if (!_hasAudioAccess()) {
      final result = await AudioAccessDialog.show(context: context);

      if (result == AudioAccessAction.watchAd) {
        _hasTemporaryAudioAccess = true;
      } else if (result == AudioAccessAction.premium) {
        // Navigate to premium screen or show premium info
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit Profile screen to upgrade to Premium'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } else {
        return; // User cancelled
      }
    }

    try {
      // Accept the audio room invitation
      await _gameProvider.handleAudioRoomInvitation(widget.user.uid!, true);

      // Initialize voice engine if not already done
      await _initializeVoiceEngineIfNeeded();

      // Remote audio tracks are auto-subscribed and attached by the LiveKit
      // TrackSubscribedEvent listener, so no manual stream start is needed.

      if (!mounted) return;
      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = true; // Start with mic enabled
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined audio room'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join audio room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _autoJoinAudioRoom() async {
    if (_isInAudioRoom) return;

    // Check microphone permission before auto-joining
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      _gameProvider.logger.w(
        'Cannot auto-join audio room: microphone permission not granted',
      );
      return;
    }

    try {
      await _initializeVoiceEngineIfNeeded();

      // Remote audio tracks are auto-subscribed and attached by the LiveKit
      // TrackSubscribedEvent listener, so no manual stream start is needed.

      if (!mounted) return;
      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = true;
      });
    } catch (e) {
      _gameProvider.logger.e('Failed to auto-join audio room: $e');
    }
  }

  Future<void> _autoLeaveAudioRoom() async {
    if (!_isInAudioRoom) return;

    try {
      await _cleanupVoiceEngine();

      if (!mounted) return;
      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Audio room ended'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _gameProvider.logger.e('Failed to auto-leave audio room: $e');
    }
  }

  bool _hasAudioAccess() {
    // If the admin has turned the voice-chat ad-gate off specifically,
    // voice chat is free for everyone — independent of the general ads
    // toggle (banner/interstitial/native/etc stay unaffected).
    if (!_voiceChatAdGateEnabled) return true;
    return !MonetizationService.shouldShowAds(context, widget.user) ||
        _hasTemporaryAudioAccess;
  }

  /// Build online/offline status indicator widget
  Widget _buildOnlineStatusIndicator({
    required bool isOnline,
    double size = 14,
    EdgeInsets padding = const EdgeInsets.all(0),
  }) {
    return Container(
      width: size,
      height: size,
      margin: padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey,
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.grey).withAlpha(128),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
    );
  }

  /// Build online status indicator with label
  Widget _buildOnlineStatusWithLabel({
    required bool isOnline,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOnlineStatusIndicator(isOnline: isOnline, size: 10),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isOnline ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Play checkmate sound effect
  Future<void> _playCheckmateSoundEffect() async {
    if (!mounted || !_appInForeground || !SoundService.instance.audible) return;
    try {
      await _checkmateSoundPlayer.setAsset('assets/audio/checkmate.wav');
      await _checkmateSoundPlayer.play();
    } catch (e) {
      _gameProvider.logger.e('Error playing checkmate sound: $e');
    }
  }

  /// Handle rematch state changes (reset game over flag when rematch is accepted)
  void _handleRematchStateChange() {
    // A brand-new online game replaced the finished one (rematch): close the
    // old "game over" dialog and clear the screen's per-game flags.
    if (_seenNewGameCounter != _gameProvider.newGameCounter) {
      _seenNewGameCounter = _gameProvider.newGameCounter;
      if (_isGameOverDialogShowing && mounted) {
        _isGameOverDialogShowing = false; // closed exactly once, never popped twice
        Navigator.of(context).pop(GameOverAction.none);
      }
      if (mounted) {
        setState(() {
          _gameOverHandled = false;
          _endAdHandled = false; // new game: one ad allowed again
          _rematchExplicitlyAccepted = false;
          _showRematchOffer = false;
          _rematchOffererName = null;
        });
      }
      return;
    }

    // Auto-close dialog if rematch is pending (opponent accepted rematch)
    if (_gameProvider.rematchPending && _isGameOverDialogShowing && mounted) {
      _gameProvider.logger.i(
        'Rematch pending detected - auto-closing game over dialog',
      );
      // Close the game over dialog (flag cleared first so it can never be popped twice)
      _isGameOverDialogShowing = false;
      Navigator.of(context).pop(GameOverAction.none);
      // Reset the game after a short delay to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _gameProvider.logger.i('Resetting game for rematch');
          _gameProvider.resetGame(false);
          _gameProvider.trackGameStart();
          setState(() {
            _gameOverHandled = false;
            _endAdHandled = false; // new game: one ad allowed again
            _rematchExplicitlyAccepted = false;
          });
        }
      });
      return;
    }

    // Handle rematch pending when dialog is already closed (for player who accepted)
    if (_gameProvider.rematchPending && !_isGameOverDialogShowing && mounted) {
      _gameProvider.logger.i(
        'Rematch pending detected - dialog already closed, resetting game',
      );
      _gameProvider.resetGame(false);
      _gameProvider.trackGameStart();
      setState(() {
        _gameOverHandled = false;
        _endAdHandled = false; // new game: one ad allowed again
        _rematchExplicitlyAccepted = false;
        _showRematchOffer = false;
        _rematchOffererName = null;
      });
      return;
    }

    // Don't process other state changes while dialog is showing
    if (_isGameOverDialogShowing) {
      return;
    }

    // Reset _gameOverHandled flag ONLY when rematch is explicitly accepted
    if (_gameProvider.isOnlineGame &&
        !_gameProvider.isGameOver &&
        _gameOverHandled &&
        _rematchExplicitlyAccepted) {
      _gameProvider.logger.i(
        'Rematch accepted - resetting game over flag to allow new dialogs',
      );
      setState(() {
        _gameOverHandled = false;
        _endAdHandled = false; // new game: one ad allowed again
        _showRematchOffer = false; // Hide rematch offer widget
        _rematchOffererName = null;
        _rematchExplicitlyAccepted = false; // Reset the flag
      });
    }

    // Show rematch offer widget if game is over, dialog was dismissed, and dialog is NOT currently showing
    if (_gameProvider.isOnlineGame &&
        _gameProvider.isGameOver &&
        _gameOverHandled &&
        !_isGameOverDialogShowing &&
        _gameProvider.onlineGameRoom?.rematchOfferedBy != null &&
        _gameProvider.onlineGameRoom?.rematchOfferedBy != widget.user.uid) {
      // Get opponent name who offered the rematch
      final opponentName =
          _gameProvider.onlineGameRoom!.player1Id ==
              _gameProvider.onlineGameRoom!.rematchOfferedBy
          ? _gameProvider.onlineGameRoom!.player1DisplayName
          : _gameProvider.onlineGameRoom!.player2DisplayName ?? 'Opponent';

      if (mounted) {
        setState(() {
          _showRematchOffer = true;
          _rematchOffererName = opponentName;
        });
      }
    } else if (_gameProvider.isOnlineGame &&
        (_gameProvider.onlineGameRoom?.rematchOfferedBy == null ||
            _gameProvider.onlineGameRoom?.rematchOfferedBy ==
                widget.user.uid)) {
      // Hide the widget if rematch offer was cleared or if current user is the offerer
      if (mounted && _showRematchOffer) {
        setState(() {
          _showRematchOffer = false;
          _rematchOffererName = null;
        });
      }
    }
  }

  /// Handle rematch offer accept
  Future<void> _handleRematchAccept() async {
    setState(() {
      _showRematchOffer = false;
      _rematchOffererName = null;
      _rematchExplicitlyAccepted =
          true; // Mark that rematch was explicitly accepted
    });

    final error = await _gameProvider.handleRematch(true);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Handle rematch offer decline
  Future<void> _handleRematchDecline() async {
    setState(() {
      _showRematchOffer = false;
      _rematchOffererName = null;
    });

    final error = await _gameProvider.handleRematch(false);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Tells the player their takeback request was declined (shown once).
  void _handleTakebackRejection() {
    if (_gameProvider.takebackRejected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.undo, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Your takeback request was declined')),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
      _gameProvider.clearTakebackRejection();
    }
  }

  /// Abort: only offered by the server before 2 plies; no result, no rating change.
  void _showAbortDialog() async {
    final bool? confirm = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Abort Game?',
      maxWidth: 400,
      isDestructive: true,
      icon: Icons.cancel_outlined,
      child: const ConfirmationDialog(
        message: 'The game will be cancelled. No rating change.',
        confirmButtonText: 'Abort',
        cancelButtonText: 'Keep playing',
        isDestructive: true,
        confirmIcon: Icons.cancel_outlined,
      ),
    );
    if (confirm == true) await _gameProvider.abortOnlineGame();
  }

  /// Ask the opponent to allow taking back our last move.
  void _showTakebackOfferDialog() async {
    final bool? confirm = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Ask for a takeback?',
      maxWidth: 400,
      child: const ConfirmationDialog(
        message: 'Your opponent must agree. Your last move (and their reply, if any) will be undone.',
        confirmButtonText: 'Ask',
        cancelButtonText: 'Cancel',
      ),
    );
    if (confirm == true) {
      await _gameProvider.offerTakeback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takeback request sent'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  /// Handle draw offer rejection notification
  void _handleDrawOfferRejection() {
    // Handle rejection received from opponent (user offered, opponent rejected)
    if (_gameProvider.drawOfferRejected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.handshake, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Your draw offer was declined')),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 3),
        ),
      );

      // Clear the rejection flag after showing the notification
      _gameProvider.clearDrawOfferRejection();
    }
  }

  /// One interstitial per game, however the player leaves it (new game, back button,
  /// quit, win, lose or draw). Returns once the ad closed, failed or was skipped.
  bool _endAdHandled = false;
  bool _isLeaving = false;

  /// Ads only run in online games, for users who should see ads.
  bool _endAdAllowed() =>
      mounted &&
      _gameProvider.isOnlineGame &&
      MonetizationService.shouldShowAds(context, widget.user);

  /// Game over: short pause (the player sees the final position), then the ad (once),
  /// then the Game Over dialog (Rematch / Review / New game). Nothing the player does
  /// after that shows another ad.
  Future<void> _showAdThenGameOverDialog() async {
    if (_endAdAllowed() && !_endAdHandled) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted || _isLeaving) return;
      await _showEndOfGameAdOnce();
    }
    // Still the same finished game and the screen is still here?
    if (!mounted || _isLeaving || !_gameProvider.isGameOver) return;
    _showGameOverDialog();
  }

  Future<void> _showEndOfGameAdOnce() async {
    if (_endAdHandled) return;
    _endAdHandled = true;
    if (!mounted) return;
    if (!_endAdAllowed()) return;

    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator.adaptive()),
    );
    MonetizationService.showInterstitialAd(
      context: context,
      onAdClosed: () {
        log('Interstitial ad closed');
        finish();
      },
      onAdFailedToLoad: () {
        log('Interstitial ad skipped or failed to load');
        finish();
      },
    );
    // Safety net: never leave the player stuck on the loading spinner.
    await done.future.timeout(const Duration(seconds: 60), onTimeout: () {});
    if (mounted) Navigator.of(context).pop(); // close the loading spinner
  }

  void _handleGameOver() {
    // Prevent multiple calls to this method
    if (_gameOverHandled) {
      return;
    }
    // Already leaving (quit): no game-over dialog on top of the exit flow.
    if (_isLeaving) return;

    // Only show dialog if game result is not null and game is actually over
    final gameResult = _gameProvider.gameResult;
    if (gameResult == null || !_gameProvider.isGameOver) return;

    _gameOverHandled = true;

    // Play checkmate sound if it's a checkmate
    if (gameResult is bishop.WonGameCheckmate) {
      _playCheckmateSoundEffect();
    } else if (_appInForeground) {
      // Draw, resignation, timeout, ...: the end-of-game sound (obeys Options > Sound Effects).
      SoundService.instance.play(SoundEffect.gameEnd);
    }

    // Ensure the game is saved for all game types
    if (!_gameProvider.isOnlineGame) {
      // For local games (CPU or local multiplayer), manually trigger save
      _gameProvider.checkGameOver(userId: widget.user.uid);
    }

    // delete chat messages for online games only
    if (_gameProvider.isOnlineGame) {
      final gameRoom = _gameProvider.onlineGameRoom;
      if (gameRoom != null) {
        final opponentId = gameRoom.player1Id == widget.user.uid
            ? gameRoom.player2Id
            : gameRoom.player1Id;
        if (opponentId != null) {
          _gameProvider.deleteChatMessages(widget.user.uid!, opponentId);
        }
      }
    }

    // A finished game counts for the daily streak and the daily missions on the SERVER (online
    // games it finishes itself, CPU games when the result is saved). Give it a moment, then refresh.
    final missionProvider = context.read<MissionProvider>();
    final streakProvider = context.read<StreakProvider>();
    Future.delayed(const Duration(seconds: 3), () {
      streakProvider.refresh();
      missionProvider.refresh();
    });

    // Ad first (once per game), then the dialog with Rematch / Review / New game.
    _showAdThenGameOverDialog();
  }

  void _showGameOverDialog() {
    if (mounted) {
      setState(() {
        _isGameOverDialogShowing = true;
      });
      AnimatedDialog.show(
        context: context,
        title: 'Game Over!',
        maxWidth: 400,
        barrierDismissible: false,
        child: GameOverDialog(
          result: _gameProvider.gameResult,
          user: widget.user,
          playerColor: _gameProvider.player,
          isOnlineGame: _gameProvider.isOnlineGame,
        ),
      ).then((action) {
        if (!mounted) return; // the screen was left while the dialog was open
        setState(() {
          _isGameOverDialogShowing = false;
        });
        if (action == null) return; // Dialog was dismissed

        final isOnline = _gameProvider.isOnlineGame;

        switch (action) {
          case GameOverAction.rematch:
            // Mark that rematch was explicitly accepted
            setState(() {
              _rematchExplicitlyAccepted = true;
              _gameOverHandled = false;
              _endAdHandled = false; // new game: one ad allowed again
            });
            break;
          case GameOverAction.newGame:
            _gameProvider.disposeStockfish();
            if (isOnline) {
              // For online, properly leave the game room before navigating.
              _gameProvider.cancelOnlineGameSearch();
            }

            // The ad was already shown before this dialog: just go back.
            if (mounted) Navigator.of(context).pop();
            break;
          case GameOverAction.none:
            // Do nothing
            break;
        }
      });
    }
  }

  /// Online training game: warn about my own last move with a separate engine.
  Future<void> _trainingCheck(String fenBefore, String fenAfter) async {
    if (_trainingAnalyzer == null) {
      if (_trainingStarting) return;
      _trainingStarting = true;
      final analyzer = GameAnalyzer();
      final ok = await analyzer.start();
      _trainingStarting = false;
      if (!mounted || !ok) {
        analyzer.dispose();
        return;
      }
      _trainingAnalyzer = analyzer;
    }
    final warning = await _trainingAnalyzer?.checkMove(fenBefore, fenAfter);
    if (warning != null && mounted && _gameProvider.coachEnabled) {
      _gameProvider.showCoachWarning(warning);
    }
  }

  /// A move picked on the board. With Options > Confirm Moves it only becomes a pending move
  /// (arrow + Confirm / Cancel bar); otherwise it is played at once. Premoves are never held back.
  void _onMove(Move move) {
    if (context.read<SettingsProvider>().confirmMoves && !_gameProvider.isGameOver) {
      setState(() {
        _pendingMove = move;
        _pendingFen = _gameProvider.game.fen;
      });
      return;
    }
    _playMove(move);
  }

  void _confirmPending() {
    final move = _pendingMove;
    if (move == null) return;
    final stale = _pendingFen != _gameProvider.game.fen || _gameProvider.isGameOver;
    setState(() {
      _pendingMove = null;
      _pendingFen = null;
    });
    if (!stale) _playMove(move);
  }

  void _cancelPending() => setState(() {
        _pendingMove = null;
        _pendingFen = null;
      });

  /// The board with the pending move drawn as an arrow (nothing extra when no move is pending).
  Widget _withPendingMove(GameProvider gp, Widget board) {
    final uci = _pendingMove?.algebraic();
    final showArrow = uci != null && ArrowGeometry.parseUci(uci) != null;
    // Always a Stack, so the board widget keeps its state when an arrow appears or goes away.
    final hint = gp.hintUci;
    final showHint = hint != null && ArrowGeometry.parseUci(hint) != null;
    return Stack(children: [
      board,
      if (showHint)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: MoveArrowPainter(uci: hint, flipped: gp.blackAtBottom, color: const Color(0xCC1E88E5)),
            ),
          ),
        ),
      if (showArrow)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: MoveArrowPainter(uci: uci, flipped: gp.blackAtBottom)),
          ),
        ),
    ]);
  }

  Widget _confirmBar(GameProvider gp) {
    final move = _pendingMove;
    if (move == null) return const SizedBox.shrink();
    // The position changed or the game ended while the move was waiting: drop it.
    if (_pendingFen != gp.game.fen || gp.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pendingMove != null) _cancelPending();
      });
      return const SizedBox.shrink();
    }
    final uci = move.algebraic();
    final label = uci.length >= 4 ? '${uci.substring(0, 2)} → ${uci.substring(2, 4)}' : uci;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _cancelPending, icon: const Icon(Icons.close), label: const Text('Cancel'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton.icon(onPressed: _confirmPending, icon: const Icon(Icons.check), label: Text('Play $label'))),
      ]),
    );
  }

  void _playMove(Move move) async {
    final fenBefore = _gameProvider.game.fen;
    // Make a squared move and set the squares state
    await _gameProvider.makeSquaresMove(move, userId: widget.user.uid!);
    final fenAfter = _gameProvider.game.fen;

    // Check if VS CPU mode is enabled
    if (_gameProvider.vsCPU) {
      // Practice coach: quick look at my move first (about half a second), then the CPU replies.
      await _gameProvider.coachCheckMove(fenBefore, fenAfter);
      _gameProvider.makeStockfishMove();
    } else if (_gameProvider.localMultiplayer) {
      // In local multiplayer, no external notification is needed, we just make the move
      // The makeSquaresMove already handles turn switching and timer updates
    } else if (_gameProvider.isOnlineGame) {
      // For online games, the move is handled by the GameProvider's Firestore update
      // The opponent will receive the update via the stream
      if (_gameProvider.isTrainingGame && _gameProvider.coachEnabled) {
        _trainingCheck(fenBefore, fenAfter);
      }
    }
  }

  /// Handles the user's attempt to pop the screen (e.g., via back button).
  /// Prompts the user to confirm resigning the game with a clear warning about losing.
  Future<bool> _onWillPop() async {
    // Game already over: no extra "Leave Game?" dialog. Back = leave, with at most one ad per game.
    if (_gameProvider.isGameOver) {
      // The game-over dialog is open: back just closes it (it will not leave the screen).
      if (ModalRoute.of(context)?.isCurrent == false) {
        return false;
      }
      return true; // the ad was already shown before the Game Over dialog
    }

    final bool? confirmLeave = await AnimatedDialog.show<bool>(
      context: context,
      title: 'End Game?',
      maxWidth: 400,
      isDestructive: true,
      icon: Icons.flag_rounded,
      child: const ConfirmationDialog(
        message:
            'Quitting will end the game and count as a loss. You will lose rating points and lose the match. Are you sure?',
        confirmButtonText: 'Quit & Lose',
        cancelButtonText: 'Cancel',
        isDestructive: true,
        confirmIcon: Icons.flag_rounded,
      ),
    );

    if (confirmLeave == true) {
      _isLeaving = true; // no Game Over dialog on top of the exit flow
      await _gameProvider.resignGame(
        userId: widget.user.uid,
      ); // Await resignation for online games

      // Same single end-of-game ad as every other way of leaving.
      await _showEndOfGameAdOnce();

      return true;
    }
    return false;
  }

  /// TV icon: two switches (Public / Friends) and a searchable friends list. See LiveWatchSheet.
  Future<void> _showLiveSheet() async {
    final room = _gameProvider.onlineGameRoom;
    final myId = widget.user.uid;
    if (room == null || myId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LiveWatchSheet(room: room, myId: myId),
    );
  }

  void _showResignDialog() async {
    final bool? confirmResign = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Resign Game?',
      maxWidth: 400,
      isDestructive: true,
      icon: Icons.flag_rounded,
      child: const ConfirmationDialog(
        message: 'Are you sure you want to resign?',
        confirmButtonText: 'Resign',
        cancelButtonText: 'Cancel',
        isDestructive: true,
        confirmIcon: Icons.flag_rounded,
      ),
    );

    if (confirmResign == true) {
      await _gameProvider.resignGame(
        userId: widget.user.uid,
      ); // Await resignation for online games
      // show game over dialog after resigning
      //_handleGameOver();
    }
  }

  /// Shows a confirmation dialog for undoing the last move(s)
  void _showUndoConfirmationDialog() async {
    final bool? confirmUndo = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Take Back Move?',
      maxWidth: 400,
      child: const ConfirmationDialog(
        message:
            'Take back your last move?\n(Computer\'s response will also be undone)',
        confirmButtonText: 'Take Back',
        cancelButtonText: 'Cancel',
      ),
    );

    if (confirmUndo == true) {
      final success = await _gameProvider.undoLastMove();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.undo, color: Colors.white),
                SizedBox(width: 12),
                Text('Move taken back'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot take back move'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Shows a confirmation dialog for offering a draw.
  void _showDrawOfferDialog() async {
    if (_gameProvider.localMultiplayer) {
      // For local multiplayer, show a dialog to accept or reject the draw immediately.
      final bool? acceptDraw = await AnimatedDialog.show<bool>(
        context: context,
        title: 'Draw Offer',
        maxWidth: 400,
        child: const ConfirmationDialog(
          message: 'The opponent offers a draw. Do you accept?',
          confirmButtonText: 'Accept',
          cancelButtonText: 'Reject',
        ),
      );
      if (acceptDraw == true) {
        _gameProvider.endGameAsDraw();
      }
    } else {
      // For online games, show a confirmation to send the draw offer.
      final bool? confirmDraw = await AnimatedDialog.show<bool>(
        context: context,
        title: 'Offer Draw?',
        maxWidth: 400,
        child: const ConfirmationDialog(
          message: 'Are you sure you want to offer a draw?',
          confirmButtonText: 'Offer Draw',
          cancelButtonText: 'Cancel',
        ),
      );

      if (confirmDraw == true) {
        await _gameProvider.offerDraw();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the settings provider
    final settingsProvider = context.read<SettingsProvider>();

    return PopScope(
      canPop: false, // Never allow automatic popping
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Text(
                    gameProvider.vsCPU
                        ? 'VS CPU'
                        : gameProvider.localMultiplayer
                        ? 'Local'
                        : 'Online',
                  ),
                ],
              ),
              actions: [
                if (gameProvider.vsCPU || gameProvider.isTrainingGame)
                  IconButton(
                    onPressed: () =>
                        gameProvider.setCoachEnabled(!gameProvider.coachEnabled),
                    icon: Icon(
                      gameProvider.coachEnabled
                          ? Icons.warning_amber_rounded
                          : Icons.warning_amber_outlined,
                      color: gameProvider.coachEnabled ? Colors.amber : null,
                    ),
                    tooltip: gameProvider.coachEnabled
                        ? 'Move warnings: ON'
                        : 'Move warnings: OFF',
                  ),
                IconButton(
                  onPressed: gameProvider.flipTheBoard,
                  icon: const Icon(Icons.flip_rounded),
                  tooltip: 'Flip Board',
                ),
                if (gameProvider.vsCPU)
                  IconButton(
                    onPressed: gameProvider.canUndo
                        ? _showUndoConfirmationDialog
                        : null,
                    icon: Opacity(
                      opacity: gameProvider.canUndo ? 1 : 0.4,
                      child: _assetIcon(
                        AssetsManager.undoButton,
                        30,
                        Icons.undo_rounded,
                      ),
                    ),
                    tooltip: gameProvider.canUndo ? 'Undo move' : 'No move to undo',
                  ),
                if (gameProvider.vsCPU)
                  IconButton(
                    onPressed: !gameProvider.canRequestHint
                        ? null
                        : () => gameProvider.requestAiMoveForCurrentPlayer(),
                    icon: gameProvider.aiMoveRequestedForPlayer
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                        : _assetIcon(
                            AssetsManager.aiThinking,
                            30,
                            Icons.lightbulb_outline_rounded,
                          ),
                    tooltip: gameProvider.aiMoveRequestedForPlayer
                        ? 'Finding the best move...'
                        : 'Show best move hint',
                  ),
                if (!gameProvider.vsCPU)
                  IconButton(
                    onPressed: _showDrawOfferDialog,
                    icon: const Icon(Icons.handshake),
                    tooltip: 'Offer Draw',
                  ),
                if (gameProvider.canOfferTakeback)
                  IconButton(
                    onPressed: _showTakebackOfferDialog,
                    icon: _assetIcon(AssetsManager.undoButton, 30, Icons.undo),
                    tooltip: 'Ask for takeback',
                  ),
                if (gameProvider.canAbortOnline)
                  IconButton(
                    onPressed: _showAbortDialog,
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: 'Abort',
                  )
                else
                  IconButton(
                    onPressed: _showResignDialog,
                    icon: const Icon(Icons.flag),
                    tooltip: 'Resign',
                  ),
                if (gameProvider.isOnlineGame &&
                    gameProvider.onlineGameRoom?.player2Id != null)
                  IconButton(
                    onPressed: () => showReportGameDialog(
                      context,
                      gameProvider.onlineGameRoom!.gameId,
                    ),
                    icon: const Icon(Icons.report_gmailerrorred),
                    tooltip: 'Report opponent',
                  ),
                if (gameProvider.isOnlineGame &&
                    !gameProvider.isGameOver &&
                    gameProvider.onlineGameRoom != null)
                  IconButton(
                    onPressed: _showLiveSheet,
                    icon: Icon(
                      (gameProvider.onlineGameRoom!.publicWatch ||
                              gameProvider.onlineGameRoom!.friendsWatch)
                          ? Icons.live_tv
                          : Icons.live_tv_outlined,
                      color: (gameProvider.onlineGameRoom!.publicWatch ||
                              gameProvider.onlineGameRoom!.friendsWatch)
                          ? Colors.red
                          : null,
                    ),
                    tooltip: 'Live watching',
                  ),
                if (gameProvider.isOnlineGame)
                  Builder(
                    builder: (context) {
                      final gameRoom = gameProvider.onlineGameRoom;
                      if (gameRoom == null) return const SizedBox.shrink();

                      final opponentId = gameRoom.player1Id == widget.user.uid
                          ? gameRoom.player2Id
                          : gameRoom.player1Id;

                      if (opponentId == null) return const SizedBox.shrink();

                      final chatRoomId = gameProvider.chatService.getChatRoomId(
                        widget.user.uid!,
                        opponentId,
                      );

                      return StreamBuilder<int>(
                        stream: gameProvider.chatService.getUnreadMessageCount(
                          chatRoomId,
                          widget.user.uid!,
                        ),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: UnreadBadgeWidget(
                              count: unreadCount,
                              child: GestureDetector(
                                onTap: () =>
                                    _showInGameChat(context, gameProvider),
                                child: Icon(Icons.chat, key: _chatIconKey),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Opponent data, time, and captured pieces
                    if (gameProvider.localMultiplayer)
                      _localMultiplayerOpponentDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else if (gameProvider.isOnlineGame)
                      _onlineOpponentDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else
                      _opponentsDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      ),

                    // Chess board
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _withPendingMove(
                        gameProvider,
                        BoardController(
                        state: gameProvider.flipBoard
                            ? gameProvider.state.board.flipped()
                            : gameProvider.state.board,
                        playState: gameProvider.state.state,
                        pieceSet: settingsProvider.getPieceSet(),
                        theme: settingsProvider.effectiveBoardTheme,
                        animatePieces: settingsProvider.animatePieces,
                        labelConfig: settingsProvider.showLabels
                            ? LabelConfig.standard
                            : LabelConfig.disabled,
                        moves: gameProvider.state.moves,
                        onMove: _onMove,
                        onPremove: _playMove,
                        markerTheme: MarkerTheme(
                          empty: MarkerTheme.dot,
                          piece: MarkerTheme.corners(),
                        ),
                        promotionBehaviour: PromotionBehaviour.autoPremove,
                        ),
                      ),
                    ),
                    _confirmBar(gameProvider),

                    // First move countdown for online games
                    if (gameProvider.isOnlineGame &&
                        gameProvider.onlineGameRoom != null)
                      Center(
                        child: FirstMoveCountdownWidget(
                          isVisible: gameProvider.shouldShowFirstMoveCountdown,
                          playerToMove: gameProvider.firstMoveCountdownPlayer,
                          onTimeout: () {
                            // Handle timeout by calling the GameProvider method
                            final winner =
                                gameProvider.firstMoveCountdownPlayer ==
                                    Squares.white
                                ? Squares.black
                                : Squares.white;
                            gameProvider.handleFirstMoveTimeout(winner: winner);
                          },
                          onTimerTick: () async {
                            // Play timer tick sound during first move countdown
                            await gameProvider.playTimerTickSound();
                          },
                        ),
                      ),

                    // Current user data, time, and captured pieces
                    if (gameProvider.localMultiplayer)
                      _localMultiplayerCurrentUserDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else
                      _currentUserDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      ),
                    // Emoji reactions + per-player counts (players and Live viewers see the same numbers).
                    if (gameProvider.isOnlineGame &&
                        !gameProvider.isGameOver &&
                        gameProvider.onlineGameRoom != null &&
                        gameProvider.onlineGameRoom!.player2Id != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: GameReactionPanel(
                            key: ValueKey(gameProvider.onlineGameRoom!.gameId),
                            room: gameProvider.onlineGameRoom!,
                            myId: widget.user.uid ?? '',
                          ),
                        ),
                      ),
                    // // Display scores for online games
                    // if (gameProvider.isOnlineGame &&
                    //     gameProvider.onlineGameRoom != null)
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 8.0),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceAround,
                    //       children: [
                    //         Text(
                    //           '${gameProvider.onlineGameRoom!.player1DisplayName}: ${gameProvider.player1OnlineScore}',
                    //           style: Theme.of(context).textTheme.titleMedium,
                    //         ),
                    //         Text(
                    //           '${gameProvider.onlineGameRoom!.player2DisplayName ?? 'Opponent'}: ${gameProvider.player2OnlineScore}',
                    //           style: Theme.of(context).textTheme.titleMedium,
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                  ],
                ),
                if (gameProvider.drawOfferReceived)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: DrawOfferWidget(
                      onAccept: () => gameProvider.handleDrawOffer(true),
                      onDecline: () => gameProvider.handleDrawOffer(false),
                    ),
                  ),
                if (gameProvider.takebackReceived && !gameProvider.drawOfferReceived)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: TakebackOfferWidget(
                      onAccept: () => gameProvider.handleTakebackOffer(true),
                      onDecline: () => gameProvider.handleTakebackOffer(false),
                    ),
                  ),
                if (gameProvider.friendRequestReceived)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FriendRequestWidget(
                      onAccept: () => gameProvider.handleFriendRequest(
                        widget.user.uid!,
                        gameProvider.friendRequestSenderId!,
                        true,
                      ),
                      onDecline: () => gameProvider.handleFriendRequest(
                        widget.user.uid!,
                        gameProvider.friendRequestSenderId!,
                        false,
                      ),
                    ),
                  ),
                if (_showRematchOffer && _rematchOffererName != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: RematchOfferWidget(
                      opponentName: _rematchOffererName!,
                      onAccept: _handleRematchAccept,
                      onDecline: _handleRematchDecline,
                    ),
                  ),
                // Training badge + live move warning (never blocks the board).
                if (gameProvider.isTrainingGame || gameProvider.vsCPU)
                  Positioned(
                    top: 4,
                    left: 8,
                    right: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gameProvider.isTrainingGame)
                          IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Training mode: engine warnings ON, game is unrated',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ValueListenableBuilder<CoachWarning?>(
                          valueListenable: gameProvider.coachWarning,
                          builder: (context, warning, _) {
                            if (warning == null) return const SizedBox.shrink();
                            final color = warning.mark == '??'
                                ? Colors.red
                                : warning.mark == '?'
                                    ? Colors.deepOrange
                                    : Colors.amber.shade800;
                            return GestureDetector(
                              onTap: gameProvider.clearCoachWarning,
                              child: Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        warning.text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            bottomNavigationBar:
                MonetizationService.shouldShowAds(context, widget.user)
                ? Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: MonetizationAdsWidget(
                      user: widget.user,
                      adType: MonetizationAdType.banner,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _opponentsDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final int opponentColor = gameProvider.player == Squares.white
        ? Squares.black
        : Squares.white;
    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured = opponentColor == Squares.white
        ? gameProvider.whiteCapturedPieces
        : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      opponentColor,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Opponent profile and info (left side)
              // The computer / a local second player has no country, so no flag.
              ProfileImageWidget(
                imageUrl: null,
                countryCode: null,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: gameProvider.vsCPU
                    ? Icons.computer
                    : Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameProvider.vsCPU
                        ? 'CPU (${['Beginner', 'Easy', 'Normal', 'Hard'][gameProvider.gameLevel]})'
                        : 'Opponent Name',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rating: ${gameProvider.vsCPU ? [400, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!gameProvider.vsCPU)
                  _buildCircularCountdownTimer(
                    duration: gameProvider.player == Squares.white
                        ? gameProvider.blacksTime
                        : gameProvider.whitesTime,
                    initialDuration: gameProvider.player == Squares.white
                        ? gameProvider.savedBlacksTime
                        : gameProvider.savedWhitesTime,
                  ),
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: opponentColor == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onlineOpponentDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final GameRoom? gameRoom = gameProvider.onlineGameRoom;
    if (gameRoom == null) {
      return const SizedBox(); // Should not happen in online game
    }

    final bool isPlayer1 = gameProvider.player == gameRoom.player1Color;
    final String opponentDisplayName = isPlayer1
        ? (gameRoom.player2DisplayName ?? 'Opponent')
        : gameRoom.player1DisplayName;
    final String? opponentPhotoUrl = isPlayer1
        ? gameRoom.player2PhotoUrl
        : gameRoom.player1PhotoUrl;
    final int opponentRating = isPlayer1
        ? (gameRoom.player2Rating ?? 1200)
        : gameRoom.player1Rating;
    final int? opponentColor = isPlayer1
        ? gameRoom.player2Color
        : gameRoom.player1Color;
    final String? opponentId = isPlayer1
        ? gameRoom.player2Id
        : gameRoom.player1Id;
    final String? opponentFlag = isPlayer1
        ? gameRoom.player2Flag
        : gameRoom.player1Flag;

    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured = opponentColor == Squares.white
        ? gameProvider.whiteCapturedPieces
        : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      opponentColor,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Opponent profile and info (left side)
              ProfileImageWidget(
                imageUrl: opponentPhotoUrl,
                countryCode: opponentFlag,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        opponentDisplayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      if (!gameProvider.isOpponentFriend &&
                          !gameProvider.friendRequestReceived)
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: () {
                            showFriendRequestDialog(
                              opponentId: opponentId!,
                              opponentDisplayName: opponentDisplayName,
                            );
                          },
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Rating: $opponentRating',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      _buildOnlineStatusWithLabel(
                        isOnline: gameProvider.isOpponentOnline,
                        label: gameProvider.isOpponentOnline ? 'Online' : 'Offline',
                      ),
                    ],
                  ),
                ],
              ),

              // Audio status indicator (center)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isInAudioRoom) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withAlpha(77),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _assetIcon(AssetsManager.micIcon, 18, Icons.mic),
                            const SizedBox(width: 4),
                            Text(
                              'In Audio',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!gameProvider.vsCPU)
                  _buildCircularCountdownTimer(
                    duration: opponentColor == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                    initialDuration: opponentColor == Squares.white
                        ? gameProvider.savedWhitesTime
                        : gameProvider.savedBlacksTime,
                  ),
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: opponentColor == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showFriendRequestDialog({
    required String opponentId,
    required String opponentDisplayName,
  }) async {
    final friendService = FriendService();
    await AnimatedDialog.show(
      context: context,
      title: 'Send Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            friendService.sendFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: opponentId,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
      child: Text(
        'Send a friend request to $opponentDisplayName',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _currentUserDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isPlayersTurn =
        gameProvider.game.state.turn == gameProvider.player;
    final List<String> playerCaptured = gameProvider.player == Squares.white
        ? gameProvider.whiteCapturedPieces
        : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      gameProvider.player,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // User profile and info (left side)
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        gameProvider.isOnlineGame &&
                                gameProvider.onlineGameRoom != null
                            ? (gameProvider.isHost
                                  ? gameProvider
                                        .onlineGameRoom!
                                        .player1DisplayName
                                  : gameProvider
                                            .onlineGameRoom!
                                            .player2DisplayName ??
                                        widget.user.displayName)
                            : widget.user.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Rating: ${gameProvider.isOnlineGame && gameProvider.onlineGameRoom != null ? (gameProvider.isHost ? gameProvider.onlineGameRoom!.player1Rating : gameProvider.onlineGameRoom!.player2Rating ?? widget.user.classicalRating) : widget.user.classicalRating}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),

              // CPU controls or audio controls (center)
              Expanded(
                child: gameProvider.vsCPU
                    ? _buildVsCpuControls(gameProvider)
                    : Builder(
                        builder: (context) {
                          // NOTE: the old ZegoProvider.isAudioFeatureEnabled
                          // remote toggle is gone along with Firestore. Voice
                          // chat is always considered "enabled" here for now;
                          // add a backend `/admin/game-mode-settings`-style
                          // flag later if you want to be able to turn it off
                          // remotely again.
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (gameProvider.isOnlineGame) ...[
                                if (_isInAudioRoom) ...[
                                  AudioControlsWidget(
                                    isInAudioRoom: _isInAudioRoom,
                                    isMicrophoneEnabled: _isMicrophoneEnabled,
                                    isSpeakerMuted: _isSpeakerMuted,
                                    participants: gameProvider
                                        .getAudioRoomParticipants(),
                                    onToggleMicrophone: _toggleMicrophone,
                                    onToggleSpeaker: _toggleSpeakerMute,
                                    onLeaveAudio: _leaveAudioRoom,
                                  ),
                                ] else ...[
                                  GestureDetector(
                                    onTap: _showAudioRoomInvitationDialog,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withAlpha(77),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: _assetIcon(AssetsManager.micIcon, 26, Icons.mic),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          );
                        },
                      ),
              ),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!gameProvider.vsCPU)
                  _buildCircularCountdownTimer(
                    duration: gameProvider.player == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                    initialDuration: gameProvider.player == Squares.white
                        ? gameProvider.savedWhitesTime
                        : gameProvider.savedBlacksTime,
                  ),
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: playerCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: gameProvider.player == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows an image asset, falling back to a Material icon if it is missing.
  Widget _assetIcon(String path, double size, IconData fallback) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Icon(
        fallback,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildVsCpuControls(GameProvider gameProvider) {
    // CPU hint is now available in the AppBar; keep the lower player row clear.
    return const SizedBox.shrink();
  }

  void _toggleMicrophone() async {
    // Ensure engine is initialized before attempting to control microphone
    if (!_isVoiceEngineInitialized) {
      _gameProvider.logger.w(
        'Attempted to toggle microphone before voice engine initialization',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice chat not initialized. Please try joining the audio room again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if microphone permission is still granted
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      _gameProvider.logger.w('Microphone permission revoked during runtime');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice chat'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Store the current state to revert if operation fails
    final bool previousState = _isMicrophoneEnabled;
    final bool newState = !_isMicrophoneEnabled;

    try {
      // Update UI state optimistically
      setState(() {
        _isMicrophoneEnabled = newState;
      });

      // Apply the change via LiveKit
      await _voiceRoom?.localParticipant?.setMicrophoneEnabled(newState);

      _gameProvider.logger.i(
        newState ? 'Microphone unmuted' : 'Microphone muted',
      );
    } catch (e) {
      // Revert UI state on failure
      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = previousState;
        });
      }

      // Handle the error with user-friendly feedback
      _handleAudioControlFailure(
        '${newState ? 'unmute' : 'mute'} microphone',
        e,
        previousState,
      );
    }
  }

  void _toggleSpeakerMute() async {
    // Ensure engine is initialized before attempting to control speaker
    if (!_isVoiceEngineInitialized) {
      _gameProvider.logger.w(
        'Attempted to toggle speaker before voice engine initialization',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice chat not initialized. Please try joining the audio room again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Store the current state to revert if operation fails
    final bool previousState = _isSpeakerMuted;
    final bool newState = !_isSpeakerMuted;

    try {
      // Update UI state optimistically
      setState(() {
        _isSpeakerMuted = newState;
      });

      // Apply the change via LiveKit (mutes what WE hear from the opponent,
      // not our own outgoing mic)
      await _setRemoteAudioMuted(newState);

      _gameProvider.logger.i(newState ? 'Speaker muted' : 'Speaker unmuted');
    } catch (e) {
      // Revert UI state on failure
      if (mounted) {
        setState(() {
          _isSpeakerMuted = previousState;
        });
      }

      // Handle the error with user-friendly feedback
      _handleAudioControlFailure(
        '${newState ? 'mute' : 'unmute'} speaker',
        e,
        previousState,
      );
    }
  }

  // 5. LiveKit room initialization (replaces voice engine init)
  Future<void> _initializeVoiceEngine() async {
    if (_isVoiceEngineInitialized) return;

    // Check microphone permission before joining the LiveKit room
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      throw Exception('Microphone permission is required for voice chat');
    }

    try {
      _gameProvider.logger.i('Starting LiveKit room initialization...');

      final roomID =
          _gameProvider.onlineGameRoom?.gameId ??
          'room_${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: get a signed access token from our own backend (never talk
      // to LiveKit's control plane directly from the app).
      final credentials = await LiveKitTokenService().getToken(roomID);

      // Step 2: create and connect to the room.
      final room = lk.Room();
      _voiceRoom = room;
      _setupVoiceRoomEventListeners();

      await room.connect(
        credentials.url,
        credentials.token,
        roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _gameProvider.logger.i('Successfully joined LiveKit room: $roomID');

      // Step 3: publish our microphone.
      await room.localParticipant?.setMicrophoneEnabled(true);
      _gameProvider.logger.i('Started publishing microphone audio');

      _isVoiceEngineInitialized = true;
      _currentAudioRoomId = roomID;

      // Initialize audio states to default values
      await _initializeAudioStates();

      // Sync audio states to ensure consistency
      await _syncAudioStates();

      _gameProvider.logger.i(
        'LiveKit room initialization completed successfully',
      );
    } catch (e) {
      _gameProvider.logger.e('Failed to initialize LiveKit room: $e');

      // Cleanup on failure
      try {
        await _cleanupVoiceEngineOnFailure();
      } catch (cleanupError) {
        _gameProvider.logger.e(
          'Error during cleanup after initialization failure: $cleanupError',
        );
      }

      _isVoiceEngineInitialized = false;
      _currentAudioRoomId = null;

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize voice chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      rethrow;
    }
  }

  Future<void> _initializeVoiceEngineIfNeeded() async {
    if (!_isVoiceEngineInitialized) {
      try {
        await _initializeVoiceEngine();
      } catch (e) {
        _gameProvider.logger.e(
          'Failed to initialize voice engine when needed: $e',
        );
        throw Exception('Voice chat initialization failed. Please try again.');
      }
    }
  }

  /// Initialize audio states to ensure UI reflects LiveKit state
  Future<void> _initializeAudioStates() async {
    try {
      // Microphone starts enabled (already published in _initializeVoiceEngine)
      // Speaker (hearing the opponent) starts unmuted — nothing to do on
      // the LiveKit side since remote audio tracks auto-play once subscribed.
      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = true; // Microphone starts enabled
          _isSpeakerMuted = false; // Speaker starts unmuted
        });
      }

      _gameProvider.logger.i(
        'Audio states initialized: mic=unmuted, speaker=unmuted',
      );
    } catch (e) {
      _gameProvider.logger.w('Failed to initialize audio states: $e');
      // Don't throw error as this is not critical for engine initialization
    }
  }

  /// Synchronize UI state with LiveKit audio state.
  Future<void> _syncAudioStates() async {
    if (!_isVoiceEngineInitialized) {
      _gameProvider.logger.w(
        'Cannot sync audio states: voice engine not initialized',
      );
      return;
    }

    try {
      _gameProvider.logger.i(
        'Audio states synced: mic=${_isMicrophoneEnabled ? 'enabled' : 'disabled'}, '
        'speaker=${_isSpeakerMuted ? 'muted' : 'unmuted'}',
      );
    } catch (e) {
      _gameProvider.logger.w('Failed to sync audio states: $e');
    }
  }

  /// Handle audio control failures with appropriate user feedback and recovery
  void _handleAudioControlFailure(
    String operation,
    dynamic error,
    bool revertToState,
  ) {
    _gameProvider.logger.e('Audio control failure - $operation: $error');

    if (mounted) {
      // Show user-friendly error message
      String userMessage;
      if (error.toString().contains('permission')) {
        userMessage = 'Microphone permission required for voice chat';
      } else if (error.toString().contains('network') ||
          error.toString().contains('connection')) {
        userMessage =
            'Network error. Please check your connection and try again';
      } else if (error.toString().contains('engine') ||
          error.toString().contains('initialize')) {
        userMessage =
            'Voice chat not ready. Please try rejoining the audio room';
      } else {
        userMessage = 'Failed to $operation. Please try again';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(userMessage)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              // Provide retry option for critical operations
              if (operation.contains('microphone')) {
                _toggleMicrophone();
              } else if (operation.contains('speaker')) {
                _toggleSpeakerMute();
              }
            },
          ),
        ),
      );
    }
  }

  /// Sets up LiveKit room event listeners. Unlike ZegoCloud, LiveKit
  /// auto-subscribes to remote participants' published audio tracks by
  /// default (see RoomOptions above), so there's no manual
  /// startPlayingStream/stopPlayingStream step needed — audio just plays
  /// once a remote track is subscribed. We only log join/leave here.
  void _setupVoiceRoomEventListeners() {
    final room = _voiceRoom;
    if (room == null) return;

    final listener = room.createListener();
    listener
      ..on<lk.ParticipantConnectedEvent>((event) {
        _gameProvider.logger.i(
          'Opponent joined voice room: ${event.participant.identity}',
        );
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        _gameProvider.logger.i(
          'Opponent left voice room: ${event.participant.identity}',
        );
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        _gameProvider.logger.i(
          'Subscribed to remote audio track from ${event.participant.identity}',
        );
      });
  }

  /// Mutes/unmutes everyone else's audio for us locally (does not affect
  /// what they hear). Applied to every currently-subscribed remote audio
  /// track, and to any new one via the volume set at subscribe time.
  Future<void> _setRemoteAudioMuted(bool muted) async {
    final room = _voiceRoom;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (track is lk.RemoteAudioTrack) {
          track.mediaStreamTrack.enabled = !muted;
        }
      }
    }
  }

  Future<void> _cleanupVoiceEngine() async {
    try {
      if (_isVoiceEngineInitialized) {
        _gameProvider.logger.i('Starting LiveKit room cleanup...');

        try {
          await _voiceRoom?.disconnect();
          _gameProvider.logger.i('Successfully disconnected from LiveKit room');
        } catch (e) {
          _gameProvider.logger.w('Error disconnecting from room: $e');
        }

        _voiceRoom = null;
        _isVoiceEngineInitialized = false;
        _currentAudioRoomId = null;

        _gameProvider.logger.i('LiveKit room cleanup completed');
      }
    } catch (e) {
      _gameProvider.logger.e('Error during LiveKit cleanup: $e');

      // Force reset state even if cleanup failed
      _isVoiceEngineInitialized = false;
      _currentAudioRoomId = null;
      _voiceRoom = null;
    }
  }

  Future<void> _cleanupVoiceEngineOnFailure() async {
    try {
      await _voiceRoom?.disconnect();
    } catch (e) {
      _gameProvider.logger.w('Error during failure cleanup: $e');
    }
    _voiceRoom = null;
  }

  Future<void> _leaveAudioRoom() async {
    try {
      if (_gameProvider.isOnlineGame) {
        // End the audio room for all participants instead of just leaving
        await _gameProvider.endAudioRoom(widget.user.uid!);
      }

      await _cleanupVoiceEngine();

      if (!mounted) return;
      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room ended'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving audio room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAudioRoomInvitationDialog() {
    if (!_gameProvider.isOnlineGame) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room is only available in online games'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AnimatedDialog.show(
      context: context,
      title: 'Start Audio Room?',
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _assetIcon(AssetsManager.micIcon, 64, Icons.mic),
          const SizedBox(height: 16),
          const Text(
            'Invite your opponent to voice chat',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your opponent will receive an invitation to join the audio room.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _sendAudioRoomInvitation();
          },
          child: const Text('Invite'),
        ),
      ],
    );
  }

  Future<void> _sendAudioRoomInvitation() async {
    // Check microphone permission first
    final permissionService = PermissionService();
    final permissionResult = await permissionService
        .requestMicrophonePermission(context);

    if (permissionResult == PermissionResult.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice chat'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else if (permissionResult == PermissionResult.permanentlyDenied) {
      await permissionService.handlePermanentlyDeniedPermission(
        context,
        'Microphone',
      );
      return;
    }

    // Check if user has access first
    if (!_hasAudioAccess()) {
      final result = await AudioAccessDialog.show(context: context);

      if (result == AudioAccessAction.watchAd) {
        _hasTemporaryAudioAccess = true;
      } else if (result == AudioAccessAction.premium) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit Profile screen to upgrade to Premium'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } else {
        return; // User cancelled
      }
    }

    try {
      await _gameProvider.inviteToAudioRoom(widget.user.uid!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room invitation sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _localMultiplayerOpponentDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isOpponentWhite = gameProvider.player == Squares.black;
    final bool isOpponentsTurn =
        gameProvider.game.state.turn ==
        (isOpponentWhite ? Squares.white : Squares.black);
    final List<String> opponentCaptured = isOpponentWhite
        ? gameProvider.whiteCapturedPieces
        : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      isOpponentWhite ? Squares.white : Squares.black,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Opponent profile and info (left side)
              // The computer / a local second player has no country, so no flag.
              ProfileImageWidget(
                imageUrl: null,
                countryCode: null,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: gameProvider.vsCPU
                    ? Icons.computer
                    : Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpponentWhite ? 'P1 (White)' : 'P2 (Black)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rating: ${gameProvider.vsCPU ? [400, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!gameProvider.vsCPU)
                  _buildCircularCountdownTimer(
                    duration: gameProvider.player == Squares.white
                        ? gameProvider.blacksTime
                        : gameProvider.whitesTime,
                    initialDuration: gameProvider.player == Squares.white
                        ? gameProvider.savedBlacksTime
                        : gameProvider.savedWhitesTime,
                  ),
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: isOpponentWhite,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _localMultiplayerCurrentUserDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isPlayerWhite = gameProvider.player == Squares.white;
    final bool isPlayersTurn =
        gameProvider.game.state.turn ==
        (isPlayerWhite ? Squares.white : Squares.black);
    final List<String> playerCaptured = isPlayerWhite
        ? gameProvider.whiteCapturedPieces
        : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      gameProvider.player,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              // User profile and info (left side)
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    isPlayerWhite ? 'P1 (White)' : 'P2 (Black)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!gameProvider.vsCPU)
                  _buildCircularCountdownTimer(
                    duration: gameProvider.player == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                    initialDuration: gameProvider.player == Squares.white
                        ? gameProvider.savedWhitesTime
                        : gameProvider.savedBlacksTime,
                  ),
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: playerCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: gameProvider.player == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInGameChat(BuildContext context, GameProvider gameProvider) {
    final opponent = gameProvider.onlineGameRoom?.player1Id == widget.user.uid
        ? ChessUser(
            uid: gameProvider.onlineGameRoom?.player2Id,
            displayName:
                gameProvider.onlineGameRoom?.player2DisplayName ?? 'Opponent',
            photoUrl: gameProvider.onlineGameRoom?.player2PhotoUrl,
          )
        : ChessUser(
            uid: gameProvider.onlineGameRoom?.player1Id,
            displayName:
                gameProvider.onlineGameRoom?.player1DisplayName ?? 'Opponent',
            photoUrl: gameProvider.onlineGameRoom?.player1PhotoUrl,
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ChatScreen(
            currentUser: widget.user,
            otherUser: opponent,
            showInvite: false,
          ),
        );
      },
    );
  }

  /// Build a circular progress countdown timer widget
  /// Shows progress across the full game time, not just the last 10 seconds
  /// Sound plays from 10 seconds onwards (handled by GameProvider)
  Widget _buildCircularCountdownTimer({
    required Duration duration,
    required Duration initialDuration,
  }) {
    final remainingSeconds = duration.inSeconds.toDouble();
    final initialSeconds = initialDuration.inSeconds.toDouble();
    final progress = initialSeconds > 0
        ? remainingSeconds / initialSeconds
        : 0.0;

    // Format time as m:ss
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final formattedTime = '$minutes:${seconds.toString().padLeft(2, '0')}';

    // Determine color: red when <= 2 seconds, orange when <= 10 seconds, blue otherwise
    final isVeryLow = remainingSeconds <= 2;
    final isLow = remainingSeconds <= 10;

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.red.withAlpha(76),
              valueColor: AlwaysStoppedAnimation<Color>(
                isVeryLow ? Colors.red : (isLow ? Colors.orange : Colors.blue),
              ),
            ),
          ),
          // Timer text in center
          Text(
            formattedTime,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: 'monospace',
              color: isVeryLow
                  ? Colors.red
                  : (isLow ? Colors.orange : Colors.blue),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated dots indicator for AI thinking
class AnimatedDotsIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedDotsIndicator({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  State<AnimatedDotsIndicator> createState() => _AnimatedDotsIndicatorState();
}

class _AnimatedDotsIndicatorState extends State<AnimatedDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Calculate delay for each dot
            final delay = index * 0.25;
            final adjustedValue = (_controller.value + delay) % 1.0;

            // Create a wave effect: scale from 0.6 to 1.2
            final scale = 0.6 + (adjustedValue.abs() - 0.5).abs() * 1.2;

            // Fade in/out effect
            final opacity = 0.5 + (adjustedValue.abs() - 0.5).abs() * 0.5;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

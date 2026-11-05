import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/widgets/floating_message_button.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/reaction_widgets.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;

/// Read-only live view of a game. Open to everyone while the players have public Live ON, and to
/// invited friends always; if public Live is switched OFF, viewers who were not invited are sent back out. Viewers can send emoji reactions.
class SpectatorScreen extends StatefulWidget {
  final String gameId;

  const SpectatorScreen({super.key, required this.gameId});

  @override
  State<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends State<SpectatorScreen> {
  final _socketService = GameSocketService();
  StreamSubscription<Map<String, dynamic>>? _roomSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;
  GameRoom? _room;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    FloatingMessageController.hide();
    _start();
  }

  Future<void> _start() async {
    try {
      await _socketService.connect();
    } catch (_) {
      _close('Could not connect. Please try again.');
      return;
    }
    if (!mounted) return;
    _endedSub = _socketService.onSpectateEnded.where((d) => d['gameId'] == widget.gameId).listen((d) {
      _close(d['reason'] == 'live_off'
          ? 'The players turned public Live off.'
          : 'You can no longer watch this game.');
    });
    _roomSub = _socketService.spectateGame(widget.gameId).listen((data) {
      final raw = data['room'];
      if (raw is! Map || !mounted) return;
      final room = GameRoom.fromSocketJson(Map<String, dynamic>.from(raw));
      if (room.gameId != widget.gameId) return; // an update for some other game
      setState(() => _room = room);
    });
  }

  void _close(String message) {
    if (_closing || !mounted) return;
    _closing = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _endedSub?.cancel();
    _socketService.leaveSpectate(widget.gameId);
    FloatingMessageController.show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return _SpectatorView(gameRoom: room);
  }
}

class _SpectatorView extends StatefulWidget {
  final GameRoom gameRoom;

  const _SpectatorView({required this.gameRoom});

  @override
  State<_SpectatorView> createState() => _SpectatorViewState();
}

class _SpectatorViewState extends State<_SpectatorView> {
  late SquaresState _state = _stateFor(widget.gameRoom.fen);

  SquaresState _stateFor(String fen) => bishop.Game(fen: fen).squaresState(Squares.white);

  @override
  void didUpdateWidget(covariant _SpectatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameRoom.fen != oldWidget.gameRoom.fen) {
      setState(() => _state = _stateFor(widget.gameRoom.fen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final myId = context.read<UserProvider>().user?.uid ?? '';
    final room = widget.gameRoom;
    final over = room.status != 'active';

    // Black on top, white at the bottom (the board is drawn from White's side).
    final p1IsWhite = room.player1Color == Squares.white;
    Widget p1(int ms) => _buildPlayerInfo(context, room.player1DisplayName, room.player1PhotoUrl, room.player1Rating, ms, gameProvider);
    Widget p2(int ms) => _buildPlayerInfo(context, room.player2DisplayName ?? 'Opponent', room.player2PhotoUrl, room.player2Rating ?? 1200, ms, gameProvider);
    final white = p1IsWhite ? p1(room.whitesTimeRemaining) : p2(room.whitesTimeRemaining);
    final black = p1IsWhite ? p2(room.blacksTimeRemaining) : p1(room.blacksTimeRemaining);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: WatchingCountBadge(gameId: room.gameId)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            black,
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: BoardController(
                state: _state.board,
                playState: PlayState.theirTurn,
                pieceSet: settingsProvider.getPieceSet(),
                theme: settingsProvider.effectiveBoardTheme,
              ),
            ),
            white,
            if (over)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Game over${room.endReason != null ? ' · ${room.endReason}' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            else
              GameReactionPanel(room: room, myId: myId, isSpectator: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(BuildContext context, String name, String? photoUrl, int rating, int ms, GameProvider gameProvider) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ProfileImageWidget(imageUrl: photoUrl, radius: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text('Rating: $rating', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gameProvider.getFormattedTime(Duration(milliseconds: ms)),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

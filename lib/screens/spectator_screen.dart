import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;

class SpectatorScreen extends StatelessWidget {
  final String gameId;

  const SpectatorScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final socketService = GameSocketService();
    return FutureBuilder<void>(
      future: socketService.connect(),
      builder: (context, connectSnapshot) {
        if (connectSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamProvider<GameRoom?>.value(
          value: socketService.spectateGame(gameId).map(
                (data) => GameRoom.fromSocketJson(
                  Map<String, dynamic>.from(data['room']),
                ),
              ),
          initialData: null,
          child: Consumer<GameRoom?>(
            builder: (context, gameRoom, _) {
              if (gameRoom == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return _SpectatorView(gameRoom: gameRoom);
            },
          ),
        );
      },
    );
  }
}

class _SpectatorView extends StatefulWidget {
  final GameRoom gameRoom;

  const _SpectatorView({required this.gameRoom});

  @override
  State<_SpectatorView> createState() => _SpectatorViewState();
}

class _SpectatorViewState extends State<_SpectatorView> {
  late bishop.Game _game;
  late SquaresState _state = SquaresState.initial(0);

  @override
  void initState() {
    super.initState();
    _game = bishop.Game(fen: widget.gameRoom.fen);
  }

  @override
  void didUpdateWidget(covariant _SpectatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameRoom.fen != oldWidget.gameRoom.fen) {
      setState(() {
        _game = bishop.Game(fen: widget.gameRoom.fen);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Spectator Mode')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPlayerInfo(
            context,
            widget.gameRoom.player1DisplayName,
            widget.gameRoom.player1PhotoUrl,
            widget.gameRoom.player1Rating,
            widget.gameRoom.player1Color,
            Duration(milliseconds: widget.gameRoom.whitesTimeRemaining),
            gameProvider,
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: BoardController(
              state: _state.board,
              playState: PlayState.theirTurn,
              pieceSet: settingsProvider.getPieceSet(),
              theme: settingsProvider.boardTheme,
            ),
          ),
          _buildPlayerInfo(
            context,
            widget.gameRoom.player2DisplayName ?? 'Opponent',
            widget.gameRoom.player2PhotoUrl,
            widget.gameRoom.player2Rating ?? 1200,
            widget.gameRoom.player2Color!,
            Duration(milliseconds: widget.gameRoom.blacksTimeRemaining),
            gameProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(
    BuildContext context,
    String name,
    String? photoUrl,
    int rating,
    int color,
    Duration time,
    GameProvider gameProvider,
  ) {
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
                Text(
                  'Rating: $rating',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
              gameProvider.getFormattedTime(time),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/screens/game_replay_screen.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:intl/intl.dart';

class SavedGamesScreen extends StatefulWidget {
  final ChessUser user;

  const SavedGamesScreen({super.key, required this.user});

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  final SavedGameService _savedGameService = SavedGameService();
  final FriendService _friendService = FriendService();
  late Future<List<SavedGame>> _savedGamesFuture;

  @override
  void initState() {
    super.initState();
    _savedGamesFuture = _savedGameService.getSavedGamesForUser(
      widget.user.uid!,
    );
  }

  // show firendRequest Dialog
  void showFriendRequestDialog({
    required String opponentId,
    required String opponentDisplayName,
  }) async {
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
            _friendService.sendFriendRequest(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Games')),
      body: FutureBuilder<List<SavedGame>>(
        future: _savedGamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no saved games.'));
          } else {
            final savedGames = snapshot.data!;
            return ListView.builder(
              itemCount: savedGames.length,
              itemBuilder: (context, index) {
                final game = savedGames[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      'vs. ${game.opponentDisplayName} (${game.gameMode})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Result: ${game.result.toUpperCase()}'),
                        Text(
                          'Date: ${DateFormat('MMM d, yyyy HH:mm').format(game.createdAt)}',
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (game.opponentId.isNotEmpty &&
                            game.opponentId != 'stockfish_ai' &&
                            game.opponentId != 'local_player')
                          FutureBuilder<bool>(
                            future: _friendService.isFriend(
                              widget.user.uid!,
                              game.opponentId,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              final isFriend = snapshot.data ?? false;
                              if (!isFriend) {
                                return IconButton(
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () {
                                    showFriendRequestDialog(
                                      opponentId: game.opponentId,
                                      opponentDisplayName:
                                          game.opponentDisplayName,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Friend request sent to ${game.opponentDisplayName}!',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        _buildResultIcon(game.result),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameReplayScreen(game: game),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildResultIcon(String result) {
    IconData icon;
    Color color;
    switch (result) {
      case Constants.win:
        icon = Icons.emoji_events;
        color = Colors.green;
        break;
      case Constants.loss:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case Constants.draw:
        icon = Icons.handshake;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Icon(icon, color: color);
  }
}

import 'dart:async';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/game_provider.dart' as bishop;

import 'package:provider/provider.dart';

enum GameOverAction { rematch, newGame, none }

class GameOverDialog extends StatefulWidget {
  final bishop.GameResult? result;
  final ChessUser user;
  final int playerColor;
  final bool isOnlineGame;

  const GameOverDialog({
    super.key,
    required this.result,
    required this.user,
    required this.playerColor,
    this.isOnlineGame = false,
  });

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> {
  String? _rematchStatus; // e.g., 'waiting', 'rejected'
  bool _rematchStatusIsError = false; // Track if status is an error message
  Timer? _statusClearTimer;
  late GameProvider gameProvider;
  bool _buttonsEnabled = false;
  Timer? _enableButtonsTimer;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();

    // Enable buttons after 2 seconds
    _enableButtonsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _buttonsEnabled = true;
        });
      }
    });

    // Listen to game provider changes to update dialog state
    gameProvider.addListener(_onGameProviderUpdate);
  }

  void _onGameProviderUpdate() {
    // Force rebuild when game provider changes (e.g., when rematch is cancelled/rejected)
    if (mounted) {
      gameProvider.logger.i(
        'DIALOG: _onGameProviderUpdate called - forcing rebuild. RematchOfferedBy: ${gameProvider.onlineGameRoom?.rematchOfferedBy}',
      );
      setState(() {});
    }
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onGameProviderUpdate);
    _statusClearTimer?.cancel();
    _enableButtonsTimer?.cancel();
    super.dispose();
  }

  String _getResultText(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final onlineGameRoom = gameProvider.onlineGameRoom;

    if (widget.result == null) return 'Game Over';

    if (widget.result is bishop.WonGame) {
      final winner = (widget.result as bishop.WonGame).winner;
      String winnerName = '';
      if (onlineGameRoom != null) {
        if (onlineGameRoom.player1Color == winner) {
          winnerName = onlineGameRoom.player1DisplayName;
        } else if (onlineGameRoom.player2Color == winner) {
          winnerName = onlineGameRoom.player2DisplayName ?? 'Opponent';
        }
      } else {
        winnerName = (winner == widget.playerColor) ? 'You' : 'Opponent';
      }

      String winType = '';
      if (widget.result is bishop.WonGameCheckmate) {
        winType = 'by Checkmate';
      } else if (widget.result is bishop.WonGameTimeout) {
        winType = 'by Timeout';
      } else if (widget.result is bishop.WonGameResignation) {
        winType = 'by Resignation';
      } else if (widget.result is bishop.WonGameAborted) {
        return 'Game Aborted';
      } else if (widget.result is bishop.WonGameElimination) {
        winType = 'by Elimination';
      } else if (widget.result is bishop.WonGameStalemate) {
        winType = 'by Stalemate (opponent won)';
      } else if (widget.result is bishop.WonGameCheckLimit) {
        winType = 'by Check Limit';
      }

      return '$winnerName Won $winType!';
    } else if (widget.result is bishop.DrawnGame) {
      String drawType = '';
      if (widget.result is bishop.DrawnGameInsufficientMaterial) {
        drawType = 'Insufficient Material';
      } else if (widget.result is bishop.DrawnGameRepetition) {
        drawType = 'Threefold Repetition';
      } else if (widget.result is bishop.DrawnGameLength) {
        drawType = '50-Move Rule';
      } else if (widget.result is bishop.DrawnGameStalemate) {
        drawType = 'Stalemate';
      } else if (widget.result is bishop.DrawnGameElimination) {
        drawType = 'by Elimination';
      } else if (widget.result is DrawnGameAgreement) {
        drawType = 'by Agreement';
      }
      return 'Game Drawn ($drawType)';
    }
    return 'Game Over';
  }

  void _showRematchStatus(String status, {bool isError = false}) {
    setState(() {
      _rematchStatus = status;
      _rematchStatusIsError = isError;
    });
    _statusClearTimer?.cancel();
    _statusClearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _rematchStatus = null;
          _rematchStatusIsError = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final onlineGameRoom = gameProvider.onlineGameRoom;

        // DIALOG DEBUG: Log when dialog rebuilds and game state
        gameProvider.logger.i(
          'DIALOG DEBUG: Dialog rebuilding - gameResult: ${gameProvider.gameResult}, isGameOver: ${gameProvider.isGameOver}, rematchOfferedBy: ${onlineGameRoom?.rematchOfferedBy}',
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getResultText(context),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onlineGameRoom != null)
              _buildOnlinePlayerData(context, gameProvider)
            else
              _buildLocalPlayerData(context, widget.user),
            const SizedBox(height: 24),
            if (onlineGameRoom != null)
              _buildRematchSection(context, gameProvider, onlineGameRoom)
            else
              _buildLocalRematchButtons(context, gameProvider),
          ],
        );
      },
    );
  }

  Widget _buildRematchSection(
    BuildContext context,
    GameProvider gameProvider,
    GameRoom onlineGameRoom,
  ) {
    final currentUserId = widget.user.uid;
    final rematchOfferedBy = onlineGameRoom.rematchOfferedBy;

    // Debug logging
    gameProvider.logger.i(
      'DIALOG: Building rematch section - rematchOfferedBy: $rematchOfferedBy, currentUserId: $currentUserId, buttonsEnabled: $_buttonsEnabled',
    );

    // Case 1: A rematch offer is active
    if (rematchOfferedBy != null) {
      // Subcase 1.1: The current user sent the offer
      if (rematchOfferedBy == currentUserId) {
        return Column(
          children: [
            const Text('Waiting for opponent...'),
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _buttonsEnabled
                  ? () async {
                      print('=== CANCEL BUTTON TAPPED ===');
                      gameProvider.logger.i('DIALOG: Cancel button pressed');
                      setState(() {
                        _buttonsEnabled = false; // Disable during processing
                      });
                      final error = await gameProvider.handleRematch(false);
                      gameProvider.logger.i(
                        'DIALOG: After handleRematch(false) - rematchOfferedBy should be null',
                      );
                      if (mounted) {
                        if (error != null) {
                          _showRematchStatus(error, isError: true);
                        } else {
                          _showRematchStatus('Rematch offer cancelled');
                        }
                        setState(() {
                          _buttonsEnabled = true;
                        });
                      }
                    }
                  : null,
              child: const Text('Cancel Rematch Offer'),
            ),
          ],
        );
      }
      // Subcase 1.2: The opponent sent the offer
      else {
        return Column(
          children: [
            Text(
              '${onlineGameRoom.player1Id == rematchOfferedBy ? onlineGameRoom.player1DisplayName : onlineGameRoom.player2DisplayName ?? 'Opponent'} wants a rematch!',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _buttonsEnabled
                      ? () async {
                          final error = await gameProvider.handleRematch(true);
                          if (mounted) {
                            if (error != null) {
                              _showRematchStatus(error, isError: true);
                            } else {
                              // Rematch accepted successfully, close dialog
                              Navigator.of(context).pop(GameOverAction.rematch);
                            }
                          }
                        }
                      : null,
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: _buttonsEnabled
                      ? () async {
                          print('=== DECLINE BUTTON TAPPED ===');
                          gameProvider.logger.i(
                            'DIALOG: Decline button pressed',
                          );
                          setState(() {
                            _buttonsEnabled =
                                false; // Disable during processing
                          });
                          final error = await gameProvider.handleRematch(false);
                          gameProvider.logger.i(
                            'DIALOG: After handleRematch(false) - rematchOfferedBy should be null',
                          );
                          if (mounted) {
                            if (error != null) {
                              _showRematchStatus(error, isError: true);
                            } else {
                              _showRematchStatus('Rematch rejected');
                            }
                            setState(() {
                              _buttonsEnabled = true;
                            });
                          }
                        }
                      : null,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        );
      }
    }
    // Case 2: No active rematch offer
    else {
      // Check if the current user has already sent a rematch offer
      final hasUserSentRematch = gameProvider.rematchOfferSent;

      return Column(
        children: [
          if (_rematchStatus != null) ...[
            Text(
              _rematchStatus!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _rematchStatusIsError ? Colors.red : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: ElevatedButton(
                  onPressed: (_buttonsEnabled && !hasUserSentRematch)
                      ? () async {
                          final error = await gameProvider.offerRematch();
                          if (mounted && error != null) {
                            _showRematchStatus(error, isError: true);
                          }
                        }
                      : null,
                  child: hasUserSentRematch
                      ? const Text('Rematch Requested')
                      : const Text('Rematch'),
                ),
              ),

              // TODO: Add rewarded ad requirement for rematch when user base grows
              // Currently disabled to encourage rematch requests during early growth phase
              const SizedBox(width: 4),
              Flexible(
                child: OutlinedButton(
                  onPressed: _buttonsEnabled
                      ? () => Navigator.of(context).pop(GameOverAction.newGame)
                      : null,
                  child: const Text('New Game'),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildLocalRematchButtons(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Flexible(
          child: ElevatedButton(
            onPressed: _buttonsEnabled
                ? () {
                    gameProvider.resetGame(true);
                    Navigator.of(context).pop(GameOverAction.rematch);
                  }
                : null,
            child: const Text('Rematch', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: OutlinedButton(
            onPressed: _buttonsEnabled
                ? () {
                    Navigator.of(context).pop(GameOverAction.newGame);
                  }
                : null,
            child: const Text('New Game', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalPlayerData(BuildContext context, ChessUser user) {
    return Column(
      children: [
        Text(
          'Your Rating: ${user.classicalRating}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildOnlinePlayerData(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    final onlineGameRoom = gameProvider.onlineGameRoom!;
    final bool isHost = gameProvider.isHost;

    // final String player1Name = onlineGameRoom.player1DisplayName;
    // final String player2Name = onlineGameRoom.player2DisplayName ?? 'Opponent';

    // final int player1Score = onlineGameRoom.player1Score;
    // final int player2Score = onlineGameRoom.player2Score;

    return Text(
      isHost
          ? 'Your Rating: ${onlineGameRoom.player1Rating}'
          : 'Your Rating: ${onlineGameRoom.player2Rating ?? widget.user.classicalRating}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

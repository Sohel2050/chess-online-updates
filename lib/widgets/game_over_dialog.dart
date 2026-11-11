import 'package:flutter_chess_app/utils/debug_log.dart';
import 'dart:async';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/game_provider.dart' as bishop;

import 'package:flutter_chess_app/screens/game_replay_screen.dart';
import 'package:flutter_chess_app/widgets/report_game_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
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
    if (!mounted) return;
    final err = gameProvider.rematchError;
    if (err != null) {
      gameProvider.clearRematchError();
      _showRematchStatus(err, isError: true); // also rebuilds
      return;
    }
    setState(() {});
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
        final myColor = gameProvider.isHost
            ? onlineGameRoom.player1Color
            : onlineGameRoom.player2Color;
        if (myColor == winner) {
          winnerName = 'You';
        } else if (onlineGameRoom.player1Color == winner) {
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

  /// 1 = you won, -1 = you lost, 0 = draw, null = unknown / aborted.
  int? _outcomeForMe(GameProvider gameProvider) {
    final result = widget.result;
    if (result == null) return null;
    if (result is bishop.WonGameAborted) return null;
    if (result is bishop.DrawnGame) return 0;
    if (result is bishop.WonGame) {
      final room = gameProvider.onlineGameRoom;
      final int? myColor = room != null
          ? (gameProvider.isHost ? room.player1Color : room.player2Color)
          : widget.playerColor;
      if (myColor == null) return null;
      return result.winner == myColor ? 1 : -1;
    }
    return null;
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

  bool _openingReview = false;

  /// Opens this game's move-by-move replay (the server saves it when the game ends).
  Future<void> _openReview(String roomId) async {
    if (_openingReview) return;
    setState(() => _openingReview = true);
    // 1) The game that was just played is still on the board: open it straight away,
    //    no waiting for the server to finish saving it.
    SavedGame? game = gameProvider.buildReviewSnapshot();
    // 2) Otherwise fall back to the server's saved copy (it retries for a few seconds).
    game ??= await SavedGameService().getSavedGameByRoomId(roomId);
    if (!mounted) return;
    setState(() => _openingReview = false);
    if (game == null) {
      _showRematchStatus(
        'Review is not ready yet. Try again in a moment, or open it from Settings > Saved games.',
        isError: true,
      );
      return;
    }
    final SavedGame reviewGame = game;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameReplayScreen(game: reviewGame)),
    );
  }


  bool get _isAborted => widget.result is bishop.WonGameAborted;

  ({List<Color> colors, IconData icon, String headline, String sub}) _look(
    BuildContext context,
    GameProvider gp,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (_isAborted) {
      return (
        colors: [const Color(0xFF607D8B), const Color(0xFF37474F)],
        icon: Icons.block_rounded,
        headline: 'Game Aborted',
        sub: 'No rating change',
      );
    }
    final sub = _getResultText(context);
    switch (_outcomeForMe(gp)) {
      case 1:
        return (
          colors: [const Color(0xFFFFB300), const Color(0xFFEF6C00)],
          icon: Icons.emoji_events_rounded,
          headline: 'Victory!',
          sub: sub,
        );
      case -1:
        return (
          colors: [const Color(0xFFE53935), const Color(0xFF7F1D1D)],
          icon: Icons.heart_broken_rounded,
          headline: 'Defeat',
          sub: sub,
        );
      case 0:
        return (
          colors: [const Color(0xFF607D8B), const Color(0xFF37474F)],
          icon: Icons.handshake_rounded,
          headline: 'Draw',
          sub: sub,
        );
      default:
        return (
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.4)!],
          icon: Icons.flag_rounded,
          headline: 'Game Over',
          sub: sub,
        );
    }
  }

  Widget _buildHero(BuildContext context, GameProvider gp) {
    final look = _look(context, gp);
    final compact = MediaQuery.of(context).size.height < 700;
    final iconBox = compact ? 64.0 : 84.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, compact ? 20 : 30, 20, compact ? 16 : 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: look.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            left: -50,
            child: _bubble(150, 0.08),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: _bubble(170, 0.07),
          ),
          Positioned(
            top: -14,
            right: -10,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              tooltip: 'Close',
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(look.icon, size: iconBox * 0.55, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                look.headline,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                look.sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final onlineGameRoom = gameProvider.onlineGameRoom;
        final cs = Theme.of(context).colorScheme;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: cs.surface,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(context, gameProvider),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          children: [
                            if (onlineGameRoom != null)
                              _buildOnlinePlayerData(context, gameProvider)
                            else
                              _buildLocalPlayerData(context, widget.user),
                            const SizedBox(height: 20),
                            if (onlineGameRoom != null)
                              _buildRematchSection(
                                context,
                                gameProvider,
                                onlineGameRoom,
                              )
                            else
                              _buildLocalRematchButtons(context, gameProvider),
                            if (onlineGameRoom != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed:
                                          (_buttonsEnabled && !_openingReview)
                                          ? () => _openReview(
                                              onlineGameRoom.gameId,
                                            )
                                          : null,
                                      icon: _openingReview
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.replay_rounded,
                                              size: 18,
                                            ),
                                      label: const Text('Review'),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: _buttonsEnabled
                                          ? () => showReportGameDialog(
                                              context,
                                              onlineGameRoom.gameId,
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.flag_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Report'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );

  ButtonStyle get _secondaryStyle => OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
  );

  Widget _statusLine(BuildContext context) {
    if (_rematchStatus == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final color = _rematchStatusIsError ? cs.error : cs.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _rematchStatus!,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRematchSection(
    BuildContext context,
    GameProvider gameProvider,
    GameRoom onlineGameRoom,
  ) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = widget.user.uid;
    final rematchOfferedBy = onlineGameRoom.rematchOfferedBy;

    // Case 1: A rematch offer is active
    if (rematchOfferedBy != null) {
      // Subcase 1.1: The current user sent the offer
      if (rematchOfferedBy == currentUserId) {
        return Column(
          children: [
            _statusLine(context),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Waiting for opponent...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: _secondaryStyle,
              onPressed: _buttonsEnabled
                  ? () async {
                      dlog('=== CANCEL BUTTON TAPPED ===');
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
              child: const Text('Cancel rematch offer'),
            ),
          ],
        );
      }
      // Subcase 1.2: The opponent sent the offer
      else {
        final offerer = onlineGameRoom.player1Id == rematchOfferedBy
            ? onlineGameRoom.player1DisplayName
            : onlineGameRoom.player2DisplayName ?? 'Opponent';
        return Column(
          children: [
            _statusLine(context),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$offerer wants a rematch!',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    style: _primaryStyle,
                    onPressed: _buttonsEnabled
                        ? () async {
                            final error = await gameProvider.handleRematch(
                              true,
                            );
                            if (mounted) {
                              if (error != null) {
                                _showRematchStatus(error, isError: true);
                              } else {
                                // Accepted. Do NOT pop here: the game screen closes this dialog
                                // itself the moment the new game starts. A second pop here could
                                // close the whole game screen (looked like a crash).
                                _showRematchStatus('Starting rematch...');
                              }
                            }
                          }
                        : null,
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: _secondaryStyle,
                    onPressed: _buttonsEnabled
                        ? () async {
                            dlog('=== DECLINE BUTTON TAPPED ===');
                            gameProvider.logger.i(
                              'DIALOG: Decline button pressed',
                            );
                            setState(() {
                              _buttonsEnabled =
                                  false; // Disable during processing
                            });
                            final error = await gameProvider.handleRematch(
                              false,
                            );
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
                ),
              ],
            ),
          ],
        );
      }
    }
    // Case 2: No active rematch offer
    else {
      final hasUserSentRematch = gameProvider.rematchOfferSent;

      return Column(
        children: [
          _statusLine(context),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: FilledButton.icon(
                  style: _primaryStyle,
                  onPressed: (_buttonsEnabled && !hasUserSentRematch)
                      ? () async {
                          final error = await gameProvider.offerRematch();
                          if (mounted && error != null) {
                            _showRematchStatus(error, isError: true);
                          }
                        }
                      : null,
                  icon: Icon(
                    hasUserSentRematch
                        ? Icons.hourglass_top_rounded
                        : Icons.autorenew_rounded,
                    size: 20,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasUserSentRematch ? 'Requested' : 'Rematch',
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              // TODO: Add rewarded ad requirement for rematch when user base grows
              // Currently disabled to encourage rematch requests during early growth phase
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: _secondaryStyle,
                  onPressed: _buttonsEnabled
                      ? () => Navigator.of(context).pop(GameOverAction.newGame)
                      : null,
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('New game', maxLines: 1)),
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
      children: [
        Expanded(
          flex: 1,
          child: FilledButton.icon(
            style: _primaryStyle,
            onPressed: _buttonsEnabled
                ? () {
                    gameProvider.resetGame(true);
                    Navigator.of(context).pop(GameOverAction.rematch);
                  }
                : null,
            icon: const Icon(Icons.autorenew_rounded, size: 20),
            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Rematch', maxLines: 1)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: OutlinedButton(
            style: _secondaryStyle,
            onPressed: _buttonsEnabled
                ? () => Navigator.of(context).pop(GameOverAction.newGame)
                : null,
            child: const FittedBox(fit: BoxFit.scaleDown, child: Text('New game', maxLines: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalPlayerData(BuildContext context, ChessUser user) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'YOUR RATING',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${user.classicalRating}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _playerTile(
    BuildContext context, {
    required String name,
    required int rating,
    required String? photoUrl,
    required bool isMe,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          ProfileImageWidget(imageUrl: photoUrl, radius: 26),
          const SizedBox(height: 8),
          Text(
            isMe ? 'You' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isMe
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$rating',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isMe ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlinePlayerData(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    final room = gameProvider.onlineGameRoom!;
    final bool isHost = gameProvider.isHost;
    final cs = Theme.of(context).colorScheme;

    final me = _playerTile(
      context,
      name: isHost
          ? room.player1DisplayName
          : (room.player2DisplayName ?? widget.user.displayName),
      rating: isHost
          ? room.player1Rating
          : (room.player2Rating ?? widget.user.classicalRating),
      photoUrl: isHost ? room.player1PhotoUrl : room.player2PhotoUrl,
      isMe: true,
    );
    final opp = _playerTile(
      context,
      name: isHost
          ? (room.player2DisplayName ?? 'Opponent')
          : room.player1DisplayName,
      rating: isHost
          ? (room.player2Rating ?? 0)
          : room.player1Rating,
      photoUrl: isHost ? room.player2PhotoUrl : room.player1PhotoUrl,
      isMe: false,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        me,
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'VS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        opp,
      ],
    );
  }
}

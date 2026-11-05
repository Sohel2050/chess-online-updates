import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';

import '../providers/settings_provider.dart';

/// The board used by the Learn screens: same piece set / theme / labels as the rest of the app.
/// With [onMove] == null the board only shows the position (lesson diagrams, "study" mode).
class LearnBoard extends StatelessWidget {
  final SquaresState state;
  final bool flipped;
  final void Function(Move move)? onMove;

  const LearnBoard({
    super.key,
    required this.state,
    this.flipped = false,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final interactive = onMove != null;
    return AspectRatio(
      aspectRatio: 1,
      child: BoardController(
        state: flipped ? state.board.flipped() : state.board,
        playState: interactive ? state.state : PlayState.observing,
        pieceSet: settings.getPieceSet(),
        theme: settings.effectiveBoardTheme,
        animatePieces: settings.animatePieces,
        labelConfig:
            settings.showLabels ? LabelConfig.standard : LabelConfig.disabled,
        moves: interactive ? state.moves : const [],
        onMove: (Move m) {
          if (onMove != null) onMove!(m);
        },
        markerTheme: MarkerTheme(
          empty: MarkerTheme.dot,
          piece: MarkerTheme.corners(),
        ),
      ),
    );
  }
}

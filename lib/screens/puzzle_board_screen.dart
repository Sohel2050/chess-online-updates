import 'dart:developer';

import 'package:flutter_chess_app/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/widgets/floating_message_button.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/mission_provider.dart';
import '../services/puzzle_service.dart';
import '../services/rated_puzzle_service.dart';
import '../services/personal_puzzle_service.dart';
import '../utils/puzzle_error_handler.dart';
import '../widgets/puzzle_completion_dialog.dart';
import '../widgets/puzzle_loading_widget.dart';
import '../widgets/move_arrow_overlay.dart';

class PuzzleBoardScreen extends StatefulWidget {
  final PuzzleModel puzzle;

  /// Set only when opened from the Daily Puzzle card ("YYYY-MM-DD", the
  /// user's local date). Solving then also records the daily solve.
  final String? dailyDateKey;

  /// Set for rated play (roadmap item 8): the server's attempt id for this puzzle. The result is then
  /// reported to /puzzles/rated/:id/result and moves the puzzle rating instead of the normal solve call.
  final String? ratedAttemptId;

  /// Theme filter of the rated session (null = all themes), used when asking for the next rated puzzle.
  final String? ratedTheme;

  /// Set when opened from "My blunders" (item 9): the solve is reported to /puzzles/mine/:id/solve.
  final String? personalPuzzleId;

  const PuzzleBoardScreen({
    super.key,
    required this.puzzle,
    this.dailyDateKey,
    this.ratedAttemptId,
    this.ratedTheme,
    this.personalPuzzleId,
  });

  @override
  State<PuzzleBoardScreen> createState() => _PuzzleBoardScreenState();
}

class _PuzzleBoardScreenState extends State<PuzzleBoardScreen> {
  late PuzzleMovePattern _movePattern;

  /// The puzzle with its solution normalised to UCI ("d1h5"). Puzzles from
  /// the server / bundled data may list moves in SAN ("Qh5"); everything
  /// below (hint arrow, opponent replies, validation, Show Solution, and the
  /// provider) works only with this UCI version.
  late PuzzleModel _puzzle;
  late bishop.Game _game;
  late SquaresState _state;
  late PuzzleProvider _puzzleProvider;
  bool _isInitialized = false;
  bool _flipBoard = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showVisualHint = false;
  String? _hintUci; // best-move hint shown as an arrow until the next move
  bool _isPlayingSolution = false;
  bool _ratedReported = false; // rated mode: the result of this puzzle is already sent

  /// How many solution plies are currently on the board (opponent's and the
  /// player's correct moves alike). This is the single source of truth for
  /// hint, opponent replies and board restore, so they can never disagree
  /// about the position. (The provider's `currentMoveIndex` only counts the
  /// PLAYER's moves, so it must not be used as a ply index.)
  int _pliesPlayed = 0;

  /// Bumped on every reset / solution playback / re-init. Delayed callbacks
  /// (opponent reply, completion dialog, solution animation) remember the
  /// value they were scheduled with and do nothing if it has changed.
  int _runId = 0;
  List<int> _highlightedSquares = [];

  @override
  void initState() {
    super.initState();
    FloatingMessageController.hide();
    _puzzleProvider = context.read<PuzzleProvider>();
    _initializePuzzle();
  }

  void _initializePuzzle() async {
    try {
      // Validate puzzle data first
      if (widget.puzzle.fen.isEmpty) {
        throw Exception('Puzzle has invalid position data');
      }

      if (widget.puzzle.solution.isEmpty) {
        throw Exception('Puzzle has no solution moves');
      }

      final normalized = _normalizeSolution(widget.puzzle);
      if (normalized == null) {
        throw Exception('Puzzle solution does not fit its position');
      }
      _puzzle = widget.puzzle.copyWith(solution: normalized);

      // Create game from FEN position with error handling
      try {
        _game = bishop.Game(
          variant: bishop.Variant.standard(),
          fen: widget.puzzle.fen,
        );
      } catch (e) {
        throw Exception('Invalid chess position: ${widget.puzzle.fen}');
      }

      // Validate the game state
      if (_game.state.result != null) {
        throw Exception('Puzzle position is already game over');
      }

      _pliesPlayed = 0;
      _runId++;
      _isPlayingSolution = false;
      _hintUci = null;

      // Analyze the puzzle solution to determine move pattern
      final movePattern = _analyzePuzzlePattern();
      _movePattern = movePattern;
      debugPrint('Puzzle ${widget.puzzle.id}: Move pattern: $movePattern');

      // Determine player color based on the pattern
      final playerColor = movePattern.playerColor; // Already an int

      // Set the initial board state from the player's perspective
      // This ensures the UI always shows the board from the player's viewpoint
      _state = _game.squaresState(playerColor);

      // Start the puzzle session with error handling
      try {
        await _puzzleProvider.startPuzzle(_puzzle);
      } catch (e) {
        throw Exception('Failed to start puzzle session: $e');
      }

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Play opponent moves automatically if needed
      if (movePattern.opponentMovesFirst) {
        _scheduleOpponentMove(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = PuzzleErrorHandler.getErrorMessage(e);
      });

      // Show error and navigate back after delay
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  void _onMove(Move move) async {
    if (!_isInitialized || _hasError || _isPlayingSolution) return;
    // Not the player's turn (opponent reply pending, or puzzle finished):
    // ignore silently instead of calling it a wrong move.
    if (!_isUserTurn) return;

    // Log the square click for debugging
    debugPrint('Square clicked: ${move.algebraic()}');

    try {
      // Make the move in the game
      final fenBeforeUserMove = _game.fen;
      final success = _game.makeSquaresMove(move);
      if (!success) {
        _showIncorrectMoveMessage();
        return;
      }
      SoundService.instance.playMove(fenBeforeUserMove, _game.fen);

      // Update the squares state
      // Set the board state from the player's perspective
      _state = _game.squaresState(_movePattern.playerColor);

      // Puzzle solutions are stored in UCI (e.g. e2e4), while
      // Move.algebraic() returns SAN (e.g. e4). Compare resulting positions
      // to identify the exact expected UCI move without mixing notations.
      final expectedUci = _nextUserMoveUci(fen: fenBeforeUserMove);
      var matchedExpectedMove = false;
      if (expectedUci != null) {
        try {
          final expectedGame = bishop.Game(
            variant: bishop.Variant.standard(),
            fen: fenBeforeUserMove,
          );
          matchedExpectedMove = expectedGame.makeMoveString(expectedUci) &&
              expectedGame.fen == _game.fen;
        } catch (e) {
          debugPrint('Could not validate expected puzzle move $expectedUci: $e');
        }
      }

      debugPrint(
        'User move SAN: ${move.algebraic()}, expected UCI: $expectedUci, '
        'matched: $matchedExpectedMove',
      );
      final isValidMove = expectedUci != null && matchedExpectedMove
          ? await _puzzleProvider.makeMove(
              expectedUci,
              isUserMove: _movePattern.isUserMove,
              expectedUserMoves: _movePattern.expectedUserMoves,
            )
          : false;

      if (isValidMove) {
        _pliesPlayed++; // the player's correct move is now on the board
        // Clear any visual hints when a correct move is made
        if (!mounted) return;
        setState(() {
          _showVisualHint = false;
          _highlightedSquares = [];
          _hintUci = null;
        });

        // Clear the incorrect move flag
        _puzzleProvider.clearIncorrectMoveFlag();

        // Check if puzzle is solved
        final session = _puzzleProvider.currentSession;
        if (session != null && session.isCompleted) {
          // Add a small delay before showing completion dialog
          final run = _runId;
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted && run == _runId) {
              _showPuzzleCompletedDialog();
            }
          });
        } else {
          // Make the opponent's response move after a delay to make it visible
          _scheduleOpponentMove(const Duration(milliseconds: 1500));
        }
      } else {
        // Invalid move - reset the board state
        _resetBoardState();
        _showIncorrectMoveMessage();
        _reportRatedFailure();

        // Don't automatically show visual hint - only show when user presses hint button
        // The solution button will be shown to allow user to see the solution if needed
      }

      setState(() {});
    } catch (e) {
      // Handle move processing errors
      if (mounted) {
        PuzzleErrorHandler.showPuzzleDataError(
          context,
          puzzleId: widget.puzzle.id,
          onRetry: () => _resetPuzzle(),
        );
      }
      _resetBoardState();
    }
  }

  // ---- Solution normalisation (SAN / UCI -> UCI) ----------------------------

  static final RegExp _uciRe = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

  /// Piece letters of a FEN board as a 64-entry list, index = rank*8+file
  /// with rank 0 = rank 1 (white's back rank).
  List<String> _fenBoard(String fen) {
    final cells = List<String>.filled(64, '');
    final rows = fen.split(' ').first.split('/');
    for (int r = 0; r < 8 && r < rows.length; r++) {
      int file = 0;
      for (final ch in rows[r].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          file += n;
        } else {
          cells[(7 - r) * 8 + file] = ch;
          file++;
        }
      }
    }
    return cells;
  }

  String _sqName(int i) =>
      '${String.fromCharCode(97 + i % 8)}${(i ~/ 8) + 1}';

  /// The UCI move that turns [before] into [after] (both FEN), found by
  /// comparing the two boards. Works for captures, castling, en passant and
  /// promotion without relying on any move-object API.
  String? _uciFromFens(String before, String after) {
    final a = _fenBoard(before);
    final b = _fenBoard(after);
    final whiteMoved = before.split(' ')[1] == 'w';
    bool mine(String c) =>
        c.isNotEmpty && (c == c.toUpperCase()) == whiteMoved;
    final emptied = <int>[];
    final filled = <int>[];
    for (int i = 0; i < 64; i++) {
      if (a[i] == b[i]) continue;
      if (mine(a[i]) && !mine(b[i])) emptied.add(i);
      if (mine(b[i])) filled.add(i);
    }
    if (emptied.isEmpty || filled.isEmpty) return null;
    int from = emptied.first;
    int to = filled.first;
    if (emptied.length > 1 || filled.length > 1) {
      // Castling: the king's squares are the move.
      final kingChar = whiteMoved ? 'K' : 'k';
      final kf = emptied.where((i) => a[i] == kingChar).toList();
      final kt = filled.where((i) => b[i] == kingChar).toList();
      if (kf.isEmpty || kt.isEmpty) return null;
      from = kf.first;
      to = kt.first;
    }
    var uci = _sqName(from) + _sqName(to);
    if (a[from].toLowerCase() == 'p' && b[to].toLowerCase() != 'p') {
      uci += b[to].toLowerCase(); // promotion piece
    }
    return uci;
  }

  /// Returns the solution as UCI, or null if a move is not legal in turn.
  List<String>? _normalizeSolution(PuzzleModel puzzle) {
    try {
      final g = bishop.Game(variant: bishop.Variant.standard(), fen: puzzle.fen);
      final out = <String>[];
      for (final raw in puzzle.solution) {
        final token = raw.trim();
        final before = g.fen;
        if (_uciRe.hasMatch(token.toLowerCase())) {
          if (!g.makeMoveString(token.toLowerCase())) return null;
          out.add(token.toLowerCase());
          continue;
        }
        final san = token.replaceAll(RegExp(r'[+#!?]'), '');
        bool done = false;
        for (final m in g.generateLegalMoves()) {
          String moveSan;
          try {
            moveSan = g.toSan(m).replaceAll(RegExp(r'[+#!?]'), '');
          } catch (_) {
            continue;
          }
          if (moveSan == san) {
            g.makeMove(m);
            done = true;
            break;
          }
        }
        if (!done) return null;
        final uci = _uciFromFens(before, g.fen);
        if (uci == null) return null;
        out.add(uci);
      }
      return out;
    } catch (e) {
      debugPrint('Could not normalise solution of ${puzzle.id}: $e');
      return null;
    }
  }

  /// True when the next solution ply is one the PLAYER has to play.
  bool get _isUserTurn {
    final solution = _puzzle.solution;
    final isUserMove = _movePattern.isUserMove;
    return _pliesPlayed < solution.length &&
        _pliesPlayed < isUserMove.length &&
        isUserMove[_pliesPlayed];
  }

  /// The next move the player has to find (UCI, e.g. "e2e4"), or null when
  /// it is not the player's turn / the puzzle is over. The move is also
  /// checked against the CURRENT board, so a hint can never point at a move
  /// that is illegal in the position the player is looking at.
  String? _nextUserMoveUci({String? fen}) {
    if (!_isUserTurn) return null;
    final candidate = _puzzle.solution[_pliesPlayed].trim().toLowerCase();
    if (!RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(candidate)) {
      return null;
    }
    try {
      // Dry run on a copy: the real game must not be touched by a hint.
      // [fen] = the position the move is to be played from. After the player
      // has already moved on the board it must be the position BEFORE that
      // move, otherwise the correct move looks illegal.
      final probe = bishop.Game(
        variant: bishop.Variant.standard(),
        fen: fen ?? _game.fen,
      );
      return probe.makeMoveString(candidate) ? candidate : null;
    } catch (_) {
      return null;
    }
  }

  void _scheduleOpponentMove(Duration delay) {
    final run = _runId;
    Future.delayed(delay, () {
      if (mounted && run == _runId && !_isPlayingSolution) {
        _makeOpponentMove();
      }
    });
  }

  /// Plays the opponent's next solution ply (the very first one in
  /// "opponent plays first" puzzles, or the reply after a correct move).
  void _makeOpponentMove() {
    final solution = _puzzle.solution;
    final isUserMove = _movePattern.isUserMove;
    if (_pliesPlayed >= solution.length ||
        _pliesPlayed >= isUserMove.length ||
        isUserMove[_pliesPlayed]) {
      return; // nothing for the opponent to play right now
    }

    final opponentMove = solution[_pliesPlayed];
    debugPrint('Making opponent move #$_pliesPlayed: $opponentMove');

    try {
      final fenBefore = _game.fen;
      if (!_game.makeMoveString(opponentMove)) {
        debugPrint('Failed to make opponent move: $opponentMove');
        return;
      }
      _pliesPlayed++;
      SoundService.instance.playMove(fenBefore, _game.fen);
      _state = _game.squaresState(_movePattern.playerColor);
      if (mounted) setState(() {});

      final session = _puzzleProvider.currentSession;
      if (session != null && session.isCompleted) {
        final run = _runId;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && run == _runId) _showPuzzleCompletedDialog();
        });
      }
    } catch (e) {
      debugPrint('Error making opponent move: $e');
    }
  }

  /// Rebuilds the board from the puzzle's starting FEN and replays the
  /// solution plies already confirmed (`_pliesPlayed`): the opponent's
  /// moves and the player's correct moves alike. Used after a wrong move so
  /// the board snaps back to the position the puzzle is really in (not to
  /// move 0, and not to a position missing the opponent's reply).
  ///
  /// `fromScratch: true` forgets all progress and goes back to the start
  /// (reset, and before "Show Solution" replays the whole solution).
  void _resetBoardState({bool fromScratch = false}) {
    _game = bishop.Game(
      variant: bishop.Variant.standard(),
      fen: widget.puzzle.fen,
    );

    if (fromScratch) {
      _pliesPlayed = 0;
    } else {
      // Replay exactly the plies that are confirmed so far.
      final solution = _puzzle.solution;
      for (int i = 0; i < _pliesPlayed && i < solution.length; i++) {
        _game.makeMoveString(solution[i]);
      }
    }

    // Set the board state from the player's perspective
    _state = _game.squaresState(_movePattern.playerColor);
  }

  void _showIncorrectMoveMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incorrect move. Try again!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool get _isRated => widget.ratedAttemptId != null;
  bool get _isPersonal => widget.personalPuzzleId != null;

  void _showRatingChange(RatedResult result) {
    if (!mounted) return;
    final sign = result.delta >= 0 ? '+' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Puzzle rating ${result.ratingAfter}${result.provisional ? '?' : ''} ($sign${result.delta})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Rated mode: the first wrong move fails the puzzle (the rating drops once). The player may still
  /// retry or look at the solution, but it no longer changes the rating.
  void _reportRatedFailure() {
    if (!_isRated || _ratedReported) return;
    _ratedReported = true;
    RatedPuzzleService()
        .submitResult(widget.ratedAttemptId!, solved: false)
        .then((r) {
      if (r != null) _showRatingChange(r);
    });
  }

  void _showPuzzleCompletedDialog() async {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    if (_isRated) {
      // Rated: report the solve once (only if no earlier wrong move already failed it).
      if (!_ratedReported) {
        _ratedReported = true;
        final ratedMission = context.read<MissionProvider>();
        final ratedStreak = context.read<StreakProvider>();
        RatedPuzzleService()
            .submitResult(
              widget.ratedAttemptId!,
              solved: true,
              moves: List<String>.from(session.userMoves),
              dateKey: PuzzleService.localDateKey(),
            )
            .then((r) {
          if (r != null) _showRatingChange(r);
          ratedStreak.refresh();
          ratedMission.refresh();
        });
      }
    }

    // The server checks the moves, then counts the solve for the puzzle list, the daily puzzle,
    // the streak and the daily missions (all in this one call). Then we refresh the views.
    final missionProvider = context.read<MissionProvider>();
    final streakProvider = context.read<StreakProvider>();
    if (_isPersonal) {
      PersonalPuzzleService()
          .solve(widget.personalPuzzleId!, List<String>.from(session.userMoves), PuzzleService.localDateKey())
          .then((_) {
        streakProvider.refresh();
        missionProvider.refresh();
      });
    }
    if (!_isRated && !_isPersonal) PuzzleService()
        .solvePuzzle(
          widget.puzzle.id,
          List<String>.from(session.userMoves),
          widget.dailyDateKey ?? PuzzleService.localDateKey(),
        )
        .then((_) {
      streakProvider.refresh();
      missionProvider.refresh();
    });

    // Check if there's a next puzzle available
    final hasNextPuzzle = _isRated ? true : (_isPersonal ? false : await _hasNextPuzzle());

    if (!mounted) return;

    final action = await PuzzleCompletionDialog.show(
      context: context,
      session: session,
      hasNextPuzzle: hasNextPuzzle,
    );

    if (!mounted) return;

    switch (action) {
      case PuzzleCompletionAction.retry:
        _resetPuzzle();
        break;
      case PuzzleCompletionAction.nextPuzzle:
        await _nextPuzzle();
        break;
      case null:
        // Dialog was dismissed without action
        break;
    }
  }

  void _resetPuzzle() {
    // Cancels every pending delayed callback and any running solution playback.
    _runId++;
    _isPlayingSolution = false;

    // Check if we have an active session before trying to reset
    if (_puzzleProvider.currentSession == null) {
      // If no session, reinitialize the puzzle
      _initializePuzzle();
    } else {
      _puzzleProvider.resetPuzzle();
      _resetBoardState(fromScratch: true);
      setState(() {
        _showVisualHint = false;
        _highlightedSquares = [];
        _hintUci = null;
      });
      // "Opponent plays first" puzzles must replay that first move again.
      if (_movePattern.opponentMovesFirst) {
        _scheduleOpponentMove(const Duration(milliseconds: 800));
      }
    }
  }

  Future<bool> _hasNextPuzzle() async {
    try {
      // Get the current puzzle difficulty
      final currentDifficulty = widget.puzzle.difficulty;

      // Get all puzzles for this difficulty
      final puzzles = _puzzleProvider.getPuzzlesForDifficulty(
        currentDifficulty,
      );

      // Find current puzzle index
      final currentIndex = puzzles.indexWhere((p) => p.id == widget.puzzle.id);

      // Check if there's a next puzzle
      return currentIndex >= 0 && currentIndex < puzzles.length - 1;
    } catch (e) {
      debugPrint('Error checking for next puzzle: $e');
      return false;
    }
  }

  Future<void> _nextPuzzle() async {
    if (_isRated) {
      final next = await RatedPuzzleService().nextPuzzle(theme: widget.ratedTheme);
      if (!mounted) return;
      if (next == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No more puzzles available right now.')),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PuzzleBoardScreen(
            puzzle: next.puzzle,
            ratedAttemptId: next.attemptId,
            ratedTheme: widget.ratedTheme,
          ),
        ),
      );
      return;
    }
    try {
      // Same list the dialog used to decide that a next puzzle exists. (The provider's own
      // nextPuzzle() needs a user id and an open session; when either was missing it answered
      // null and the app wrongly said "completed all puzzles" and closed the screen.)
      final list = _puzzleProvider.getPuzzlesForDifficulty(widget.puzzle.difficulty);
      final index = list.indexWhere((p) => p.id == widget.puzzle.id);
      PuzzleModel? nextPuzzle =
          (index >= 0 && index < list.length - 1) ? list[index + 1] : null;
      nextPuzzle ??= await _puzzleProvider.nextPuzzle();
      final PuzzleModel? found = nextPuzzle;
      if (found != null) {
        // Replace current screen with new puzzle
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PuzzleBoardScreen(puzzle: found),
            ),
          );
        }
      } else {
        // No more puzzles, go back to difficulty selection
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Congratulations! You completed all puzzles in this difficulty.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Handle errors in navigation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading next puzzle. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        // Go back to the previous screen
        Navigator.of(context).pop();
      }
    }
  }

  /// Shows the next correct move as an arrow. It never plays the move.
  Future<void> _requestHint() async {
    if (!_isInitialized || _hasError || _isPlayingSolution) return;

    final session = _puzzleProvider.currentSession;
    if (session == null || session.state != PuzzleSessionState.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This puzzle is already finished.')),
      );
      return;
    }

    // Opponent's reply still on its way: the board is not ready yet.
    if (!_isUserTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the opponent\'s move first.')),
      );
      return;
    }

    final move = _nextUserMoveUci();
    if (move == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No next move is available for a hint.')),
      );
      return;
    }

    // Same arrow already showing: nothing new to reveal, don't count again.
    if (_hintUci == move) return;

    setState(() {
      _hintUci = move;
      _showVisualHint = false;
      _highlightedSquares = [];
    });

    // Record/use a textual hint if available, but never let that prevent the
    // visual move arrow from appearing.
    await _puzzleProvider.requestHint();
  }

  /// Show Solution: restart from the original position and play the whole
  /// solution move by move. Not counted as solved.
  void _playSolution() {
    if (!_isInitialized || _hasError || _isPlayingSolution) return;
    if (_puzzle.solution.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzle solution is not available.')),
      );
      return;
    }

    // Rated mode: looking at the solution counts as a failed attempt,
    // otherwise "show solution -> retry -> solve" would farm rating.
    _reportRatedFailure();

    final run = ++_runId; // cancels pending opponent replies / dialogs
    setState(() {
      _hintUci = null;
      _showVisualHint = false;
      _highlightedSquares = [];
      _isPlayingSolution = true;
    });

    // Rebuild from the original FEN, then visibly play every solution move.
    _resetBoardState(fromScratch: true);
    _puzzleProvider.clearIncorrectMoveFlag();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && run == _runId) _playSolutionMoves(0, run);
    });
  }

  void _playSolutionMoves(int moveIndex, int run) {
    if (!mounted || run != _runId || !_isPlayingSolution) return;

    final solution = _puzzle.solution;
    if (moveIndex >= solution.length) {
      _onSolutionFinished(run);
      return;
    }

    final moveString = solution[moveIndex];
    try {
      final fenBefore = _game.fen;
      if (_game.makeMoveString(moveString)) {
        SoundService.instance.playMove(fenBefore, _game.fen);
        _state = _game.squaresState(_movePattern.playerColor);
        setState(() {});
        Future.delayed(const Duration(milliseconds: 900), () {
          _playSolutionMoves(moveIndex + 1, run);
        });
      } else {
        debugPrint('Solution playback stopped: illegal move $moveString at index $moveIndex');
        setState(() => _isPlayingSolution = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play solution move: $moveString')),
        );
      }
    } catch (e) {
      debugPrint('Error playing solution move $moveString: $e');
      setState(() => _isPlayingSolution = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred while showing the solution.')),
      );
    }
  }

  /// After the solution has auto-played, finish the puzzle: offer retry / next.
  /// (The puzzle is NOT counted as solved when the solution was shown.)
  Future<void> _onSolutionFinished(int run) async {
    if (mounted) setState(() => _isPlayingSolution = false);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || run != _runId) return;
    final hasNext = _isRated
        ? true
        : (_isPersonal ? false : await _hasNextPuzzle());
    if (!mounted || run != _runId) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Puzzle complete'),
        content: const Text(
          'The solution was played. It is not counted as solved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'retry'),
            child: const Text('Try again'),
          ),
          if (hasNext)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'next'),
              child: const Text('Next puzzle'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'next') {
      await _nextPuzzle();
    } else {
      // "Try again" or dialog dismissed: never leave the board parked on the
      // final position while the session thinks nothing was played.
      _resetPuzzle();
    }
  }

  @override
  void dispose() {
    FloatingMessageController.show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (!_isInitialized && !_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Puzzle...')),
        body: const PuzzleLoadingWidget(message: 'Setting up puzzle...'),
      );
    }

    // Show error state
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle Error')),
        body: PuzzleErrorWidget(
          title: 'Failed to Load Puzzle',
          message: _errorMessage ?? 'Unknown error occurred',
          onRetry: () {
            setState(() {
              _hasError = false;
              _errorMessage = null;
            });
            _initializePuzzle();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      );
    }

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.puzzle.difficulty.displayName} Puzzle'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildPuzzleHeader(context),

                const SizedBox(height: 8),

                // Chess board
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                        children: [
                          BoardController(
                            state: _flipBoard
                                ? _state.board.flipped()
                                : _state.board,
                            playState: _state.state,
                            pieceSet: settingsProvider.getPieceSet(),
                            theme: settingsProvider.effectiveBoardTheme,
                            animatePieces: settingsProvider.animatePieces,
                            labelConfig: settingsProvider.showLabels
                                ? LabelConfig.standard
                                : LabelConfig.disabled,
                            moves: _state.moves,
                            onMove: _onMove,
                            onPremove: _onMove,
                            markerTheme: MarkerTheme(
                              empty: _showVisualHint
                                  ? MarkerTheme.cross()
                                  : MarkerTheme.dot,
                              piece: _showVisualHint
                                  ? MarkerTheme.corners()
                                  : MarkerTheme.corners(),
                            ),
                            promotionBehaviour: PromotionBehaviour.autoPremove,
                          ),
                          // Best-move hint arrow
                          if (_hintUci != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedMoveArrow(
                                  key: ValueKey(_hintUci),
                                  uci: _hintUci,
                                  // The board is already turned for Black by
                                  // squaresState(playerColor); _flipBoard turns it again.
                                  flipped: (_movePattern.playerColor == Squares.black) !=
                                      _flipBoard,
                                  color: const Color(0xCCFFB300),
                                ),
                              ),
                            ),
                          // Overlay for visual hints
                          if (_showVisualHint)
                            ..._highlightedSquares.map(
                              (square) => _HintOverlay(squareIndex: square),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Hint / Reset / Solution in one bar
                _buildActionBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _isPlayingSolution;

    Widget tile({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap,
      bool emphasize = false,
    }) {
      final enabled = onTap != null;
      final c = enabled ? color : scheme.onSurface.withValues(alpha: 0.35);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: emphasize ? Border.all(color: c, width: 2) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, color: c, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Consumer<PuzzleProvider>(
          builder: (context, puzzleProvider, child) {
            final wrong = puzzleProvider.currentSession?.hasIncorrectMove ?? false;
            return Row(
              children: [
                tile(
                  icon: Icons.lightbulb_rounded,
                  label: 'Hint',
                  color: Colors.amber.shade700,
                  onTap: busy ? null : _requestHint,
                ),
                tile(
                  icon: Icons.refresh_rounded,
                  label: 'Reset',
                  color: scheme.primary,
                  onTap: busy ? null : _resetPuzzle,
                ),
                tile(
                  icon: Icons.play_arrow_rounded,
                  label: busy ? 'Showing...' : 'Solution',
                  color: Colors.deepOrange,
                  onTap: busy ? null : _playSolution,
                  emphasize: wrong,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _difficultyColor() {
    switch (widget.puzzle.difficulty.name) {
      case 'beginner':
        return const Color(0xFF4CAF50);
      case 'easy':
        return const Color(0xFF2196F3);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'hard':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  Widget _buildPuzzleHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _difficultyColor();
    final whiteToMove = _movePattern.playerColor == 0;

    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: whiteToMove ? Colors.white : Colors.black,
                  border: Border.all(color: scheme.outline, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.puzzle.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              chip(Icons.flag_rounded, widget.puzzle.difficulty.displayName),
              chip(Icons.trending_up_rounded, '${widget.puzzle.rating}'),
              chip(
                whiteToMove ? Icons.circle_outlined : Icons.circle,
                whiteToMove ? 'White to move' : 'Black to move',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Analyze the puzzle solution to determine the move pattern
  PuzzleMovePattern _analyzePuzzlePattern() {
    final solution = _puzzle.solution;
    final fenTurn = _game.state.turn; // This is a color value

    // For single move puzzles, the player plays as the side to move
    if (solution.length == 1) {
      return PuzzleMovePattern(
        isUserMove: [true],
        playerColor: fenTurn, // Use the int value directly
        opponentMovesFirst: false,
        expectedUserMoves: 1,
      );
    }

    // Use the explicit opponentPlaysFirst field if available
    // This is more reliable than trying to determine it from the solution
    final opponentMovesFirst = widget.puzzle.opponentPlaysFirst;

    // Determine player color based on the opponentMovesFirst flag
    // If opponent moves first, player is the opposite color of the FEN turn
    // If opponent doesn't move first, player is the same color as the FEN turn
    final playerColorValue = opponentMovesFirst
        ? (fenTurn == 0 ? 1 : 0) // Opposite color
        : fenTurn; // Same color

    // Determine which moves are user moves vs opponent moves
    List<bool> isUserMove = [];
    for (int i = 0; i < solution.length; i++) {
      // If opponent moves first, user moves are at odd indices (1, 3, 5...)
      // If opponent doesn't move first, user moves are at even indices (0, 2, 4...)
      final isUser = opponentMovesFirst ? (i % 2 == 1) : (i % 2 == 0);
      isUserMove.add(isUser);
    }

    final expectedUserMoves = isUserMove.where((isUser) => isUser).length;

    return PuzzleMovePattern(
      isUserMove: isUserMove,
      playerColor: playerColorValue, // Use the int value instead of Squares
      opponentMovesFirst: opponentMovesFirst,
      expectedUserMoves: expectedUserMoves,
    );
  }

  /// Overlay widget to highlight squares
  Widget _HintOverlay({required int squareIndex}) {
    // Convert square index to row/column (0-7)
    final row = squareIndex ~/ 8;
    final col = squareIndex % 8;

    // Calculate position as percentage (0-100%)
    final leftPercent = col * 12.5; // 12.5% per square
    final topPercent = row * 12.5;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate actual pixel positions based on board size
          final squareSize = constraints.maxWidth / 8;
          final left = col * squareSize;
          final top = row * squareSize;

          return Stack(
            children: [
              // Position the highlight at the correct square
              Positioned(
                left: left,
                top: top,
                width: squareSize,
                height: squareSize,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

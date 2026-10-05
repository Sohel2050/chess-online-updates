import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/puzzle_error_handler.dart';
import '../widgets/puzzle_completion_dialog.dart';
import '../widgets/puzzle_loading_widget.dart';

class PuzzleBoardScreen extends StatefulWidget {
  final PuzzleModel puzzle;

  const PuzzleBoardScreen({super.key, required this.puzzle});

  @override
  State<PuzzleBoardScreen> createState() => _PuzzleBoardScreenState();
}

class _PuzzleBoardScreenState extends State<PuzzleBoardScreen> {
  late PuzzleMovePattern _movePattern;
  late bishop.Game _game;
  late SquaresState _state;
  late PuzzleProvider _puzzleProvider;
  bool _isInitialized = false;
  bool _flipBoard = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showVisualHint = false;
  List<int> _highlightedSquares = [];

  @override
  void initState() {
    super.initState();
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
        await _puzzleProvider.startPuzzle(widget.puzzle);
      } catch (e) {
        throw Exception('Failed to start puzzle session: $e');
      }

      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Play opponent moves automatically if needed
      if (movePattern.opponentMovesFirst) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _makeOpponentFirstMove();
          }
        });
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
    if (!_isInitialized || _hasError) return;

    // Log the square click for debugging
    debugPrint('Square clicked: ${move.algebraic()}');

    try {
      // Make the move in the game
      final success = _game.makeSquaresMove(move);
      if (!success) {
        _showIncorrectMoveMessage();
        return;
      }

      // Update the squares state
      // Set the board state from the player's perspective
      _state = _game.squaresState(_movePattern.playerColor);

      // Convert move to UCI notation to match puzzle solution format
      final moveString = move.algebraic();

      // Check if this puzzle has an opponent first move (multi-move with player as opposite color)
      final hasOpponentFirstMove = widget.puzzle.solution.length > 1;
      debugPrint(
        'User move: $moveString, hasOpponentFirstMove: $hasOpponentFirstMove',
      );
      final isValidMove = await _puzzleProvider.makeMove(
        moveString,
        isUserMove: _movePattern.isUserMove,
        expectedUserMoves: _movePattern.expectedUserMoves,
      );

      if (isValidMove) {
        // Clear any visual hints when a correct move is made
        setState(() {
          _showVisualHint = false;
          _highlightedSquares = [];
        });

        // Clear the incorrect move flag
        _puzzleProvider.clearIncorrectMoveFlag();

        // Check if puzzle is solved
        final session = _puzzleProvider.currentSession;
        if (session != null && session.isCompleted) {
          // Add a small delay before showing completion dialog
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _showPuzzleCompletedDialog();
            }
          });
        } else {
          // Make the opponent's response move after a delay to make it visible
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _makeOpponentMove();
            }
          });
        }
      } else {
        // Invalid move - reset the board state
        _resetBoardState();
        _showIncorrectMoveMessage();

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

  void _showVisualHintForNextMove() {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    // Find the next user move in the solution based on the move pattern
    String? nextMoveSource;
    final solution = session.puzzle.solution;
    final isUserMove = _movePattern.isUserMove;

    log(
      'Show visual hint for next move: $isUserMove- ${session.userMoves.length} user moves played, ${isUserMove.length} user moves found',
    );

    // Find the next user move after the current user moves
    int userMovesPlayed = session.userMoves.length;
    int userMovesFound = 0;

    for (int i = 0; i < solution.length && i < isUserMove.length; i++) {
      if (isUserMove[i]) {
        if (userMovesFound == userMovesPlayed) {
          // This is the next user move
          final move = solution[i];
          if (move.length >= 2) {
            nextMoveSource = move.substring(0, 2);
            break;
          }
        }
        userMovesFound++;
      }
    }

    if (nextMoveSource != null && nextMoveSource.length == 2) {
      // Convert algebraic notation to square index
      final file = nextMoveSource.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = 8 - (nextMoveSource.codeUnitAt(1) - '0'.codeUnitAt(0));

      log('Next move source: $nextMoveSource, file: $file, rank: $rank');

      if (file >= 0 && file < 8 && rank >= 0 && rank < 8) {
        final squareIndex = rank * 8 + file;

        setState(() {
          _showVisualHint = true;
          _highlightedSquares = [squareIndex];
        });

        log('Showing visual hint for next move: $squareIndex');

        // Automatically hide the hint after a few seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showVisualHint = false;
              _highlightedSquares = [];
            });
          }
        });
      }
    }
  }

  void _makeOpponentFirstMove() {
    // This method handles cases where the opponent needs to play the first move
    // to set up the puzzle position (like in puzzle 001KR where Black plays Kg8 first)

    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    final solution = session.puzzle.solution;
    if (solution.isEmpty) return;

    final firstSolutionMove = solution.first;
    debugPrint('Making opponent first move: $firstSolutionMove');

    try {
      // Make the first move from the solution as the opponent's move
      final success = _game.makeMoveString(firstSolutionMove);

      if (success) {
        // Update the squares state for the new position
        // After opponent's move, set the board state from the player's perspective
        _state = _game.squaresState(_movePattern.playerColor);

        setState(() {});

        // // Show a brief message about the opponent's move
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       'Opponent played: ${_formatMoveForDisplay(firstSolutionMove)}',
        //     ),
        //     backgroundColor: Colors.blue,
        //     duration: const Duration(seconds: 2),
        //   ),
        // );
      } else {
        debugPrint('Failed to make opponent first move: $firstSolutionMove');
      }
    } catch (e) {
      debugPrint('Could not make opponent first move: $e');
      // If we can't make the move, just continue with the puzzle as is
    }
  }

  void _makeOpponentMove() {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    final solution = session.puzzle.solution;
    final userMoves = session.userMoves;

    // Use the move pattern to find the next opponent move
    int nextOpponentMoveIndex = -1;
    int userMovesSeen = 0;

    // Find the next opponent move after the current user moves
    for (int i = 0; i < _movePattern.isUserMove.length; i++) {
      if (_movePattern.isUserMove[i]) {
        userMovesSeen++;
        if (userMovesSeen > userMoves.length) {
          // We've found all user moves, now look for the next opponent move
          break;
        }
      } else {
        // This is an opponent move
        if (userMovesSeen == userMoves.length) {
          // This is the next opponent move to play
          nextOpponentMoveIndex = i;
          break;
        }
      }
    }

    debugPrint(
      'Looking for opponent move at index $nextOpponentMoveIndex, userMoves: ${userMoves.length}, solution length: ${solution.length}',
    );

    // Check if there's an opponent response move
    if (nextOpponentMoveIndex >= 0 && nextOpponentMoveIndex < solution.length) {
      final opponentMoveString = solution[nextOpponentMoveIndex];
      debugPrint('Making opponent move: $opponentMoveString');

      // Make the opponent move using UCI notation
      try {
        // Parse the UCI move and make it
        final success = _game.makeMoveString(opponentMoveString);

        if (success) {
          // Update state after opponent move
          // Set the board state from the player's perspective
          _state = _game.squaresState(_movePattern.playerColor);
          setState(() {});

          // // Show a brief message about the opponent's move
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(
          //       'Opponent played: ${_formatMoveForDisplay(opponentMoveString)}',
          //     ),
          //     backgroundColor: Colors.blue,
          //     duration: const Duration(seconds: 2),
          //   ),
          // );

          // Check if puzzle is completed after opponent's move
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              final updatedSession = _puzzleProvider.currentSession;
              if (updatedSession != null && updatedSession.isCompleted) {
                _showPuzzleCompletedDialog();
              }
            }
          });
        } else {
          debugPrint('Failed to make opponent move: $opponentMoveString');
        }
      } catch (e) {
        // Handle move parsing error
        debugPrint('Error making opponent move: $e');
      }
    } else {
      debugPrint('No more opponent moves in solution');
    }
  }

  /// Rebuilds the board position from the puzzle's starting FEN.
  ///
  /// By default (`fromScratch: false`), it replays every solution move
  /// already confirmed correct so far (opponent's auto-played moves and
  /// the player's own correct moves alike), instead of always snapping
  /// back to move 0.
  ///
  /// This fixes a bug where, in a multi-move puzzle, getting a LATER move
  /// wrong would reset the visible board all the way to the start while
  /// `_puzzleProvider`'s session (`currentMoveIndex`, `userMoves`) stayed
  /// at wherever the player had correctly progressed to — the board and
  /// the provider disagreed about the position, so nothing the player did
  /// next matched what the provider expected, effectively locking the
  /// puzzle. Replaying up to the session's actual progress keeps both in
  /// sync.
  ///
  /// Pass `fromScratch: true` for an intentional full reset regardless of
  /// progress (e.g. `_playSolution`, which then replays the ENTIRE
  /// solution from move 0 for the "show solution" animation).
  void _resetBoardState({bool fromScratch = false}) {
    _game = bishop.Game(
      variant: bishop.Variant.standard(),
      fen: widget.puzzle.fen,
    );

    if (!fromScratch) {
      final session = _puzzleProvider.currentSession;
      final progress = session?.currentMoveIndex ?? 0;
      final solution = widget.puzzle.solution;
      for (int i = 0; i < progress && i < solution.length; i++) {
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

  void _showPuzzleCompletedDialog() async {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    // Check if there's a next puzzle available
    final hasNextPuzzle = await _hasNextPuzzle();

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
    // Check if we have an active session before trying to reset
    if (_puzzleProvider.currentSession == null) {
      // If no session, reinitialize the puzzle
      _initializePuzzle();
    } else {
      _puzzleProvider.resetPuzzle();
      _resetBoardState();
      setState(() {
        _showVisualHint = false;
        _highlightedSquares = [];
      });
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
    try {
      final nextPuzzle = await _puzzleProvider.nextPuzzle();
      if (nextPuzzle != null) {
        // Replace current screen with new puzzle
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PuzzleBoardScreen(puzzle: nextPuzzle),
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

  Future<void> _requestHint() async {
    // Instead of showing the hint bottom sheet, we'll show a visual hint
    // But first, we need to get the hint from the provider
    final hint = await _puzzleProvider.requestHint();
    if (hint != null) {
      log('showing hint: $hint');
      // Show the visual hint
      _showVisualHintForNextMove();
    }
  }

  void _showHintBottomSheet(String hint) {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hint ${session.hintsUsed}/${widget.puzzle.effectiveHintCount}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Puzzle hint to help you solve this position',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hint content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                hint,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // Hint usage info
            if (session.hintsUsed < widget.puzzle.effectiveHintCount)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.puzzle.effectiveHintCount - session.hintsUsed} more hints available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
                  ),
                ),
                if (session.hintsUsed < widget.puzzle.effectiveHintCount) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _requestHint();
                      },
                      icon: const Icon(Icons.lightbulb, size: 18),
                      label: const Text('Next Hint'),
                    ),
                  ),
                ],
              ],
            ),

            // Add bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _playSolution() {
    // Full reset to move 0 — this is about to replay the ENTIRE solution
    // from the start, not just resume wherever the player had progressed to.
    _resetBoardState(fromScratch: true);

    // Clear the incorrect move flag
    _puzzleProvider.clearIncorrectMoveFlag();

    // Play through the solution with delays
    _playSolutionMoves(0);
  }

  void _playSolutionMoves(int moveIndex) {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    final solution = session.puzzle.solution;

    if (moveIndex >= solution.length) {
      // Solution playback complete
      return;
    }

    final moveString = solution[moveIndex];

    try {
      // Make the move
      final success = _game.makeMoveString(moveString);

      if (success) {
        // Update the board state
        _state = _game.squaresState(_movePattern.playerColor);

        setState(() {});

        // Schedule the next move after a delay
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _playSolutionMoves(moveIndex + 1);
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing solution move: $e');
    }
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
            actions: [
              Consumer<PuzzleProvider>(
                builder: (context, puzzleProvider, child) {
                  final session = puzzleProvider.currentSession;
                  final hasMoreHints = session?.hasMoreHints ?? false;
                  final hintsUsed = session?.hintsUsed ?? 0;
                  final totalHints = widget.puzzle.effectiveHintCount;

                  return Stack(
                    children: [
                      IconButton(
                        onPressed: hasMoreHints ? _requestHint : null,
                        icon: Icon(
                          Icons.lightbulb,
                          color: hasMoreHints
                              ? (hintsUsed > 0 ? Colors.amber : null)
                              : Colors.grey,
                        ),
                        tooltip: hasMoreHints
                            ? 'Get Hint ($hintsUsed/$totalHints used)'
                            : 'No more hints available',
                      ),
                      if (hintsUsed > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$hintsUsed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              // IconButton(
              //   onPressed: () {
              //     setState(() {
              //       _flipBoard = !_flipBoard;
              //     });
              //   },
              //   icon: const Icon(Icons.flip),
              //   tooltip: 'Flip Board',
              // ),
              IconButton(
                onPressed: _resetPuzzle,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reset Puzzle',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Puzzle info section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Objective
                      Text(
                        widget.puzzle.objective,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Puzzle metadata
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.puzzle.difficulty.displayName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rating: ${widget.puzzle.rating}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const Spacer(),
                          Consumer<PuzzleProvider>(
                            builder: (context, puzzleProvider, child) {
                              final session = puzzleProvider.currentSession;
                              final hintsUsed = session?.hintsUsed ?? 0;
                              final totalHints = widget.puzzle.effectiveHintCount;
                              final hasUsedHints = hintsUsed > 0;
                              final hasMoreHints = hintsUsed < totalHints;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: hasUsedHints
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: hasUsedHints
                                      ? Border.all(
                                          color: Colors.amber.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb,
                                      size: 16,
                                      color: hasUsedHints
                                          ? Colors.amber[700]
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$hintsUsed/$totalHints',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: hasUsedHints
                                                ? Colors.amber[700]
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: hasUsedHints
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                    ),
                                    if (!hasMoreHints && totalHints > 0) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.amber[700],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

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
                            theme: settingsProvider.boardTheme,
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

                // Solution button (only shown when an incorrect move was made)
                Consumer<PuzzleProvider>(
                  builder: (context, puzzleProvider, child) {
                    final session = puzzleProvider.currentSession;
                    final showSolutionButton =
                        session?.hasIncorrectMove ?? false;

                    if (showSolutionButton) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _playSolution,
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Show Solution',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Bottom action buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetPuzzle,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer<PuzzleProvider>(
                          builder: (context, puzzleProvider, child) {
                            final session = puzzleProvider.currentSession;
                            final hasMoreHints = session?.hasMoreHints ?? false;
                            final hintsUsed = session?.hintsUsed ?? 0;
                            final totalHints = widget.puzzle.effectiveHintCount;

                            return ElevatedButton.icon(
                              onPressed: hasMoreHints ? _requestHint : null,
                              icon: Icon(
                                Icons.lightbulb,
                                color: hasMoreHints
                                    ? (hintsUsed > 0 ? Colors.amber : null)
                                    : null,
                              ),
                              label: Text(
                                hasMoreHints
                                    ? 'Hint ($hintsUsed/$totalHints)'
                                    : 'No Hints Left',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasMoreHints
                                    ? (hintsUsed > 0
                                          ? Colors.amber.withValues(alpha: 0.1)
                                          : null)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Analyze the puzzle solution to determine the move pattern
  PuzzleMovePattern _analyzePuzzlePattern() {
    final solution = widget.puzzle.solution;
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

  /// Build an overlay to highlight a square for hints
  Widget _buildHintOverlay(int squareIndex) {
    return _HintOverlay(squareIndex: squareIndex);
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

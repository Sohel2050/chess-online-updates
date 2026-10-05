import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_progress.dart';
import '../services/puzzle_service.dart';

// Class to represent the pattern of moves in a puzzle
class PuzzleMovePattern {
  final List<bool> isUserMove; // true for user moves, false for opponent moves
  final int playerColor; // Squares.white or Squares.black
  final bool opponentMovesFirst;
  final int expectedUserMoves;

  PuzzleMovePattern({
    required this.isUserMove,
    required this.playerColor,
    required this.opponentMovesFirst,
    required this.expectedUserMoves,
  });

  @override
  String toString() {
    return 'PuzzleMovePattern(userMoves: ${isUserMove.length}, expectedUserMoves: $expectedUserMoves, playerColor: $playerColor, opponentFirst: $opponentMovesFirst)';
  }
}

/// Enum representing the current state of a puzzle session
enum PuzzleSessionState {
  /// No puzzle is currently active
  idle,

  /// Puzzle is loaded and ready to be solved
  active,

  /// Puzzle has been successfully solved
  solved,

  /// Puzzle attempt failed (incorrect moves)
  failed,

  /// Puzzle session was abandoned by the user
  abandoned,
}

/// Model representing the current puzzle session
class PuzzleSession {
  /// The current puzzle being solved
  final PuzzleModel puzzle;

  /// List of moves made by the user so far
  final List<String> userMoves;

  /// Current move index in the solution sequence
  final int currentMoveIndex;

  /// Number of hints used in this session
  final int hintsUsed;

  /// When the puzzle session started
  final DateTime startTime;

  /// Current state of the puzzle session
  final PuzzleSessionState state;

  /// Current hint text being displayed (if any)
  final String? currentHint;

  /// Whether an incorrect move was made
  final bool hasIncorrectMove;

  const PuzzleSession({
    required this.puzzle,
    required this.userMoves,
    required this.currentMoveIndex,
    required this.hintsUsed,
    required this.startTime,
    required this.state,
    this.currentHint,
    this.hasIncorrectMove = false,
  });

  /// Create a new puzzle session
  factory PuzzleSession.start(PuzzleModel puzzle) {
    return PuzzleSession(
      puzzle: puzzle,
      userMoves: [],
      currentMoveIndex: 0,
      hintsUsed: 0,
      startTime: DateTime.now(),
      state: PuzzleSessionState.active,
      hasIncorrectMove: false,
    );
  }

  /// Create a copy of this session with updated fields
  PuzzleSession copyWith({
    PuzzleModel? puzzle,
    List<String>? userMoves,
    int? currentMoveIndex,
    int? hintsUsed,
    DateTime? startTime,
    PuzzleSessionState? state,
    String? currentHint,
    bool? hasIncorrectMove,
  }) {
    return PuzzleSession(
      puzzle: puzzle ?? this.puzzle,
      userMoves: userMoves ?? this.userMoves,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      startTime: startTime ?? this.startTime,
      state: state ?? this.state,
      currentHint: currentHint ?? this.currentHint,
      hasIncorrectMove: hasIncorrectMove ?? this.hasIncorrectMove,
    );
  }

  /// Get the solve time for this session
  Duration get solveTime => DateTime.now().difference(startTime);

  /// Check if the puzzle is completed
  bool get isCompleted => state == PuzzleSessionState.solved;

  /// Check if hints are available. Puzzles with no hand-written `hints`
  /// (e.g. the Lichess-sourced batch) still get 3 generated hints as long
  /// as they have a solution — see PuzzleService.getNextHint.
  bool get hasMoreHints => hintsUsed < puzzle.effectiveHintCount;

  /// Get the next move in the solution
  String? get nextMove {
    if (currentMoveIndex < puzzle.solution.length) {
      return puzzle.solution[currentMoveIndex];
    }
    return null;
  }

  /// Get the source square for the next move
  String? get nextMoveSourceSquare {
    final move = nextMove;
    if (move != null && move.length >= 2) {
      // Extract the source square (first two characters)
      return move.substring(0, 2);
    }
    return null;
  }
}

/// Provider for managing puzzle state and user interactions
class PuzzleProvider extends ChangeNotifier {
  final PuzzleService _puzzleService = PuzzleService();
  final Logger _logger = Logger();

  // Current session state
  PuzzleSession? _currentSession;

  // Available puzzles by difficulty
  final Map<PuzzleDifficulty, List<PuzzleModel>> _puzzlesByDifficulty = {};

  // Progress tracking by difficulty
  final Map<PuzzleDifficulty, List<PuzzleProgress>> _progressByDifficulty = {};

  // Current user ID
  String? _currentUserId;

  // Loading states
  bool _isLoading = false;
  bool _isInitializing = false;
  String? _errorMessage;
  bool _hasInitialized = false;

  // Getters
  PuzzleSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get hasInitialized => _hasInitialized;
  bool get hasPuzzleActive =>
      _currentSession != null &&
      _currentSession!.state == PuzzleSessionState.active;

  /// Get available puzzles for a difficulty level
  List<PuzzleModel> getPuzzlesForDifficulty(PuzzleDifficulty difficulty) {
    return _puzzlesByDifficulty[difficulty] ?? [];
  }

  /// Get progress for a difficulty level
  List<PuzzleProgress> getProgressForDifficulty(PuzzleDifficulty difficulty) {
    return _progressByDifficulty[difficulty] ?? [];
  }

  /// Set the current user ID
  void setUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadUserProgressWithErrorHandling();
    }
  }

  /// Initialize the provider and load puzzles
  Future<void> initialize({String? userId}) async {
    if (_isInitializing) {
      _logger.w('Initialization already in progress');
      return;
    }

    _isInitializing = true;
    _setLoading(true);
    _clearError();

    try {
      _logger.i('Initializing PuzzleProvider');

      if (userId != null) {
        _currentUserId = userId;
      }

      // Load all puzzles and organize by difficulty with timeout
      await _loadPuzzlesByDifficultyWithTimeout();

      // Load user progress if user ID is available
      if (_currentUserId != null) {
        await _loadUserProgressWithErrorHandling();
      }

      _hasInitialized = true;
      _logger.i('PuzzleProvider initialized successfully');
    } catch (e) {
      _logger.e('Error initializing PuzzleProvider: $e');
      _setError(_getErrorMessage(e));
    } finally {
      _isInitializing = false;
      _setLoading(false);
    }
  }

  /// Retry initialization
  Future<void> retryInitialization() async {
    _hasInitialized = false;
    await initialize(userId: _currentUserId);
  }

  /// Start a new puzzle session
  Future<void> startPuzzle(PuzzleModel puzzle) async {
    try {
      _logger.i('Starting puzzle: ${puzzle.id}');
      _clearError();

      // End current session if active
      if (_currentSession != null) {
        await _endCurrentSession(abandoned: true);
      }

      // Create new session
      _currentSession = PuzzleSession.start(puzzle);

      // Create or update progress record
      if (_currentUserId != null) {
        await _initializePuzzleProgress(puzzle);
      }

      notifyListeners();
      _logger.i('Puzzle session started: ${puzzle.id}');
    } catch (e) {
      _logger.e('Error starting puzzle ${puzzle.id}: $e');
      _setError('Failed to start puzzle: $e');
    }
  }

  /// Make a move in the current puzzle
  Future<bool> makeMove(
    String move, {
    required List<bool> isUserMove,
    required int expectedUserMoves,
  }) async {
    if (_currentSession == null ||
        _currentSession!.state != PuzzleSessionState.active) {
      _logger.w('No active puzzle session to make move');
      return false;
    }

    try {
      _logger.i('Making move: $move for puzzle ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;
      final currentMoves = List<String>.from(_currentSession!.userMoves);

      // Find the solution index for the current user move
      int solutionIndex = -1;
      int userMovesSeen = 0;

      for (int i = 0; i < isUserMove.length; i++) {
        if (isUserMove[i]) {
          if (userMovesSeen == currentMoves.length) {
            solutionIndex = i;
            break;
          }
          userMovesSeen++;
        }
      }

      // Validate the move
      final isValidMove =
          solutionIndex >= 0 &&
          solutionIndex < puzzle.solution.length &&
          puzzle.solution[solutionIndex] == move;

      _logger.i(
        'Move validation: solutionIndex=$solutionIndex, expected=${solutionIndex >= 0 ? puzzle.solution[solutionIndex] : 'none'}, actual=$move, valid=$isValidMove',
      );

      if (!isValidMove) {
        _logger.w('Invalid move: $move');
        await _incrementAttempts();

        // Mark that an incorrect move was made
        _currentSession = _currentSession!.copyWith(hasIncorrectMove: true);
        notifyListeners();

        return false;
      }

      // Add the move to user moves
      currentMoves.add(move);

      // Update session with new move
      _currentSession = _currentSession!.copyWith(
        userMoves: currentMoves,
        currentMoveIndex: currentMoves.length,
      );

      // Check if puzzle is solved
      final isSolved = currentMoves.length == expectedUserMoves;

      _logger.i(
        'Puzzle completion check: userMoves=${currentMoves.length}, expected=$expectedUserMoves, solved=$isSolved',
      );

      if (isSolved) {
        // Update session state to solved before completing
        _currentSession = _currentSession!.copyWith(
          state: PuzzleSessionState.solved,
        );
        await _completePuzzle();
      }

      notifyListeners();
      _logger.i('Move processed successfully: $move');
      return true;
    } catch (e) {
      _logger.e('Error making move $move: $e');
      _setError('Failed to process move: $e');
      return false;
    }
  }

  /// Request a hint for the current puzzle
  Future<String?> requestHint() async {
    if (_currentSession == null ||
        _currentSession!.state != PuzzleSessionState.active) {
      _logger.w('No active puzzle session to request hint');
      return null;
    }

    try {
      _logger.i('Requesting hint for puzzle ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;
      final currentHints = _currentSession!.hintsUsed;

      // Check if more hints are available (real hints, or generated ones
      // derived from the solution when the puzzle has no hand-written text)
      final maxHints = puzzle.effectiveHintCount;
      if (currentHints >= maxHints) {
        _logger.w('No more hints available for puzzle ${puzzle.id}');
        return null;
      }

      // Get the next hint
      final hint = _puzzleService.getNextHint(puzzle, currentHints);

      if (hint != null) {
        // Update session with incremented hint count
        _currentSession = _currentSession!.copyWith(
          hintsUsed: currentHints + 1,
          currentHint: hint,
        );

        // Update progress
        if (_currentUserId != null) {
          await _incrementHints();
        }

        notifyListeners();
        _logger.i('Hint provided for puzzle ${puzzle.id}');
      }

      return hint;
    } catch (e) {
      _logger.e('Error requesting hint: $e');
      _setError('Failed to get hint: $e');
      return null;
    }
  }

  /// Reset the current puzzle to its initial state
  Future<void> resetPuzzle() async {
    if (_currentSession == null) {
      _logger.w('No puzzle session to reset');
      // Don't return early, instead try to recreate the session
      // This handles cases where the session was unexpectedly ended
      if (_puzzlesByDifficulty.isNotEmpty) {
        _logger.i('Attempting to recreate session for reset');
        // We don't have enough information to recreate the exact session
        // The UI should handle this case by showing an error or preventing reset
      }
      return;
    }

    try {
      _logger.i('Resetting puzzle: ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;

      // Create new session with same puzzle
      _currentSession = PuzzleSession.start(puzzle);

      // Reset progress if needed
      if (_currentUserId != null) {
        await _initializePuzzleProgress(puzzle);
      }

      notifyListeners();
      _logger.i('Puzzle reset: ${puzzle.id}');
    } catch (e) {
      _logger.e('Error resetting puzzle: $e');
      _setError('Failed to reset puzzle: $e');
    }
  }

  /// Clear the incorrect move flag
  void clearIncorrectMoveFlag() {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(hasIncorrectMove: false);
      notifyListeners();
    }
  }

  /// Navigate to the next puzzle in the current difficulty level
  Future<PuzzleModel?> nextPuzzle() async {
    if (_currentSession == null) {
      _logger.w('No current session to get next puzzle');
      return null;
    }

    try {
      _logger.i('Getting next puzzle after ${_currentSession!.puzzle.id}');
      _clearError();

      final currentPuzzle = _currentSession!.puzzle;

      // Get next puzzle BEFORE ending current session to avoid race conditions
      PuzzleModel? nextPuzzle;
      if (_currentUserId != null) {
        nextPuzzle = await _puzzleService.getNextPuzzle(
          _currentUserId!,
          currentPuzzle.difficulty,
          currentPuzzle.id,
        );
      }

      if (nextPuzzle == null) {
        _logger.i(
          'No more puzzles in difficulty ${currentPuzzle.difficulty.displayName}',
        );
        // End current session only if there's no next puzzle
        await _endCurrentSession();
        return null;
      }

      // End current session
      await _endCurrentSession();

      // Start new puzzle session
      await startPuzzle(nextPuzzle);

      return nextPuzzle;
    } catch (e) {
      _logger.e('Error getting next puzzle: $e');
      _setError('Failed to get next puzzle: $e');
      return null;
    }
  }

  /// Get completion percentage for a difficulty level
  int getCompletionPercentage(PuzzleDifficulty difficulty) {
    final puzzles = getPuzzlesForDifficulty(difficulty);
    final progress = getProgressForDifficulty(difficulty);

    if (puzzles.isEmpty) return 0;

    final completedCount = progress.where((p) => p.completed).length;
    return ((completedCount / puzzles.length) * 100).round();
  }

  /// Get the first unsolved puzzle for a difficulty level
  Future<PuzzleModel?> getFirstUnsolvedPuzzle(
    PuzzleDifficulty difficulty,
  ) async {
    if (_currentUserId == null) {
      final puzzles = getPuzzlesForDifficulty(difficulty);
      return puzzles.isNotEmpty ? puzzles.first : null;
    }

    try {
      return await _puzzleService.getFirstUnsolvedPuzzle(
        _currentUserId!,
        difficulty,
      );
    } catch (e) {
      _logger.e('Error getting first unsolved puzzle: $e');
      return null;
    }
  }

  /// End the current puzzle session
  Future<void> endCurrentSession({bool abandoned = false}) async {
    await _endCurrentSession(abandoned: abandoned);
  }

  /// Clear all puzzle progress for a user
  Future<void> clearAllPuzzleProgress(String userId) async {
    try {
      _logger.i('Clearing all puzzle progress for user: $userId');
      await _puzzleService.clearUserProgress(userId);

      // Clear local cache
      _progressByDifficulty.clear();

      // Reload user progress
      await _loadUserProgressWithErrorHandling();

      notifyListeners();
      _logger.i('All puzzle progress cleared for user: $userId');
    } catch (e) {
      _logger.e('Error clearing all puzzle progress for user $userId: $e');
      rethrow;
    }
  }

  // Private helper methods

  /// Load puzzles organized by difficulty with timeout
  Future<void> _loadPuzzlesByDifficultyWithTimeout() async {
    _puzzlesByDifficulty.clear();

    try {
      // Add timeout to prevent hanging
      await Future.wait(
        PuzzleDifficulty.values.map((difficulty) async {
          try {
            final puzzles = await _puzzleService
                .getPuzzlesByDifficulty(difficulty)
                .timeout(const Duration(seconds: 10));
            _puzzlesByDifficulty[difficulty] = puzzles;
            _logger.i(
              'Loaded ${puzzles.length} puzzles for ${difficulty.displayName}',
            );
          } catch (e) {
            _logger.w(
              'Failed to load puzzles for ${difficulty.displayName}: $e',
            );
            _puzzlesByDifficulty[difficulty] = []; // Set empty list as fallback
          }
        }),
      ).timeout(const Duration(seconds: 30));

      // Check if we have any puzzles at all
      final totalPuzzles = _puzzlesByDifficulty.values.fold<int>(
        0,
        (sum, puzzles) => sum + puzzles.length,
      );

      if (totalPuzzles == 0) {
        throw Exception('No puzzles could be loaded from any difficulty level');
      }

      _logger.i('Successfully loaded puzzles for all difficulty levels');
    } catch (e) {
      _logger.e('Error loading puzzles by difficulty: $e');
      rethrow;
    }
  }

  /// Load user progress for all difficulties with error handling
  Future<void> _loadUserProgressWithErrorHandling() async {
    if (_currentUserId == null) return;

    _progressByDifficulty.clear();

    try {
      final allProgress = await _puzzleService
          .getAllUserProgress(_currentUserId!)
          .timeout(const Duration(seconds: 15));

      // Organize progress by difficulty
      for (final progress in allProgress) {
        try {
          final difficulty = progress.difficulty;
          _progressByDifficulty[difficulty] ??= [];
          _progressByDifficulty[difficulty]!.add(progress);
        } catch (e) {
          _logger.w('Error processing progress record: $e');
          // Continue with other progress records
        }
      }

      _logger.i('Loaded progress for ${allProgress.length} puzzles');
    } catch (e) {
      _logger.e('Error loading user progress: $e');
      // Don't rethrow - progress loading failure shouldn't prevent puzzle access
      // Initialize empty progress for all difficulties
      for (final difficulty in PuzzleDifficulty.values) {
        _progressByDifficulty[difficulty] = [];
      }
    }
  }

  /// Initialize or get existing progress for a puzzle
  Future<void> _initializePuzzleProgress(PuzzleModel puzzle) async {
    if (_currentUserId == null) return;

    try {
      var progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        puzzle.id,
      );

      if (progress == null) {
        // Create new progress record
        progress = PuzzleProgress.newAttempt(
          userId: _currentUserId!,
          puzzleId: puzzle.id,
          difficulty: puzzle.difficulty,
        );
        await _puzzleService.savePuzzleProgress(progress);

        // Add to local cache
        _progressByDifficulty[puzzle.difficulty] ??= [];
        _progressByDifficulty[puzzle.difficulty]!.add(progress);
      }
    } catch (e) {
      _logger.e('Error initializing puzzle progress: $e');
    }
  }

  /// Complete the current puzzle
  Future<void> _completePuzzle() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final session = _currentSession!;

      // Session state should already be set to solved by the caller

      // Update progress
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        session.puzzle.id,
      );
      if (progress != null) {
        final completedProgress = progress.markCompleted(
          solveTime: session.solveTime,
          hintsUsed: session.hintsUsed,
        );

        await _puzzleService.savePuzzleProgress(completedProgress);

        // Update local cache
        final difficulty = session.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == session.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = completedProgress;
        }
      }

      _logger.i('Puzzle completed: ${session.puzzle.id}');
    } catch (e) {
      _logger.e('Error completing puzzle: $e');
    }
  }

  /// Increment attempts for current puzzle
  Future<void> _incrementAttempts() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        _currentSession!.puzzle.id,
      );
      if (progress != null) {
        final updatedProgress = progress.incrementAttempts();
        await _puzzleService.savePuzzleProgress(updatedProgress);

        // Update local cache
        final difficulty = _currentSession!.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == _currentSession!.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = updatedProgress;
        }
      }
    } catch (e) {
      _logger.e('Error incrementing attempts: $e');
    }
  }

  /// Increment hints used for current puzzle
  Future<void> _incrementHints() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        _currentSession!.puzzle.id,
      );
      if (progress != null) {
        final updatedProgress = progress.incrementHints();
        await _puzzleService.savePuzzleProgress(updatedProgress);

        // Update local cache
        final difficulty = _currentSession!.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == _currentSession!.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = updatedProgress;
        }
      }
    } catch (e) {
      _logger.e('Error incrementing hints: $e');
    }
  }

  /// End the current session
  Future<void> _endCurrentSession({bool abandoned = false}) async {
    if (_currentSession == null) return;

    try {
      final state = abandoned
          ? PuzzleSessionState.abandoned
          : PuzzleSessionState.idle;
      _currentSession = _currentSession!.copyWith(state: state);

      // For immediate cleanup, set session to null directly
      // The delayed approach was causing race conditions
      _currentSession = null;

      // Use scheduleMicrotask to defer notifyListeners() to avoid calling
      // it during the build phase, which causes Flutter errors
      scheduleMicrotask(() {
        if (!_isInitializing && !_isLoading) {
          notifyListeners();
        }
      });

      _logger.i('Puzzle session ended');
    } catch (e) {
      _logger.e('Error ending session: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout')) {
      return 'Loading timed out. Please check your connection and try again.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorString.contains('no puzzles') ||
        errorString.contains('empty')) {
      return 'No puzzles available. Please try again later.';
    } else if (errorString.contains('format') || errorString.contains('json')) {
      return 'Puzzle data is corrupted. Please try again.';
    } else if (errorString.contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    } else {
      return 'Failed to load puzzles. Please try again.';
    }
  }

  @override
  void dispose() {
    _currentSession = null;
    _puzzlesByDifficulty.clear();
    _progressByDifficulty.clear();
    super.dispose();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_progress.dart';
import '../utils/fallback_puzzles.dart';
import 'api_client.dart';

/// Service for managing chess puzzles data and progress.
///
/// Puzzles and per-user progress now come from the self-hosted backend
/// (`/puzzles/*`) instead of a bundled asset file + SharedPreferences.
/// Everything below `loadPuzzles()` / the progress methods (filtering,
/// move validation, hints, "next puzzle" logic) is unchanged — it was
/// already built on top of those two primitives, so it keeps working
/// as-is once they're backend-backed.
class PuzzleService {
  static const String _puzzleProgressPrefix = 'puzzle_progress_';

  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;
  List<PuzzleModel>? _cachedPuzzles;
  final Map<String, PuzzleDifficulty> _difficultyById = {};

  PuzzleModel _puzzleFromBackendJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final theme = json['theme'] as String?;
    return PuzzleModel.fromJson({
      'id': id,
      'fen': json['fen'],
      'solution': List<String>.from(json['solution'] ?? const []),
      'objective': theme != null
          ? 'Find the winning move ($theme)'
          : 'Find the best move',
      'difficulty': json['difficulty'] ?? 'medium',
      'hints': const [],
      'rating': json['rating'] ?? 1200,
      'tags': theme != null ? [theme] : const [],
      'opponentPlaysFirst': false,
    });
  }

  /// Load all puzzles from the backend, with the bundled fallback puzzles
  /// used only if the backend can't be reached (e.g. offline, or the VPS
  /// isn't deployed yet) so puzzle mode never completely breaks.
  Future<List<PuzzleModel>> loadPuzzles() async {
    if (_cachedPuzzles != null) {
      return _cachedPuzzles!;
    }

    try {
      _logger.i('Loading puzzles from backend');
      final result = await _api.get('/puzzles', query: {'limit': 500});
      final puzzlesJson = result['puzzles'] as List;

      if (puzzlesJson.isEmpty) {
        _logger.w('No puzzles returned by backend, using fallback puzzles');
        _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
        return _cachedPuzzles!;
      }

      final List<PuzzleModel> validPuzzles = [];
      int invalidCount = 0;

      for (int i = 0; i < puzzlesJson.length; i++) {
        try {
          final puzzle = _puzzleFromBackendJson(Map<String, dynamic>.from(puzzlesJson[i]));
          if (_validatePuzzleData(puzzle)) {
            validPuzzles.add(puzzle);
            _difficultyById[puzzle.id] = puzzle.difficulty;
          } else {
            invalidCount++;
            _logger.w('Skipping invalid puzzle at index $i: ${puzzle.id}');
          }
        } catch (e) {
          invalidCount++;
          _logger.w('Error parsing puzzle at index $i: $e');
        }
      }

      if (validPuzzles.isEmpty) {
        _logger.w(
          'No valid puzzles found from backend, using fallback puzzles',
        );
        _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
        return _cachedPuzzles!;
      }

      if (invalidCount > 0) {
        _logger.w(
          'Skipped $invalidCount invalid puzzles out of ${puzzlesJson.length}',
        );
      }

      _cachedPuzzles = validPuzzles;
      _logger.i('Successfully loaded ${_cachedPuzzles!.length} valid puzzles');
      return _cachedPuzzles!;
    } catch (e) {
      _logger.e(
        'Error loading puzzles from backend: $e, using fallback puzzles',
      );
      _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
      return _cachedPuzzles!;
    }
  }

  /// Validate puzzle data integrity
  bool _validatePuzzleData(PuzzleModel puzzle) {
    try {
      // Check required fields
      if (puzzle.id.isEmpty) {
        _logger.w('Puzzle has empty ID');
        return false;
      }

      if (puzzle.fen.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty FEN');
        return false;
      }

      if (puzzle.solution.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty solution');
        return false;
      }

      if (puzzle.objective.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty objective');
        return false;
      }

      // Validate FEN format (basic check)
      final fenParts = puzzle.fen.split(' ');
      if (fenParts.length < 4) {
        _logger.w('Puzzle ${puzzle.id} has invalid FEN format');
        return false;
      }

      // Validate solution moves are not empty
      for (final move in puzzle.solution) {
        if (move.trim().isEmpty) {
          _logger.w('Puzzle ${puzzle.id} has empty move in solution');
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.w('Error validating puzzle ${puzzle.id}: $e');
      return false;
    }
  }

  /// Get puzzles filtered by difficulty level
  Future<List<PuzzleModel>> getPuzzlesByDifficulty(
    PuzzleDifficulty difficulty,
  ) async {
    try {
      final allPuzzles = await loadPuzzles();
      final filteredPuzzles = allPuzzles
          .where((puzzle) => puzzle.difficulty == difficulty)
          .toList();

      _logger.i(
        'Found ${filteredPuzzles.length} puzzles for difficulty: ${difficulty.displayName}',
      );

      // Return empty list instead of throwing if no puzzles found
      return filteredPuzzles;
    } catch (e) {
      _logger.e('Error getting puzzles by difficulty $difficulty: $e');
      // Return empty list as fallback instead of rethrowing
      return [];
    }
  }

  /// Get a specific puzzle by its ID
  Future<PuzzleModel?> getPuzzleById(String puzzleId) async {
    try {
      final allPuzzles = await loadPuzzles();
      final puzzle = allPuzzles.where((p) => p.id == puzzleId).firstOrNull;

      if (puzzle != null) {
        _logger.i('Found puzzle: $puzzleId');
      } else {
        _logger.w('Puzzle not found: $puzzleId');
      }

      return puzzle;
    } catch (e) {
      _logger.e('Error getting puzzle by ID $puzzleId: $e');
      return null;
    }
  }

  /// Validate if a move is correct for the current puzzle state
  bool validateMove(
    PuzzleModel puzzle,
    List<String> userMoves,
    String newMove, {
    bool hasOpponentFirstMove = false,
  }) {
    try {
      // Calculate the expected move index in the solution
      // If opponent played first move automatically, offset by 1
      int moveIndex = userMoves.length;
      if (hasOpponentFirstMove) {
        moveIndex += 1; // Account for the opponent's automatic first move
      }

      // Check if we have more moves in the solution
      if (moveIndex >= puzzle.solution.length) {
        _logger.w('No more moves expected in solution for puzzle ${puzzle.id}');
        return false;
      }

      // Check if the move matches the expected solution move
      final bool isCorrect = puzzle.solution[moveIndex] == newMove;

      _logger.i(
        'Move validation for puzzle ${puzzle.id}: $newMove ${isCorrect ? 'correct' : 'incorrect'} (moveIndex: $moveIndex, hasOpponentFirstMove: $hasOpponentFirstMove)',
      );
      return isCorrect;
    } catch (e) {
      _logger.e('Error validating move for puzzle ${puzzle.id}: $e');
      return false;
    }
  }

  /// Check if the puzzle is completely solved
  bool isPuzzleSolved(PuzzleModel puzzle, List<String> userMoves) {
    try {
      final bool solved =
          userMoves.length == puzzle.solution.length &&
          _areMovesCorrect(puzzle, userMoves);

      _logger.i('Puzzle ${puzzle.id} solved status: $solved');
      return solved;
    } catch (e) {
      _logger.e('Error checking if puzzle ${puzzle.id} is solved: $e');
      return false;
    }
  }

  /// Helper method to check if all user moves match the solution
  bool _areMovesCorrect(PuzzleModel puzzle, List<String> userMoves) {
    if (userMoves.length > puzzle.solution.length) {
      return false;
    }

    for (int i = 0; i < userMoves.length; i++) {
      if (userMoves[i] != puzzle.solution[i]) {
        return false;
      }
    }

    return true;
  }

  /// Get the next hint for a puzzle
  static const Map<String, String> _themeHintText = {
    'mate': 'Look for a forced checkmate.',
    'mateIn1': 'There is a checkmate in one move.',
    'mateIn2': 'There is a forced checkmate in two moves.',
    'mateIn3': 'There is a forced checkmate in three moves.',
    'mateIn4': 'There is a forced checkmate in four moves.',
    'fork': 'Look for a move that attacks two pieces at once.',
    'pin': 'One of the opponent\'s pieces is pinned — exploit it.',
    'skewer': 'Look for a skewer — attack a valuable piece through a lesser one.',
    'hangingPiece': 'The opponent has left a piece undefended.',
    'discoveredAttack': 'Moving one piece will reveal an attack from another.',
    'crushing': 'There is a crushing tactical blow available.',
    'advantage': 'Look for the move that wins a decisive advantage.',
  };

  /// Number of hints available for a puzzle — real ones if the puzzle has
  /// hand-written text, otherwise a fixed set of generated hints derived
  /// from the solution itself (see [getNextHint]). Puzzles imported from
  /// the Lichess database (see importPuzzlesFromAsset.js) have `hints: []`
  /// but always have a `solution`, so they still get 3 usable hints
  /// instead of the hint button silently doing nothing.
  int hintCountFor(PuzzleModel puzzle) {
    if (puzzle.hints.isNotEmpty) return puzzle.hints.length;
    return puzzle.solution.isNotEmpty ? 3 : 0;
  }

  /// Builds a hint for a puzzle with no hand-written `hints`, using its
  /// theme tag (if any) and the first solution move — progressively more
  /// specific at each index:
  /// 0. A generic tactical pointer (from the puzzle's theme, if known)
  /// 1. Which square to move the piece from
  /// 2. The full move to play
  String? _generateHint(PuzzleModel puzzle, int hintIndex) {
    if (puzzle.solution.isEmpty) return null;
    final firstMove = puzzle.solution.first;
    if (firstMove.length < 4) return null;
    final from = firstMove.substring(0, 2);
    final to = firstMove.substring(2, 4);

    switch (hintIndex) {
      case 0:
        for (final tag in puzzle.tags) {
          if (_themeHintText.containsKey(tag)) return _themeHintText[tag];
        }
        return 'Look for the strongest tactical move in this position.';
      case 1:
        return 'Look closely at the piece on $from.';
      case 2:
        return 'Play $from to $to.';
      default:
        return null;
    }
  }

  String? getNextHint(PuzzleModel puzzle, int hintIndex) {
    try {
      if (puzzle.hints.isNotEmpty) {
        if (hintIndex < 0 || hintIndex >= puzzle.hints.length) {
          _logger.w('Invalid hint index $hintIndex for puzzle ${puzzle.id}');
          return null;
        }
        final hint = puzzle.hints[hintIndex];
        _logger.i('Providing hint $hintIndex for puzzle ${puzzle.id}');
        return hint;
      }

      // No hand-written hints (e.g. Lichess-sourced puzzles) — generate one.
      final hint = _generateHint(puzzle, hintIndex);
      if (hint != null) {
        _logger.i('Providing generated hint $hintIndex for puzzle ${puzzle.id}');
      } else {
        _logger.w('No generated hint available at index $hintIndex for puzzle ${puzzle.id}');
      }
      return hint;
    } catch (e) {
      _logger.e('Error getting hint for puzzle ${puzzle.id}: $e');
      return null;
    }
  }

  /// Save puzzle progress to the backend (`/puzzles/:id/progress`), with a
  /// local SharedPreferences copy kept as an offline fallback/cache — same
  /// safety behavior as before (never throws; storage failures are logged
  /// and swallowed so solving a puzzle never crashes the app).
  Future<void> savePuzzleProgress(PuzzleProgress progress) async {
    try {
      await _api.post(
        '/puzzles/${progress.puzzleId}/progress',
        body: {
          'solved': progress.completed,
          'attempts': progress.attempts,
        },
      );
      _logger.i(
        'Saved progress for puzzle ${progress.puzzleId} for user ${progress.userId} to backend',
      );
    } catch (e) {
      _logger.e('Error saving puzzle progress to backend: $e');
    }

    // Always keep a local copy too, so getPuzzleProgress has something to
    // show immediately/offline even if the backend call above failed.
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          '$_puzzleProgressPrefix${progress.userId}_${progress.puzzleId}';
      await prefs.setString(key, json.encode(progress.toJson()));
    } catch (e) {
      _logger.e('Error caching puzzle progress locally: $e');
    }
  }

  /// Get puzzle progress — tries the backend first, falls back to the
  /// local cache written by [savePuzzleProgress] if the backend can't be
  /// reached (offline, VPS down, etc).
  Future<PuzzleProgress?> getPuzzleProgress(
    String userId,
    String puzzleId,
  ) async {
    try {
      final result = await _api.get('/puzzles/progress/all');
      final records = result['progress'] as List;
      final match = records.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['puzzleId']?.toString() == puzzleId,
        orElse: () => const {},
      );
      if (match.isNotEmpty) {
        return PuzzleProgress(
          userId: userId,
          puzzleId: puzzleId,
          completed: match['solved'] ?? false,
          completedAt: match['solvedAt'] != null ? DateTime.tryParse(match['solvedAt']) : null,
          hintsUsed: 0,
          attempts: match['attempts'] ?? 0,
          solvedWithoutHints: false,
          difficulty: _difficultyById[puzzleId] ?? PuzzleDifficulty.medium,
          createdAt: match['createdAt'] != null ? DateTime.parse(match['createdAt']) : DateTime.now(),
          updatedAt: match['updatedAt'] != null ? DateTime.parse(match['updatedAt']) : DateTime.now(),
          needsSync: false,
        );
      }
    } catch (e) {
      _logger.e('Error getting puzzle progress from backend for $userId/$puzzleId: $e');
    }

    // Fallback: local cache.
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_puzzleProgressPrefix${userId}_$puzzleId';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        return PuzzleProgress.fromJson(json.decode(jsonString) as Map<String, dynamic>);
      }
    } catch (e) {
      _logger.e('Error reading cached puzzle progress for $userId/$puzzleId: $e');
    }
    return null;
  }

  /// Get completion statistics by difficulty level for a user, from the backend.
  Future<Map<PuzzleDifficulty, int>> getCompletionStats(String userId) async {
    final Map<PuzzleDifficulty, int> stats = {
      for (final d in PuzzleDifficulty.values) d: 0,
    };
    try {
      final result = await _api.get('/puzzles/progress/stats');
      final counts = Map<String, dynamic>.from(result['stats'] ?? {});
      for (final entry in counts.entries) {
        final difficulty = PuzzleDifficulty.values.firstWhere(
          (d) => d.name == entry.key,
          orElse: () => PuzzleDifficulty.medium,
        );
        stats[difficulty] = (entry.value as num).toInt();
      }
      _logger.i('Completion stats for user $userId: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error getting completion stats for user $userId: $e');
      return stats; // all zeros
    }
  }

  /// Get total puzzle count by difficulty level
  Future<Map<PuzzleDifficulty, int>> getPuzzleCountsByDifficulty() async {
    try {
      final allPuzzles = await loadPuzzles();
      final Map<PuzzleDifficulty, int> counts = {};

      // Initialize all difficulties with 0
      for (final difficulty in PuzzleDifficulty.values) {
        counts[difficulty] = 0;
      }

      // Count puzzles by difficulty
      for (final puzzle in allPuzzles) {
        counts[puzzle.difficulty] = (counts[puzzle.difficulty] ?? 0) + 1;
      }

      _logger.i('Puzzle counts by difficulty: $counts');
      return counts;
    } catch (e) {
      _logger.e('Error getting puzzle counts by difficulty: $e');
      return {};
    }
  }

  /// Get all puzzle progress for a user, from the backend.
  Future<List<PuzzleProgress>> getAllUserProgress(String userId) async {
    try {
      final result = await _api.get('/puzzles/progress/all');
      final records = (result['progress'] as List).cast<Map<String, dynamic>>();
      final progressList = records.map((r) {
        final puzzleId = r['puzzleId']?.toString() ?? '';
        return PuzzleProgress(
          userId: userId,
          puzzleId: puzzleId,
          completed: r['solved'] ?? false,
          completedAt: r['solvedAt'] != null ? DateTime.tryParse(r['solvedAt']) : null,
          hintsUsed: 0,
          attempts: r['attempts'] ?? 0,
          solvedWithoutHints: false,
          difficulty: _difficultyById[puzzleId] ?? PuzzleDifficulty.medium,
          createdAt: r['createdAt'] != null ? DateTime.parse(r['createdAt']) : DateTime.now(),
          updatedAt: r['updatedAt'] != null ? DateTime.parse(r['updatedAt']) : DateTime.now(),
          needsSync: false,
        );
      }).toList();

      _logger.i(
        'Retrieved ${progressList.length} progress records for user $userId',
      );
      return progressList;
    } catch (e) {
      _logger.e('Error getting all user progress for $userId: $e');
      return [];
    }
  }

  /// Clear all puzzle progress for a user (useful for testing or reset).
  Future<void> clearUserProgress(String userId) async {
    try {
      await _api.delete('/puzzles/progress');
      _logger.i('Cleared all backend progress for user $userId');
    } catch (e) {
      _logger.e('Error clearing user progress for $userId: $e');
      rethrow;
    }

    // Also clear the local cache written by savePuzzleProgress.
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final userProgressKeys = allKeys
          .where((key) => key.startsWith('$_puzzleProgressPrefix$userId'))
          .toList();
      for (final key in userProgressKeys) {
        await prefs.remove(key);
      }
    } catch (e) {
      _logger.w('Error clearing cached local progress for $userId: $e');
    }
  }

  /// Get the next puzzle in a difficulty level
  Future<PuzzleModel?> getNextPuzzle(
    String userId,
    PuzzleDifficulty difficulty,
    String currentPuzzleId,
  ) async {
    try {
      final puzzles = await getPuzzlesByDifficulty(difficulty);
      final currentIndex = puzzles.indexWhere((p) => p.id == currentPuzzleId);

      if (currentIndex == -1) {
        _logger.w(
          'Current puzzle $currentPuzzleId not found in difficulty ${difficulty.displayName}',
        );
        return puzzles.isNotEmpty ? puzzles.first : null;
      }

      if (currentIndex + 1 < puzzles.length) {
        final nextPuzzle = puzzles[currentIndex + 1];
        _logger.i('Next puzzle for user $userId: ${nextPuzzle.id}');
        return nextPuzzle;
      }

      _logger.i(
        'No more puzzles available in difficulty ${difficulty.displayName}',
      );
      return null;
    } catch (e) {
      _logger.e('Error getting next puzzle: $e');
      return null;
    }
  }

  /// Get the first unsolved puzzle in a difficulty level
  Future<PuzzleModel?> getFirstUnsolvedPuzzle(
    String userId,
    PuzzleDifficulty difficulty,
  ) async {
    try {
      final puzzles = await getPuzzlesByDifficulty(difficulty);

      for (final puzzle in puzzles) {
        final progress = await getPuzzleProgress(userId, puzzle.id);
        if (progress == null || !progress.completed) {
          _logger.i(
            'First unsolved puzzle for user $userId in ${difficulty.displayName}: ${puzzle.id}',
          );
          return puzzle;
        }
      }

      _logger.i(
        'All puzzles completed in difficulty ${difficulty.displayName} for user $userId',
      );
      return null;
    } catch (e) {
      _logger.e('Error getting first unsolved puzzle: $e');
      return null;
    }
  }
}

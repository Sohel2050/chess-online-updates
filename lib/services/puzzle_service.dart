import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chess_app/services/analytics_service.dart';
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
    final id = (json['_id'] ?? json['id'])?.toString() ?? '';
    final theme = json['theme'] as String?;
    return PuzzleModel.fromJson({
      'id': id,
      'fen': json['fen'],
      'solution': List<String>.from(json['solution'] ?? const []),
      'objective': (json['objective'] is String && (json['objective'] as String).isNotEmpty)
          ? json['objective']
          : (theme != null ? 'Find the winning move ($theme)' : 'Find the best move'),
      'difficulty': json['difficulty'] ?? 'medium',
      'hints': json['hints'] is List ? List<String>.from(json['hints']) : const <String>[],
      'rating': json['rating'] ?? 1200,
      'tags': theme != null ? [theme] : const [],
      'opponentPlaysFirst': json['opponentPlaysFirst'] == true,
    });
  }

  // ---- Pagination -------------------------------------------------------
  // The first request loads page 1; "Load More" asks for the following pages.
  // Nothing is limited to the first 2000 puzzles any more: every page the
  // server has can be loaded.
  // Smaller pages: a 2000-puzzle page was slow enough to time out on mobile data,
  // which silently sent users to the 10 bundled fallback puzzles.
  int _pageSize = 500;
  static const Duration _puzzleTimeout = Duration(seconds: 60);

  /// The puzzle list out of the server answer, whatever shape it has
  /// ({puzzles: [...]}, {data: {puzzles: [...]}}, {items: [...]}, ...).
  List _extractPuzzles(Map<String, dynamic> result) {
    for (final key in const ['puzzles', 'items', 'results', 'data']) {
      final v = result[key];
      if (v is List) return v;
      if (v is Map) {
        for (final inner in const ['puzzles', 'items', 'results']) {
          if (v[inner] is List) return v[inner] as List;
        }
      }
    }
    return const [];
  }
  int _pagesLoaded = 0;
  bool _hasMorePuzzles = false;
  bool _loadingMore = false;
  final Set<String> _loadedIds = {};

  /// True while the server probably has more puzzles to load.
  bool get hasMorePuzzles => _hasMorePuzzles;
  bool get isLoadingMore => _loadingMore;

  /// Works out whether another page exists. Uses the server's own hint
  /// (`hasMore` / `total`) when it sends one, otherwise "the page was full".
  bool _serverHasMore(Map<String, dynamic> result, int rawCount) {
    final hasMore = result['hasMore'];
    if (hasMore is bool) return hasMore;
    final total = result['total'];
    if (total is num) return _loadedIds.length < total.toInt();
    // The server may cap the page size below ours: any non-empty page can be
    // followed by another. A page with nothing new ends the list (see loadMorePuzzles).
    return rawCount > 0;
  }

  /// Parses and validates a page of puzzles; invalid ones are skipped and
  /// puzzles already loaded (same id) are never added twice.
  List<PuzzleModel> _parsePage(List puzzlesJson) {
    final List<PuzzleModel> valid = [];
    int invalidCount = 0;
    for (int i = 0; i < puzzlesJson.length; i++) {
      try {
        final puzzle = _puzzleFromBackendJson(Map<String, dynamic>.from(puzzlesJson[i]));
        if (!_validatePuzzleData(puzzle)) {
          invalidCount++;
          _logger.w('Skipping invalid puzzle at index $i: ${puzzle.id}');
          continue;
        }
        if (!_loadedIds.add(puzzle.id)) continue; // duplicate: already loaded
        valid.add(puzzle);
        _difficultyById[puzzle.id] = puzzle.difficulty;
      } catch (e) {
        invalidCount++;
        _logger.w('Error parsing puzzle at index $i: $e');
      }
    }
    if (invalidCount > 0) {
      _logger.w('Skipped $invalidCount invalid puzzles out of ${puzzlesJson.length}');
    }
    return valid;
  }

  /// Load the first page of puzzles from the backend, with the bundled
  /// fallback puzzles used only if the backend can't be reached (e.g. offline,
  /// or the VPS isn't deployed yet) so puzzle mode never completely breaks.
  /// More pages are loaded with [loadMorePuzzles].
  Future<List<PuzzleModel>> loadPuzzles() async {
    if (_cachedPuzzles != null) {
      return _cachedPuzzles!;
    }
    // The server just failed: do not hammer it again for every difficulty list
    // (each one calls this method). The Retry button resets this.
    if (_offlinePuzzles != null &&
        _lastFailAt != null &&
        DateTime.now().difference(_lastFailAt!) < const Duration(seconds: 20)) {
      return _offlinePuzzles!;
    }

    // Try the normal page size first, then a smaller one (a server that caps the
    // page size, or a slow connection, may refuse / time out on the big one).
    // Different servers page differently (the first request used to be just
    // ?limit=N), so a few query shapes are tried until one returns puzzles.
    final attempts = <Map<String, dynamic>>[
      {'limit': 500},
      {'limit': 100},
      {'limit': 100, 'page': 1},
      <String, dynamic>{},
    ];
    for (var i = 0; i < attempts.length; i++) {
      final query = attempts[i];
      final size = (query['limit'] as int?) ?? 500;
      try {
        _logger.i('Loading puzzles from backend (query $query)');
        _loadedIds.clear();
        _pageSize = size;
        final result = await _api.get(
          '/puzzles',
          query: query.isEmpty ? null : query,
          timeout: i == 0 ? _puzzleTimeout : const Duration(seconds: 30),
        );
        final puzzlesJson = _extractPuzzles(result);
        if (puzzlesJson.isEmpty) {
          lastLoadError =
              'The server sent an empty puzzle list (answer keys: ${result.keys.join(', ')}).';
          continue;
        }
        final validPuzzles = _parsePage(puzzlesJson);
        if (validPuzzles.isEmpty) {
          lastLoadError = 'The server sent puzzles in an unknown format.';
          continue;
        }
        _cachedPuzzles = validPuzzles;
        _pagesLoaded = 1;
        _hasMorePuzzles = _serverHasMore(Map<String, dynamic>.from(result), puzzlesJson.length);
        usingOfflinePuzzles = false;
        lastLoadError = null;
        _offlinePuzzles = null;
        _logger.i('Successfully loaded ${_cachedPuzzles!.length} valid puzzles');
        return _cachedPuzzles!;
      } on ApiException catch (e) {
        lastLoadError = 'Server answered ${e.statusCode}: ${e.message}';
        _logger.e('Error loading puzzles from backend: $e');
      } catch (e) {
        lastLoadError = 'Could not reach the server ($e).';
        _logger.e('Error loading puzzles from backend: $e');
      }
    }

    // Server failed: use the puzzles bundled inside the app (hundreds), and only
    // the tiny built-in list if even that fails. Not cached, so Retry asks again.
    _loadedIds.clear();
    _hasMorePuzzles = false;
    usingOfflinePuzzles = true;
    _lastFailAt = DateTime.now();
    _offlinePuzzles = await _loadBundledPuzzles();
    return _offlinePuzzles!;
  }

  /// Puzzles from assets/puzzles/puzzles.json (same format as the server's).
  Future<List<PuzzleModel>> _loadBundledPuzzles() async {
    try {
      final raw = await rootBundle.loadString('assets/puzzles/puzzles.json');
      final decoded = jsonDecode(raw);
      final list = decoded is Map ? decoded['puzzles'] : decoded;
      if (list is List) {
        final valid = _parsePage(list);
        if (valid.isNotEmpty) return valid;
      }
    } catch (e) {
      _logger.e('Could not read the bundled puzzles: $e');
    }
    return FallbackPuzzles.getFallbackPuzzles();
  }

  /// Set when the server could not be used; shown to the user with a Retry.
  bool usingOfflinePuzzles = false;
  String? lastLoadError;
  List<PuzzleModel>? _offlinePuzzles;
  DateTime? _lastFailAt;

  /// Forgets a failed attempt so the next load asks the server again.
  void resetOfflineState() {
    _offlinePuzzles = null;
    _lastFailAt = null;
    usingOfflinePuzzles = false;
  }

  /// Loads the next page and appends it. Returns how many NEW puzzles were
  /// added (0 when there is nothing more). Throws on a server/network error,
  /// leaving everything already loaded untouched so the user can try again.
  Future<int> loadMorePuzzles() async {
    final cached = _cachedPuzzles;
    if (cached == null || !_hasMorePuzzles || _loadingMore) return 0;
    _loadingMore = true;
    try {
      final nextPage = _pagesLoaded + 1;
      final result = await _api.get('/puzzles', query: {'limit': _pageSize, 'page': nextPage, 'skip': cached.length, 'offset': cached.length}, timeout: _puzzleTimeout);
      final puzzlesJson = _extractPuzzles(result);
      final added = _parsePage(puzzlesJson);
      cached.addAll(added);
      _pagesLoaded = nextPage;
      // An empty page, or a page with nothing new (a server that ignores the
      // page number sends the same puzzles again), means we reached the end.
      _hasMorePuzzles = added.isNotEmpty &&
          _serverHasMore(Map<String, dynamic>.from(result), puzzlesJson.length);
      _logger.i('Loaded page $nextPage: ${added.length} new puzzles (total ${cached.length})');
      return added.length;
    } finally {
      _loadingMore = false;
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
        final localDone = await _localProgress(userId, puzzleId);
        if (localDone != null && localDone.completed && match['solved'] != true) {
          return localDone;
        }
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

  Future<PuzzleProgress?> _localProgress(String userId, String puzzleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_puzzleProgressPrefix${userId}_$puzzleId');
      if (raw == null) return null;
      return PuzzleProgress.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
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
    final Map<String, PuzzleProgress> byId = {};

    // 1) Local copy first: it works offline and for guests.
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '$_puzzleProgressPrefix${userId}_';
      for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        try {
          final raw = prefs.getString(key);
          if (raw == null) continue;
          final p = PuzzleProgress.fromJson(
            json.decode(raw) as Map<String, dynamic>,
          );
          final known = _difficultyById[p.puzzleId];
          byId[p.puzzleId] = known != null ? p.copyWith(difficulty: known) : p;
        } catch (e) {
          _logger.w('Skipping unreadable cached progress $key: $e');
        }
      }
    } catch (e) {
      _logger.e('Error reading cached progress for $userId: $e');
    }

    // 2) Backend on top. A solved puzzle stays solved if either side says so.
    try {
      final result = await _api.get('/puzzles/progress/all');
      final records = (result['progress'] as List).cast<Map<String, dynamic>>();
      for (final r in records) {
        final puzzleId = r['puzzleId']?.toString() ?? '';
        if (puzzleId.isEmpty) continue;
        final remote = PuzzleProgress(
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
        final local = byId[puzzleId];
        if (local != null && local.completed && !remote.completed) continue;
        byId[puzzleId] = remote;
      }
    } catch (e) {
      _logger.e('Error getting all user progress for $userId (using local copy): $e');
    }

    _logger.i('Retrieved ${byId.length} progress records for user $userId');
    return byId.values.toList();
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

  /// The user's LOCAL calendar date as "YYYY-MM-DD". Using the device date
  /// (not UTC) means every user gets "their" day, whatever the timezone.
  static String localDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Today's daily puzzle (same for everyone on the same date) plus whether
  /// this user already solved it. Returns null if it can't be loaded.
  Future<DailyPuzzleInfo?> getDailyPuzzle() async {
    try {
      final dateKey = localDateKey();
      final result = await _api.get('/puzzles/daily', query: {'date': dateKey});
      final raw = result['puzzle'];
      if (raw == null) return null;
      final puzzle = _puzzleFromBackendJson(Map<String, dynamic>.from(raw as Map));
      if (!_validatePuzzleData(puzzle)) return null;
      _difficultyById[puzzle.id] = puzzle.difficulty;
      return DailyPuzzleInfo(
        dateKey: dateKey,
        puzzle: puzzle,
        solved: result['solved'] == true,
      );
    } catch (e) {
      _logger.e('Error loading daily puzzle: $e');
      return null;
    }
  }

  /// Sends the player's own moves to the server, which checks them against the puzzle's
  /// solution and only then counts the solve (progress, daily puzzle, streak and mission).
  /// Never throws; returns true when the server accepted the moves.
  Future<bool> solvePuzzle(String puzzleId, List<String> userMoves, String dateKey) async {
    try {
      await _api.post(
        '/puzzles/$puzzleId/solve',
        body: {'moves': userMoves, 'date': dateKey},
      );
      AnalyticsService.instance.track('puzzle_result', {'kind': 'daily', 'result': 'solved'});
      return true;
    } catch (e) {
      _logger.e('Error saving puzzle solve: $e');
      return false;
    }
  }

  /// Tells the backend the user solved today's daily puzzle. Never throws.
  /// (Older call: the server remembers it but gives no streak/mission credit. Use [solvePuzzle].)
  Future<bool> markDailySolved(String dateKey, String puzzleId) async {
    try {
      await _api.post(
        '/puzzles/daily/solve',
        body: {'date': dateKey, 'puzzleId': puzzleId},
      );
      return true;
    } catch (e) {
      _logger.e('Error saving daily puzzle solve: $e');
      return false;
    }
  }
}

/// Today's daily puzzle and the user's solved state.
class DailyPuzzleInfo {
  final String dateKey;
  final PuzzleModel puzzle;
  final bool solved;
  const DailyPuzzleInfo({
    required this.dateKey,
    required this.puzzle,
    required this.solved,
  });
}

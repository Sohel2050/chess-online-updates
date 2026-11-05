import 'package:logger/logger.dart';
import 'package:flutter_chess_app/services/analytics_service.dart';
import '../models/puzzle_model.dart';
import 'api_client.dart';

/// A puzzle the server served for rated play. The server remembers it as an "attempt";
/// the result must be reported for that attempt (see [RatedPuzzleService.submitResult]).
class RatedPuzzle {
  final String attemptId;
  final PuzzleModel puzzle;
  final int userRating;
  final bool provisional;
  const RatedPuzzle({
    required this.attemptId,
    required this.puzzle,
    required this.userRating,
    required this.provisional,
  });
}

class RatedResult {
  final bool solved;
  final int ratingBefore;
  final int ratingAfter;
  final bool provisional;
  const RatedResult({
    required this.solved,
    required this.ratingBefore,
    required this.ratingAfter,
    required this.provisional,
  });
  int get delta => ratingAfter - ratingBefore;
}

class PuzzleThemeStat {
  final String theme;
  final int count; // puzzles available
  final int attempts; // this user's finished rated attempts
  final int solved;
  const PuzzleThemeStat({
    required this.theme,
    required this.count,
    required this.attempts,
    required this.solved,
  });
  double get successRate => attempts == 0 ? 0 : solved / attempts;
}

class PuzzleRatingInfo {
  final int rating;
  final bool provisional;
  final int rated;
  final List<int> history; // rating after each of the last 30 rated puzzles, oldest first
  const PuzzleRatingInfo({
    required this.rating,
    required this.provisional,
    required this.rated,
    required this.history,
  });
}

/// Rated puzzles and practice by theme (roadmap item 8). Talks to /puzzles/rated/*, /puzzles/rating, /puzzles/themes.
/// Methods never throw: they return null / empty on any error.
class RatedPuzzleService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  /// "mateIn2" -> "Mate in 2", "hangingPiece" -> "Hanging piece".
  static String prettyTheme(String id) {
    final spaced = id
        .replaceAllMapped(RegExp(r'([a-z])([A-Z0-9])'), (m) => '${m[1]} ${m[2]}')
        .toLowerCase();
    if (spaced.isEmpty) return id;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  PuzzleModel _puzzleFromJson(Map<String, dynamic> json) {
    final themes = List<String>.from(json['themes'] ?? const []);
    final theme = themes.isNotEmpty ? themes.first : json['theme'] as String?;
    return PuzzleModel.fromJson({
      'id': json['_id']?.toString() ?? '',
      'fen': json['fen'],
      'solution': List<String>.from(json['solution'] ?? const []),
      'objective': theme != null
          ? 'Find the winning move (${prettyTheme(theme)})'
          : 'Find the best move',
      'difficulty': json['difficulty'] ?? 'medium',
      'hints': const [],
      'rating': json['rating'] ?? 1200,
      'tags': themes.isNotEmpty ? themes : (theme != null ? [theme] : const []),
      'opponentPlaysFirst': false,
    });
  }

  /// Next rated puzzle near the user's rating, optionally only [theme].
  /// An unfinished earlier puzzle is counted as failed by the server.
  Future<RatedPuzzle?> nextPuzzle({String? theme}) async {
    try {
      final result = await _api.get(
        '/puzzles/rated/next',
        query: theme == null ? null : {'theme': theme},
      );
      final raw = result['puzzle'];
      final attemptId = result['attemptId']?.toString();
      if (raw == null || attemptId == null) return null;
      final user = Map<String, dynamic>.from(result['user'] ?? const {});
      return RatedPuzzle(
        attemptId: attemptId,
        puzzle: _puzzleFromJson(Map<String, dynamic>.from(raw as Map)),
        userRating: (user['puzzleRating'] as num?)?.toInt() ?? 1200,
        provisional: user['provisional'] == true,
      );
    } catch (e) {
      _logger.e('nextPuzzle failed: $e');
      return null;
    }
  }

  /// Reports the result. For [solved] = true the server needs the player's own moves and the local date.
  Future<RatedResult?> submitResult(
    String attemptId, {
    required bool solved,
    List<String> moves = const [],
    String? dateKey,
  }) async {
    try {
      final result = await _api.post(
        '/puzzles/rated/$attemptId/result',
        body: {'solved': solved, 'moves': moves, if (dateKey != null) 'date': dateKey},
      );
      AnalyticsService.instance.track('puzzle_result', {'kind': 'rated', 'result': solved ? 'solved' : 'failed'});
      return RatedResult(
        solved: result['solved'] == true,
        ratingBefore: (result['ratingBefore'] as num).toInt(),
        ratingAfter: (result['ratingAfter'] as num).toInt(),
        provisional: result['provisional'] == true,
      );
    } catch (e) {
      _logger.e('submitResult failed: $e');
      return null;
    }
  }

  Future<PuzzleRatingInfo?> getRating() async {
    try {
      final r = await _api.get('/puzzles/rating');
      final history = (r['history'] as List? ?? const [])
          .map((h) => ((h as Map)['rating'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      return PuzzleRatingInfo(
        rating: (r['rating'] as num).toInt(),
        provisional: r['provisional'] == true,
        rated: (r['rated'] as num?)?.toInt() ?? 0,
        history: history,
      );
    } catch (e) {
      _logger.e('getRating failed: $e');
      return null;
    }
  }

  Future<List<PuzzleThemeStat>> getThemes() async {
    try {
      final r = await _api.get('/puzzles/themes');
      return (r['themes'] as List? ?? const []).map((t) {
        final m = Map<String, dynamic>.from(t as Map);
        return PuzzleThemeStat(
          theme: m['theme'].toString(),
          count: (m['count'] as num?)?.toInt() ?? 0,
          attempts: (m['attempts'] as num?)?.toInt() ?? 0,
          solved: (m['solved'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      _logger.e('getThemes failed: $e');
      return [];
    }
  }
}

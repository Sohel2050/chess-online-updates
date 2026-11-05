import 'dart:convert';
import 'dart:math' as math;

import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_chess_app/services/game_analyzer.dart';

/// Quality of one move, judged by how much the mover's position got worse.
enum MoveQuality { best, good, inaccuracy, mistake, blunder }

extension MoveQualityX on MoveQuality {
  String get label {
    switch (this) {
      case MoveQuality.best:
        return 'Best';
      case MoveQuality.good:
        return 'Good';
      case MoveQuality.inaccuracy:
        return 'Inaccuracy';
      case MoveQuality.mistake:
        return 'Mistake';
      case MoveQuality.blunder:
        return 'Blunder';
    }
  }

  /// Chess-annotation symbol ('' for best/good).
  String get mark {
    switch (this) {
      case MoveQuality.inaccuracy:
        return '?!';
      case MoveQuality.mistake:
        return '?';
      case MoveQuality.blunder:
        return '??';
      default:
        return '';
    }
  }
}

/// Engine verdict for ONE played move.
class ReviewedMove {
  final int ply; // 0-based index into the game's move list
  final bool white; // true if White made this move
  final int? cpBefore; // centipawns, White's point of view, before the move
  final int? cpAfter; // centipawns, White's point of view, after the move
  final String? bestUci; // engine's best move in the position before the move
  final String playedUci; // the move that was played ('' if unknown)
  final MoveQuality quality;
  final int loss; // centipawns lost by the mover (>= 0)
  final double accuracy; // 0-100 for this move

  const ReviewedMove({
    required this.ply,
    required this.white,
    required this.cpBefore,
    required this.cpAfter,
    required this.bestUci,
    required this.playedUci,
    required this.quality,
    required this.loss,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'p': ply,
        'w': white,
        'b': cpBefore,
        'a': cpAfter,
        'u': bestUci,
        'm': playedUci,
        'q': quality.index,
        'l': loss,
        'c': accuracy,
      };

  factory ReviewedMove.fromJson(Map<String, dynamic> j) => ReviewedMove(
        ply: j['p'] as int,
        white: j['w'] as bool,
        cpBefore: j['b'] as int?,
        cpAfter: j['a'] as int?,
        bestUci: j['u'] as String?,
        playedUci: (j['m'] as String?) ?? '',
        quality: MoveQuality.values[(j['q'] as int).clamp(0, MoveQuality.values.length - 1)],
        loss: j['l'] as int,
        accuracy: (j['c'] as num).toDouble(),
      );
}

/// Totals for one side.
class SideSummary {
  final double accuracy; // 0-100
  final int best, good, inaccuracies, mistakes, blunders;
  const SideSummary(this.accuracy, this.best, this.good, this.inaccuracies, this.mistakes, this.blunders);
}

/// The full result of reviewing one game.
class GameReviewResult {
  /// Evaluation (White's view) of every position: index 0 = start, index n = after move n.
  final List<int?> evals;
  final List<ReviewedMove> moves;
  const GameReviewResult(this.evals, this.moves);

  SideSummary summary({required bool white}) {
    final mine = moves.where((m) => m.white == white).toList();
    if (mine.isEmpty) return const SideSummary(100, 0, 0, 0, 0, 0);
    int count(MoveQuality q) => mine.where((m) => m.quality == q).length;
    final acc = mine.map((m) => m.accuracy).reduce((a, b) => a + b) / mine.length;
    return SideSummary(
      acc,
      count(MoveQuality.best),
      count(MoveQuality.good),
      count(MoveQuality.inaccuracy),
      count(MoveQuality.mistake),
      count(MoveQuality.blunder),
    );
  }

  /// Ply of the single biggest mistake by [white] side (or null if none >= inaccuracy).
  ReviewedMove? worstMove({required bool white}) {
    ReviewedMove? worst;
    for (final m in moves) {
      if (m.white != white || m.quality.index < MoveQuality.inaccuracy.index) continue;
      if (worst == null || m.loss > worst.loss) worst = m;
    }
    return worst;
  }

  String encode() => jsonEncode({
        'v': 1,
        'e': evals,
        'm': moves.map((m) => m.toJson()).toList(),
      });

  /// Returns null if [raw] is missing, corrupt or from another format version.
  static GameReviewResult? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['v'] != 1) return null;
      final evals = (j['e'] as List).map((e) => e as int?).toList();
      final moves = (j['m'] as List)
          .map((e) => ReviewedMove.fromJson(e as Map<String, dynamic>))
          .toList();
      return GameReviewResult(evals, moves);
    } catch (_) {
      return null;
    }
  }
}

/// Pure review maths (no engine, no Flutter) so it can be unit-tested.
class ReviewRules {
  /// Win chance (0-100) of the side with score [cp] (its own point of view).
  /// Same curve Lichess uses.
  static double winPercent(int cp) {
    final c = cp.clamp(-1000, 1000).toDouble();
    return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * c)) - 1);
  }

  /// Accuracy (0-100) of one move from the mover's win chance before and after it.
  static double moveAccuracy(double winBefore, double winAfter) {
    final drop = math.max(0.0, winBefore - winAfter);
    final a = 103.1668 * math.exp(-0.04354 * drop) - 3.1669;
    return a.clamp(0.0, 100.0);
  }

  /// Quality from the centipawns lost. Uses the same limits as the live coach
  /// ([CoachRules.verdict]): 70 / 150 / 300.
  static MoveQuality classify(int loss, {required bool playedEngineMove}) {
    if (playedEngineMove || loss <= 10) return MoveQuality.best;
    if (loss < 70) return MoveQuality.good;
    if (loss < 150) return MoveQuality.inaccuracy;
    if (loss < 300) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  /// Judges one move. [cpBefore]/[cpAfter] are from White's point of view.
  /// Unknown scores (engine gave nothing) count as a neutral "good" move.
  static ReviewedMove judge({
    required int ply,
    required bool white,
    required int? cpBefore,
    required int? cpAfter,
    required String? bestUci,
    required String playedUci,
  }) {
    if (cpBefore == null || cpAfter == null) {
      return ReviewedMove(
        ply: ply,
        white: white,
        cpBefore: cpBefore,
        cpAfter: cpAfter,
        bestUci: bestUci,
        playedUci: playedUci,
        quality: MoveQuality.good,
        loss: 0,
        accuracy: 80,
      );
    }
    final before = white ? cpBefore : -cpBefore;
    final after = white ? cpAfter : -cpAfter;
    final loss = math.max(0, before - after);
    final played = bestUci != null && bestUci.isNotEmpty && playedUci == bestUci;
    final quality = classify(loss, playedEngineMove: played);
    final acc = played ? 100.0 : moveAccuracy(winPercent(before), winPercent(after));
    return ReviewedMove(
      ply: ply,
      white: white,
      cpBefore: cpBefore,
      cpAfter: cpAfter,
      bestUci: bestUci,
      playedUci: playedUci,
      quality: quality,
      loss: loss,
      accuracy: acc,
    );
  }

  /// Bar fill for White, 0.0 (Black winning) .. 1.0 (White winning). Null score = even.
  static double barWhite(int? cpWhite) => cpWhite == null ? 0.5 : winPercent(cpWhite) / 100;

  /// Short text for the score ("+0.45", "-1.20", "M3" style is not available: mate is +/-10000-n).
  static String scoreText(int? cpWhite) {
    if (cpWhite == null) return '–';
    if (cpWhite.abs() >= 9000) {
      final n = 10000 - cpWhite.abs();
      return '${cpWhite > 0 ? '+' : '-'}M$n';
    }
    final v = (cpWhite / 100).toStringAsFixed(2);
    return cpWhite > 0 ? '+$v' : v;
  }
}

/// Runs the engine over a whole game.
class GameReviewer {
  final GameAnalyzer _analyzer = GameAnalyzer();
  bool _cancelled = false;

  /// [moves] are the played moves in order; [initialFen] is the start position.
  /// [onProgress] receives 0.0 .. 1.0. Returns null if the engine could not
  /// start or the review was cancelled.
  Future<GameReviewResult?> review({
    required String initialFen,
    required List<bishop.Move> moves,
    List<String>? uciMoves, // the same moves as "e2e4" text (the saved game's move list), same order
    void Function(double progress)? onProgress,
    int moveTimeMs = 200,
  }) async {
    if (!await _analyzer.start()) return null;
    try {
      // 1. positions + the UCI text of every played move
      final game = bishop.Game(fen: initialFen);
      final fens = <String>[game.fen];
      final played = <String>[];
      for (var i = 0; i < moves.length; i++) {
        final m = moves[i];
        played.add(uciMoves != null && i < uciMoves.length ? uciMoves[i].toLowerCase() : '');
        game.makeMove(m);
        fens.add(game.fen);
      }

      // 2. one engine run per position
      final evals = <int?>[];
      final bests = <String?>[];
      for (var i = 0; i < fens.length; i++) {
        if (_cancelled) return null;
        final e = await _analyzer.evaluate(fens[i], moveTimeMs: moveTimeMs);
        evals.add(e.cpWhite ?? _terminalScore(fens[i]));
        bests.add(e.bestUci);
        onProgress?.call((i + 1) / fens.length);
      }
      if (_cancelled) return null;

      // 3. judge every move
      final reviewed = <ReviewedMove>[];
      for (var i = 0; i < moves.length; i++) {
        reviewed.add(ReviewRules.judge(
          ply: i,
          white: CoachRules.whiteToMove(fens[i]),
          cpBefore: evals[i],
          cpAfter: evals[i + 1],
          bestUci: bests[i],
          playedUci: played[i],
        ));
      }
      return GameReviewResult(evals, reviewed);
    } finally {
      _analyzer.dispose();
    }
  }

  void cancel() {
    _cancelled = true;
    _analyzer.dispose();
  }

  /// Score of a finished position (the engine returns nothing there).
  /// Checkmate: the side to move lost. Anything else finished: draw.
  int? _terminalScore(String fen) {
    try {
      final g = bishop.Game(fen: fen);
      if (!g.gameOver) return null;
      // A won game in a finished position = checkmate: the side to move lost.
      if (g.result is bishop.WonGame) return CoachRules.whiteToMove(fen) ? -10000 : 10000;
      return 0;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:async';
import 'package:bishop/bishop.dart' as bishop;
import 'package:stockfish/stockfish.dart';

/// Engine result for one position. [cpWhite] is the score in centipawns from
/// WHITE's point of view (mate is mapped to +/-10000 minus the distance).
class PositionEval {
  final int? cpWhite;
  final String? bestUci; // e.g. "g1f3"
  const PositionEval(this.cpWhite, this.bestUci);
}

/// A live warning about the move the player just made.
class CoachWarning {
  final String mark; // '??' blunder, '?' mistake, '?!' inaccuracy
  final String betterUci; // the engine's better move ('' if unknown)
  const CoachWarning(this.mark, this.betterUci);

  String get label =>
      mark == '??' ? 'Blunder' : (mark == '?' ? 'Mistake' : 'Inaccuracy');

  String get text {
    final better = betterUci.length >= 4 ? ' Better: ${CoachRules.fmtUci(betterUci)}' : '';
    return '$label ($mark).$better';
  }
}

class CoachRules {
  /// Compares the score before and after a move, from the mover's side.
  /// Ignored when the mover was already lost or is still clearly winning.
  static String? verdict(int? beforeWhite, int? afterWhite, bool moverIsWhite) {
    if (beforeWhite == null || afterWhite == null) return null;
    final before = moverIsWhite ? beforeWhite : -beforeWhite;
    final after = moverIsWhite ? afterWhite : -afterWhite;
    if (before <= -700 || after >= 700) return null;
    final loss = before - after;
    if (loss >= 300) return '??';
    if (loss >= 150) return '?';
    if (loss >= 70) return '?!';
    return null;
  }

  static String fmtUci(String u) =>
      '${u.substring(0, 2)} \u2192 ${u.substring(2, 4)}${u.length > 4 ? '=${u[4].toUpperCase()}' : ''}';

  static bool whiteToMove(String fen) {
    final parts = fen.split(' ');
    return parts.length < 2 || parts[1] == 'w';
  }
}

/// Reads Stockfish output lines and keeps the latest score + best move.
class EngineLineParser {
  bool whiteToMove = true;
  int? cpWhite;
  String? best;

  void reset(bool whiteToMove) {
    this.whiteToMove = whiteToMove;
    cpWhite = null;
    best = null;
  }

  /// Feed raw engine output. Returns true once a "bestmove" line was seen.
  bool feed(String chunk) {
    var finished = false;
    for (final line in chunk.split('\n')) {
      final l = line.trim();
      if (l.startsWith('info ') && l.contains(' score ')) {
        if (l.contains(' multipv ') && !l.contains(' multipv 1 ')) continue;
        final m = RegExp(r'score (cp|mate) (-?\d+)').firstMatch(l);
        if (m != null) {
          final v = int.parse(m.group(2)!);
          final stm = m.group(1) == 'cp' ? v : (v > 0 ? 10000 - v : -10000 - v);
          cpWhite = whiteToMove ? stm : -stm;
        }
      } else if (l.startsWith('bestmove')) {
        final parts = l.split(RegExp(r'\s+'));
        if (parts.length > 1 &&
            RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(parts[1])) {
          best = parts[1];
        }
        finished = true;
      }
    }
    return finished;
  }
}

/// Own Stockfish instance, for ONLINE training games (the game provider only
/// starts its engine for games against the computer, and the package allows
/// just one engine at a time). [start] returns false if it cannot be created.
class GameAnalyzer {
  Stockfish? _sf;
  StreamSubscription<String>? _sub;
  Completer<void>? _done;
  final EngineLineParser _parser = EngineLineParser();
  bool _cancelled = false;
  bool _busy = false;

  bool get isRunning => _sf != null && !_cancelled;

  Future<bool> start() async {
    try {
      _sf = Stockfish();
      var tries = 0;
      while (_sf!.state.value != StockfishState.ready && tries < 40) {
        await Future.delayed(const Duration(milliseconds: 250));
        tries++;
      }
      if (_sf!.state.value != StockfishState.ready) {
        dispose();
        return false;
      }
      _sub = _sf!.stdout.listen((chunk) {
        if (_parser.feed(chunk) && _done != null && !_done!.isCompleted) {
          _done!.complete();
        }
      });
      _sf!.stdin = 'setoption name Threads value 1';
      _sf!.stdin = 'setoption name Hash value 16';
      return true;
    } catch (_) {
      dispose();
      return false;
    }
  }

  Future<PositionEval> evaluate(String fen, {int moveTimeMs = 300}) async {
    if (_sf == null || _cancelled || bishop.Game(fen: fen).gameOver) {
      return const PositionEval(null, null);
    }
    _parser.reset(CoachRules.whiteToMove(fen));
    _done = Completer<void>();
    _sf!.stdin = 'position fen $fen';
    _sf!.stdin = 'go movetime $moveTimeMs';
    await _done!.future.timeout(
      Duration(milliseconds: moveTimeMs + 3000),
      onTimeout: () async {
        _sf?.stdin = 'stop';
        // Wait for the engine's answer to "stop" so a late "bestmove" cannot
        // end the NEXT evaluation too early and give a wrong warning.
        await _done!.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () {},
        );
      },
    );
    return PositionEval(_parser.cpWhite, _parser.best);
  }

  /// Warning for the move that led from [fenBefore] to [fenAfter], or null.
  Future<CoachWarning?> checkMove(String fenBefore, String fenAfter) async {
    if (_busy || _sf == null) return null;
    _busy = true;
    try {
      final a = await evaluate(fenBefore);
      final b = await evaluate(fenAfter);
      if (_cancelled) return null;
      final mark = CoachRules.verdict(a.cpWhite, b.cpWhite, CoachRules.whiteToMove(fenBefore));
      return mark == null ? null : CoachWarning(mark, a.bestUci ?? '');
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _cancelled = true;
    if (_done != null && !_done!.isCompleted) _done!.complete();
    _sub?.cancel();
    _sub = null;
    try {
      _sf?.stdin = 'stop';
      _sf?.dispose();
    } catch (_) {}
    _sf = null;
  }
}

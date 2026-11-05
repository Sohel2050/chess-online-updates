import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';

import '../data/learn_content.dart';

/// Small helper for the Learn screens (roadmap item 11): a bishop game that is rebuilt from a list of UCI moves,
/// so "undo" / "go back" never depends on bishop's own undo API.
class UciGame {
  final String? startFen;
  late bishop.Game game;
  final List<String> played = [];

  UciGame({this.startFen}) {
    _reset();
  }

  void _reset() {
    game = startFen == null
        ? bishop.Game(variant: bishop.Variant.standard())
        : bishop.Game(variant: bishop.Variant.standard(), fen: startFen);
    played.clear();
  }

  /// 0 = White to move, 1 = Black to move.
  int get turn => game.state.turn;

  bool get isOver => game.state.result != null;

  /// Plays a move such as "e2e4" or "e7e8q". Returns false (and changes nothing) if it is illegal.
  bool play(String uci) {
    if (!game.makeMoveString(uci)) return false;
    played.add(uci);
    return true;
  }

  /// Starts again and replays [moves]. Stops at the first illegal move.
  void rebuild(List<String> moves) {
    _reset();
    for (final m in moves) {
      if (!play(m)) break;
    }
  }

  void undo() {
    if (played.isEmpty) return;
    rebuild(played.sublist(0, played.length - 1));
  }

  void reset() => rebuild(const []);

  SquaresState squares(int player) => game.squaresState(player);
}

const _firstMoveNames = {
  'e2e4': "King's Pawn Game",
  'd2d4': "Queen's Pawn Game",
};

/// Name of the opening reached by [uci] (longest matching prefix of the shared table), or null.
String? openingNameFor(List<String> uci) {
  if (uci.isEmpty) return null;
  String? best;
  var bestLen = 0;
  for (final e in kOpeningNames) {
    if (e.moves.length <= uci.length && e.moves.length > bestLen) {
      var ok = true;
      for (var i = 0; i < e.moves.length; i++) {
        if (e.moves[i] != uci[i]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        best = e.name;
        bestLen = e.moves.length;
      }
    }
  }
  return best ?? _firstMoveNames[uci.first];
}

bool _startsWith(List<String> list, List<String> prefix) {
  if (prefix.length > list.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (list[i] != prefix[i]) return false;
  }
  return true;
}

/// A book continuation: the next move, its SAN, and the trainer lines that contain it.
class BookMove {
  final String uci;
  final String san;
  final List<OpeningLine> lines = [];
  BookMove(this.uci, this.san);
}

/// All next moves after [played] that appear in at least one trainer line.
List<BookMove> bookMovesAfter(List<String> played) {
  final out = <String, BookMove>{};
  for (final line in kOpeningLines) {
    if (line.uci.length > played.length && _startsWith(line.uci, played)) {
      final next = line.uci[played.length];
      final entry = out.putIfAbsent(next, () => BookMove(next, line.san[played.length]));
      entry.lines.add(line);
    }
  }
  return out.values.toList();
}

/// Trainer lines that start with [played] (including lines that are already completed by it).
List<OpeningLine> linesThrough(List<String> played) {
  return kOpeningLines.where((l) => _startsWith(l.uci, played)).toList();
}

/// "1. e4 e5 2. Nf3" style text from a list of SAN moves; [upTo] limits how many plies are shown.
String sanText(List<String> san, {int? upTo}) {
  final n = upTo ?? san.length;
  final b = StringBuffer();
  for (var i = 0; i < n && i < san.length; i++) {
    if (i % 2 == 0) b.write('${i ~/ 2 + 1}. ');
    b.write(san[i]);
    if (i != n - 1 && i != san.length - 1) b.write(' ');
  }
  return b.toString();
}

/// SAN for the played moves where they are known from a trainer line, otherwise the UCI text.
List<String> labelsFor(List<String> played) {
  final out = <String>[];
  for (var i = 0; i < played.length; i++) {
    final prefix = played.sublist(0, i + 1);
    String? label;
    for (final line in kOpeningLines) {
      if (_startsWith(line.uci, prefix)) {
        label = line.san[i];
        break;
      }
    }
    out.add(label ?? played[i]);
  }
  return out;
}

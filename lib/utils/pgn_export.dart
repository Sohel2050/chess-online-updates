/// Builds a PGN text (standard chess game file) from a list of SAN moves. Pure Dart, no chess library needed.
class PgnExport {
  static const String _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// [result] is the app's result for the saved player: win / loss / draw. [playerColor] is 'white' or 'black' ('' = unknown).
  static String build({
    required List<String> sanMoves,
    required String myName,
    required String opponentName,
    required String playerColor,
    required String result,
    required DateTime date,
    String? initialFen,
    String event = 'Online game',
  }) {
    final iAmBlack = playerColor == 'black';
    final white = iAmBlack ? opponentName : myName;
    final black = iAmBlack ? myName : opponentName;
    final res = pgnResult(result: result, playerColor: playerColor);
    final fen = (initialFen == null || initialFen.isEmpty) ? _startFen : initialFen;
    final startsWithBlack = fen.split(' ').length > 1 && fen.split(' ')[1] == 'b';

    String tag(String k, String v) => '[$k "${_clean(v)}"]';
    final tags = <String>[
      tag('Event', event),
      tag('Site', 'Chess app'),
      tag('Date', '${date.year.toString().padLeft(4, '0')}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'),
      tag('White', white),
      tag('Black', black),
      tag('Result', res),
      if (fen != _startFen) tag('SetUp', '1'),
      if (fen != _startFen) tag('FEN', fen),
    ];

    final text = StringBuffer();
    var ply = startsWithBlack ? 1 : 0;
    var n = 1;
    for (final san in sanMoves) {
      if (ply % 2 == 0) {
        text.write('$n. ');
      } else if (text.isEmpty) {
        text.write('$n... ');
      }
      text.write('$san ');
      if (ply % 2 == 1) n++;
      ply++;
    }
    text.write(res);
    return '${tags.join('\n')}\n\n${_wrap(text.toString())}\n';
  }

  /// "1-0", "0-1", "1/2-1/2" or "*" (unknown).
  static String pgnResult({required String result, required String playerColor}) {
    if (result == 'draw') return '1/2-1/2';
    if (playerColor != 'white' && playerColor != 'black') return '*';
    final iWon = result == 'win';
    if (result != 'win' && result != 'loss') return '*';
    final whiteWon = (playerColor == 'white') == iWon;
    return whiteWon ? '1-0' : '0-1';
  }

  static String _clean(String v) => v.replaceAll('"', "'").replaceAll(RegExp(r'[\r\n\\]'), ' ').trim();

  // PGN lines should stay under 80 characters.
  static String _wrap(String s) {
    final words = s.split(' ');
    final out = StringBuffer();
    var line = 0;
    for (final w in words) {
      if (w.isEmpty) continue;
      if (line + w.length + (line == 0 ? 0 : 1) > 79) {
        out.write('\n');
        line = 0;
      }
      if (line > 0) {
        out.write(' ');
        line++;
      }
      out.write(w);
      line += w.length;
    }
    return out.toString();
  }
}

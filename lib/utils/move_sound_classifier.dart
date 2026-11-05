/// Decides which sound a chess move should make, from the FEN before and after it.
///
/// Pure Dart (no Flutter, no chess package), so it works for every path that
/// changes the board (own move, CPU move, online opponent move) and is easy to test.
enum MoveSoundKind { move, capture, castle, check }

/// [fenBefore] / [fenAfter]: the position before and after ONE move.
/// Priority: check > capture > castle > plain move.
/// A malformed FEN falls back to a plain move sound.
MoveSoundKind classifyMoveSound(String fenBefore, String fenAfter) {
  try {
    final before = _Fen.parse(fenBefore);
    final after = _Fen.parse(fenAfter);

    // The side to move AFTER the move is the side that may now be in check.
    if (_isKingAttacked(after.grid, whiteKing: after.whiteToMove)) {
      return MoveSoundKind.check;
    }
    if (after.pieceCount < before.pieceCount) return MoveSoundKind.capture;

    // The mover is the side to move BEFORE the move. A king never moves two
    // files except when castling.
    final kingChar = before.whiteToMove ? 'K' : 'k';
    final fileBefore = before.fileOf(kingChar);
    final fileAfter = after.fileOf(kingChar);
    if (fileBefore != null &&
        fileAfter != null &&
        (fileBefore - fileAfter).abs() == 2) {
      return MoveSoundKind.castle;
    }
  } catch (_) {
    // fall through
  }
  return MoveSoundKind.move;
}

class _Fen {
  final List<List<String>> grid; // grid[0] is rank 8, grid[7] is rank 1; '' = empty
  final bool whiteToMove;
  final int pieceCount;

  _Fen(this.grid, this.whiteToMove, this.pieceCount);

  factory _Fen.parse(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final rows = parts[0].split('/');
    if (rows.length != 8) throw const FormatException('bad FEN');
    final grid = <List<String>>[];
    var count = 0;
    for (final row in rows) {
      final cells = <String>[];
      for (final ch in row.split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          for (var i = 0; i < n; i++) {
            cells.add('');
          }
        } else {
          cells.add(ch);
          count++;
        }
      }
      if (cells.length != 8) throw const FormatException('bad FEN row');
      grid.add(cells);
    }
    final white = parts.length < 2 || parts[1] == 'w';
    return _Fen(grid, white, count);
  }

  /// File (0..7) of the first [piece] found, or null.
  int? fileOf(String piece) {
    for (final row in grid) {
      for (var c = 0; c < 8; c++) {
        if (row[c] == piece) return c;
      }
    }
    return null;
  }
}

bool _isWhite(String p) => p.toUpperCase() == p;

bool _isKingAttacked(List<List<String>> g, {required bool whiteKing}) {
  final king = whiteKing ? 'K' : 'k';
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      if (g[r][c] == king) {
        return _isAttacked(g, r, c, byWhite: !whiteKing);
      }
    }
  }
  return false;
}

bool _isAttacked(List<List<String>> g, int r, int c, {required bool byWhite}) {
  bool at(int rr, int cc, List<String> kinds) {
    if (rr < 0 || rr > 7 || cc < 0 || cc > 7) return false;
    final p = g[rr][cc];
    if (p.isEmpty || _isWhite(p) != byWhite) return false;
    return kinds.contains(p.toUpperCase());
  }

  // Pawns: a white pawn attacks diagonally upwards (towards rank 8 = row 0).
  final pawnRow = byWhite ? r + 1 : r - 1;
  if (at(pawnRow, c - 1, ['P']) || at(pawnRow, c + 1, ['P'])) return true;

  const knight = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1],
  ];
  for (final d in knight) {
    if (at(r + d[0], c + d[1], ['N'])) return true;
  }

  for (var dr = -1; dr <= 1; dr++) {
    for (var dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      if (at(r + dr, c + dc, ['K'])) return true;
    }
  }

  // Sliders: walk each direction until the first piece.
  const straight = [[-1, 0], [1, 0], [0, -1], [0, 1]];
  const diagonal = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
  for (final d in straight) {
    if (_firstPieceIs(g, r, c, d[0], d[1], byWhite, ['R', 'Q'])) return true;
  }
  for (final d in diagonal) {
    if (_firstPieceIs(g, r, c, d[0], d[1], byWhite, ['B', 'Q'])) return true;
  }
  return false;
}

bool _firstPieceIs(List<List<String>> g, int r, int c, int dr, int dc,
    bool byWhite, List<String> kinds) {
  var rr = r + dr;
  var cc = c + dc;
  while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8) {
    final p = g[rr][cc];
    if (p.isNotEmpty) {
      return _isWhite(p) == byWhite && kinds.contains(p.toUpperCase());
    }
    rr += dr;
    cc += dc;
  }
  return false;
}

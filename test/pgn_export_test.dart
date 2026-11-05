import 'package:flutter_chess_app/utils/pgn_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a PGN with tags, numbering and result', () {
    final pgn = PgnExport.build(
      sanMoves: ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
      myName: 'Me',
      opponentName: 'Bob',
      playerColor: 'black',
      result: 'loss',
      date: DateTime(2026, 10, 31),
    );
    expect(pgn, contains('[White "Bob"]'));
    expect(pgn, contains('[Black "Me"]'));
    expect(pgn, contains('[Date "2026.10.31"]'));
    expect(pgn, contains('[Result "1-0"]'));
    expect(pgn, contains('1. e4 e5 2. Nf3 Nc6 3. Bb5 1-0'));
  });

  test('result mapping', () {
    expect(PgnExport.pgnResult(result: 'draw', playerColor: ''), '1/2-1/2');
    expect(PgnExport.pgnResult(result: 'win', playerColor: 'black'), '0-1');
    expect(PgnExport.pgnResult(result: 'win', playerColor: ''), '*');
  });
}

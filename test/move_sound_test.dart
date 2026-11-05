import 'package:flutter_chess_app/utils/move_sound_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('plain move', () {
    expect(
      classifyMoveSound(start,
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'),
      MoveSoundKind.move,
    );
  });

  test('capture', () {
    expect(
      classifyMoveSound(
          'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2',
          'rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2'),
      MoveSoundKind.capture,
    );
  });

  test('castling (white, king side)', () {
    expect(
      classifyMoveSound(
          'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
          'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 b kq - 5 4'),
      MoveSoundKind.castle,
    );
  });

  test('check by a bishop', () {
    expect(
      classifyMoveSound(
          'rnbqkbnr/ppp2ppp/3p4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 3',
          'rnbqkbnr/ppp2ppp/3p4/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 1 3'),
      MoveSoundKind.check,
    );
  });

  test('same bishop move but the line is blocked: no check', () {
    expect(
      classifyMoveSound(
          'rnbqkbnr/ppp2ppp/2pp4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 3',
          'rnbqkbnr/ppp2ppp/2pp4/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 1 3'),
      MoveSoundKind.move,
    );
  });

  test('check wins over capture (Bxd7+)', () {
    expect(
      classifyMoveSound(
          'rnbqkbnr/pppp1ppp/8/1B2p3/4P3/8/PPPP1PPP/RNBQK1NR w KQkq - 0 3',
          'rnbqkbnr/pppB1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 0 3'),
      MoveSoundKind.check,
    );
  });

  test('broken FEN falls back to a plain move sound', () {
    expect(classifyMoveSound('garbage', 'nonsense'), MoveSoundKind.move);
  });
}

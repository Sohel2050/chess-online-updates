import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_chess_app/widgets/move_arrow_overlay.dart';

void main() {
  group('ArrowGeometry', () {
    test('parseUci accepts moves and promotions, rejects junk', () {
      expect(ArrowGeometry.parseUci('e2e4'), ('e2', 'e4'));
      expect(ArrowGeometry.parseUci('e7e8q'), ('e7', 'e8'));
      expect(ArrowGeometry.parseUci(null), isNull);
      expect(ArrowGeometry.parseUci(''), isNull);
      expect(ArrowGeometry.parseUci('e2'), isNull);
      expect(ArrowGeometry.parseUci('z9z9'), isNull);
    });

    test('square centres, White at the bottom', () {
      // 800 px board -> 100 px squares
      expect(ArrowGeometry.squareCenter('a1', 800, flipped: false), const Offset(50, 750));
      expect(ArrowGeometry.squareCenter('h8', 800, flipped: false), const Offset(750, 50));
      expect(ArrowGeometry.squareCenter('e4', 800, flipped: false), const Offset(450, 450));
    });

    test('square centres, Black at the bottom (flipped)', () {
      expect(ArrowGeometry.squareCenter('a1', 800, flipped: true), const Offset(750, 50));
      expect(ArrowGeometry.squareCenter('h8', 800, flipped: true), const Offset(50, 750));
    });
  });
}

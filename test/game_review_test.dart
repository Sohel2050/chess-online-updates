import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/services/game_review.dart';

void main() {
  group('ReviewRules', () {
    test('win percent is 50 at equal and symmetric', () {
      expect(ReviewRules.winPercent(0), closeTo(50, 0.01));
      expect(ReviewRules.winPercent(300) + ReviewRules.winPercent(-300), closeTo(100, 0.01));
    });

    test('classify uses 70/150/300 limits', () {
      expect(ReviewRules.classify(5, playedEngineMove: false), MoveQuality.best);
      expect(ReviewRules.classify(69, playedEngineMove: false), MoveQuality.good);
      expect(ReviewRules.classify(70, playedEngineMove: false), MoveQuality.inaccuracy);
      expect(ReviewRules.classify(150, playedEngineMove: false), MoveQuality.mistake);
      expect(ReviewRules.classify(300, playedEngineMove: false), MoveQuality.blunder);
      expect(ReviewRules.classify(500, playedEngineMove: true), MoveQuality.best);
    });

    test('judge: White blunders a queen', () {
      final m = ReviewRules.judge(
          ply: 0, white: true, cpBefore: 30, cpAfter: -800, bestUci: 'e2e4', playedUci: 'd1h5');
      expect(m.quality, MoveQuality.blunder);
      expect(m.loss, 830);
      expect(m.accuracy, lessThan(30));
    });

    test('judge: Black side uses the opposite sign', () {
      // Black was fine (-20 for White), then White's score rose to +400 = Black lost 420.
      final m = ReviewRules.judge(
          ply: 1, white: false, cpBefore: -20, cpAfter: 400, bestUci: 'e7e5', playedUci: 'a7a6');
      expect(m.loss, 420);
      expect(m.quality, MoveQuality.blunder);
    });

    test('judge: playing the engine move is best and 100%', () {
      final m = ReviewRules.judge(
          ply: 0, white: true, cpBefore: 20, cpAfter: 15, bestUci: 'e2e4', playedUci: 'e2e4');
      expect(m.quality, MoveQuality.best);
      expect(m.accuracy, 100);
    });

    test('judge: missing engine score is neutral', () {
      final m = ReviewRules.judge(
          ply: 0, white: true, cpBefore: null, cpAfter: 10, bestUci: null, playedUci: 'e2e4');
      expect(m.quality, MoveQuality.good);
      expect(m.loss, 0);
    });

    test('scoreText and bar', () {
      expect(ReviewRules.scoreText(45), '+0.45');
      expect(ReviewRules.scoreText(-120), '-1.20');
      expect(ReviewRules.scoreText(9997), '+M3');
      expect(ReviewRules.scoreText(null), '–');
      expect(ReviewRules.barWhite(null), 0.5);
      expect(ReviewRules.barWhite(10000), greaterThan(0.95));
    });
  });

  group('GameReviewResult', () {
    test('encode/decode round trip and summary', () {
      final moves = [
        ReviewRules.judge(ply: 0, white: true, cpBefore: 20, cpAfter: 15, bestUci: 'e2e4', playedUci: 'e2e4'),
        ReviewRules.judge(ply: 1, white: false, cpBefore: 15, cpAfter: 600, bestUci: 'e7e5', playedUci: 'a7a6'),
      ];
      final r = GameReviewResult([20, 15, 600], moves);
      final back = GameReviewResult.decode(r.encode())!;
      expect(back.moves.length, 2);
      expect(back.evals, [20, 15, 600]);
      expect(back.summary(white: true).best, 1);
      expect(back.summary(white: false).blunders, 1);
      expect(back.worstMove(white: false)!.ply, 1);
      expect(back.worstMove(white: true), isNull);
    });

    test('decode rejects garbage', () {
      expect(GameReviewResult.decode(null), isNull);
      expect(GameReviewResult.decode('not json'), isNull);
      expect(GameReviewResult.decode('{"v":2}'), isNull);
    });
  });
}

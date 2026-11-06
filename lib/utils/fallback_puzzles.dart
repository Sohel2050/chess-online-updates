import '../models/puzzle_model.dart';

/// Fallback puzzle data in case the main puzzle file fails to load
class FallbackPuzzles {
  /// Get a minimal set of fallback puzzles for each difficulty
  static List<PuzzleModel> getFallbackPuzzles() {
    return [
      // Beginner puzzles
      PuzzleModel(
        id: 'fallback_beginner_1',
        fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        solution: ['d1h5'],
        objective: 'White to play and threaten checkmate',
        difficulty: PuzzleDifficulty.beginner,
        rating: 800,
        hints: [
          'Look for a move that attacks the king',
          'The queen can move to h5',
          'Qh5 threatens mate on f7',
        ],
        tags: ['tactics', 'mate threat'],
      ),

      // Easy puzzles
      PuzzleModel(
        id: 'fallback_easy_1',
        fen:
            'r1bq1rk1/ppp2ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQR1K1 w - - 0 8',
        solution: ['c4f7', 'f8f7', 'f3e5'],
        objective: 'White to play and win the exchange',
        difficulty: PuzzleDifficulty.easy,
        rating: 1100,
        hints: [
          'Look for a sacrifice that wins material',
          'The bishop on c4 can capture on f7',
          'After the exchange, Ne5 attacks the rook',
        ],
        tags: ['sacrifice', 'exchange', 'tactics'],
      ),

      // Medium puzzles
      PuzzleModel(
        id: 'fallback_medium_1',
        fen:
            'r2qkb1r/ppp2ppp/2n2n2/3pp3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 6',
        solution: ['f3g5', 'h7h6', 'g5f7'],
        objective: 'White to play and win material',
        difficulty: PuzzleDifficulty.medium,
        rating: 1300,
        hints: [
          'Look for a knight move that creates threats',
          'The knight can attack f7 from g5',
          'After h6, Nxf7 wins the exchange',
        ],
        tags: ['knight', 'tactics', 'material'],
      ),

      // Hard puzzles
      // Expert puzzles
    ];
  }

  /// Get fallback puzzles for a specific difficulty
  static List<PuzzleModel> getFallbackPuzzlesForDifficulty(
    PuzzleDifficulty difficulty,
  ) {
    return getFallbackPuzzles()
        .where((puzzle) => puzzle.difficulty == difficulty)
        .toList();
  }

  /// Check if we should use fallback puzzles
  static bool shouldUseFallback(List<PuzzleModel> loadedPuzzles) {
    return loadedPuzzles.isEmpty;
  }
}

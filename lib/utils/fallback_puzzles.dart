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
        solution: ['Qh5'],
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

      PuzzleModel(
        id: 'fallback_beginner_2',
        fen:
            'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 4',
        solution: ['Bxf7+', 'Ke7', 'Nd5+'],
        objective: 'White to play and win material',
        difficulty: PuzzleDifficulty.beginner,
        rating: 900,
        hints: [
          'Look for a forcing move that attacks the king',
          'Consider a bishop sacrifice on f7',
          'After Bxf7+ Ke7, you can fork the king and queen',
        ],
        tags: ['fork', 'sacrifice', 'tactics'],
      ),

      // Easy puzzles
      PuzzleModel(
        id: 'fallback_easy_1',
        fen:
            'r1bq1rk1/ppp2ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQR1K1 w - - 0 8',
        solution: ['Bxf7+', 'Rxf7', 'Ne5'],
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
        solution: ['Ng5', 'h6', 'Nxf7'],
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
      PuzzleModel(
        id: 'fallback_hard_1',
        fen:
            'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5',
        solution: ['Nd5', 'Nxd5', 'exd5', 'Ne7+'],
        objective: 'White to play and win material',
        difficulty: PuzzleDifficulty.hard,
        rating: 1500,
        hints: [
          'Look for a central breakthrough',
          'Nd5 creates multiple threats',
          'After the exchanges, Ne7+ forks king and bishop',
        ],
        tags: ['central', 'fork', 'tactics'],
      ),

      // Expert puzzles
      PuzzleModel(
        id: 'fallback_expert_1',
        fen:
            'r2qkb1r/ppp2ppp/2n2n2/3pp1B1/2B1P3/3P1N2/PPP2PPP/RN1QK2R w KQkq - 0 7',
        solution: ['Nd5', 'Nxd5', 'Bxd5', 'c6', 'Bxf7+'],
        objective: 'White to play and win decisively',
        difficulty: PuzzleDifficulty.expert,
        rating: 1700,
        hints: [
          'Look for a complex tactical sequence',
          'Nd5 starts a forcing variation',
          'The final blow comes with Bxf7+',
        ],
        tags: ['complex', 'tactics', 'sacrifice'],
      ),
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

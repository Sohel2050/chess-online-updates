import 'dart:math';

class RatingService {
  /// Calculates the new Elo ratings for two players after a game.
  ///
  /// [playerRating] The current rating of the player whose rating is being updated.
  /// [opponentRating] The current rating of the opponent.
  /// [outcome] The outcome of the game from the perspective of `playerRating`:
  ///   - 1.0 for a win
  ///   - 0.5 for a draw
  ///   - 0.0 for a loss
  /// [kFactor] The K-factor, which determines the maximum possible adjustment per game.
  ///   Common values: 32 (new players), 24 (players under 2400), 16 (players over 2400).
  ///
  /// Returns the new rating for the player.
  int calculateNewRating({
    required int playerRating,
    required int opponentRating,
    required double outcome,
    int kFactor = 24, // Default K-factor
  }) {
    // Expected score for the player
    final double expectedScore =
        1.0 / (1.0 + pow(10, (opponentRating - playerRating) / 400));

    // New rating calculation
    final double newRating = playerRating + kFactor * (outcome - expectedScore);

    return newRating.round();
  }

  /// Updates the ratings for both players after a game.
  ///
  /// Returns a Map containing the new ratings for player1 and player2.
  Map<String, int> updateGameRatings({
    required int player1CurrentRating,
    required int player2CurrentRating,
    required double
    player1Outcome, // 1.0 for P1 win, 0.5 for draw, 0.0 for P1 loss
    int kFactor = 24,
  }) {
    final int player1NewRating = calculateNewRating(
      playerRating: player1CurrentRating,
      opponentRating: player2CurrentRating,
      outcome: player1Outcome,
      kFactor: kFactor,
    );

    final int player2NewRating = calculateNewRating(
      playerRating: player2CurrentRating,
      opponentRating: player1CurrentRating,
      outcome: 1.0 - player1Outcome, // Opponent's outcome is inverse
      kFactor: kFactor,
    );

    return {
      'player1Rating': player1NewRating,
      'player2Rating': player2NewRating,
    };
  }
}

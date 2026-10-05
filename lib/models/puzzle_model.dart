import 'package:json_annotation/json_annotation.dart';

part 'puzzle_model.g.dart';

/// Enum representing different difficulty levels for chess puzzles
enum PuzzleDifficulty {
  @JsonValue('beginner')
  beginner,
  @JsonValue('easy')
  easy,
  @JsonValue('medium')
  medium,
  @JsonValue('hard')
  hard,
  @JsonValue('expert')
  expert,
}

/// Extension to provide additional functionality for PuzzleDifficulty
extension PuzzleDifficultyExtension on PuzzleDifficulty {
  /// Get display name for the difficulty level
  String get displayName {
    switch (this) {
      case PuzzleDifficulty.beginner:
        return 'Beginner';
      case PuzzleDifficulty.easy:
        return 'Easy';
      case PuzzleDifficulty.medium:
        return 'Medium';
      case PuzzleDifficulty.hard:
        return 'Hard';
      case PuzzleDifficulty.expert:
        return 'Expert';
    }
  }

  /// Get rating range for the difficulty level
  String get ratingRange {
    switch (this) {
      case PuzzleDifficulty.beginner:
        return '800-1000';
      case PuzzleDifficulty.easy:
        return '1000-1200';
      case PuzzleDifficulty.medium:
        return '1200-1400';
      case PuzzleDifficulty.hard:
        return '1400-1600';
      case PuzzleDifficulty.expert:
        return '1600+';
    }
  }
}

/// Model representing a chess puzzle
@JsonSerializable()
class PuzzleModel {
  /// Unique identifier for the puzzle
  final String id;

  /// FEN (Forsyth-Edwards Notation) string representing the starting position
  final String fen;

  /// List of moves that represent the correct solution
  final List<String> solution;

  /// Description of what the player needs to achieve (e.g., "White to play and win material")
  final String objective;

  /// Difficulty level of the puzzle
  final PuzzleDifficulty difficulty;

  /// List of progressive hints to help solve the puzzle
  final List<String> hints;

  /// Puzzle rating/difficulty score
  final int rating;

  /// Categories/tags for the puzzle (e.g., "tactics", "endgame", "fork")
  final List<String> tags;

  /// Whether the opponent/CPU plays the first move in this puzzle
  final bool opponentPlaysFirst;

  /// How many hints this puzzle actually offers. Puzzles with
  /// hand-written `hints` use that count; puzzles with none (e.g. the
  /// Lichess-sourced batch imported via importPuzzlesFromAsset.js) still
  /// get 3 generated hints as long as they have a solution — see
  /// PuzzleService.getNextHint, which generates hints 0/1/2 in that case.
  int get effectiveHintCount => hints.isNotEmpty ? hints.length : (solution.isNotEmpty ? 3 : 0);

  const PuzzleModel({
    required this.id,
    required this.fen,
    required this.solution,
    required this.objective,
    required this.difficulty,
    required this.hints,
    required this.rating,
    required this.tags,
    this.opponentPlaysFirst =
        false, // Default to false for backward compatibility
  });

  /// Create PuzzleModel from JSON
  factory PuzzleModel.fromJson(Map<String, dynamic> json) =>
      _$PuzzleModelFromJson(json);

  /// Convert PuzzleModel to JSON
  Map<String, dynamic> toJson() => _$PuzzleModelToJson(this);

  /// Create a copy of this puzzle with updated fields
  PuzzleModel copyWith({
    String? id,
    String? fen,
    List<String>? solution,
    String? objective,
    PuzzleDifficulty? difficulty,
    List<String>? hints,
    int? rating,
    List<String>? tags,
    bool? opponentPlaysFirst,
  }) {
    return PuzzleModel(
      id: id ?? this.id,
      fen: fen ?? this.fen,
      solution: solution ?? this.solution,
      objective: objective ?? this.objective,
      difficulty: difficulty ?? this.difficulty,
      hints: hints ?? this.hints,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      opponentPlaysFirst: opponentPlaysFirst ?? this.opponentPlaysFirst,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PuzzleModel(id: $id, objective: $objective, difficulty: $difficulty, rating: $rating, opponentPlaysFirst: $opponentPlaysFirst)';
  }
}

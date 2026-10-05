import 'package:json_annotation/json_annotation.dart';
import 'puzzle_model.dart';

part 'puzzle_statistics.g.dart';

/// Statistics for a specific difficulty level
@JsonSerializable()
class DifficultyStats {
  /// Number of puzzles completed at this difficulty
  final int completed;

  /// Total number of puzzles available at this difficulty
  final int total;

  /// Average time to solve puzzles at this difficulty
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration? averageTime;

  /// Total hints used for puzzles at this difficulty
  final int hintsUsed;

  const DifficultyStats({
    required this.completed,
    required this.total,
    this.averageTime,
    required this.hintsUsed,
  });

  /// Create DifficultyStats from JSON
  factory DifficultyStats.fromJson(Map<String, dynamic> json) =>
      _$DifficultyStatsFromJson(json);

  /// Convert DifficultyStats to JSON
  Map<String, dynamic> toJson() => _$DifficultyStatsToJson(this);

  /// Get completion percentage (0-100)
  double get completionPercentage {
    if (total == 0) return 0.0;
    return (completed / total) * 100.0;
  }

  /// Create a copy of this stats with updated fields
  DifficultyStats copyWith({
    int? completed,
    int? total,
    Duration? averageTime,
    int? hintsUsed,
  }) {
    return DifficultyStats(
      completed: completed ?? this.completed,
      total: total ?? this.total,
      averageTime: averageTime ?? this.averageTime,
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }

  @override
  String toString() {
    return 'DifficultyStats(completed: $completed/$total, averageTime: $averageTime, hintsUsed: $hintsUsed)';
  }

  // Helper methods for JSON serialization of Duration
  static Duration? _durationFromJson(int? json) =>
      json != null ? Duration(milliseconds: json) : null;

  static int? _durationToJson(Duration? duration) => duration?.inMilliseconds;
}

/// Model for tracking overall puzzle statistics for a user
@JsonSerializable()
class PuzzleStatistics {
  /// User ID for these statistics
  final String userId;

  /// Total number of puzzles solved across all difficulties
  final int totalPuzzlesSolved;

  /// Statistics broken down by difficulty level
  final Map<PuzzleDifficulty, DifficultyStats> puzzlesByDifficulty;

  /// Average time to solve puzzles across all difficulties
  @JsonKey(fromJson: _durationFromJsonRequired, toJson: _durationToJson)
  final Duration averageSolveTime;

  /// Total number of hints used across all puzzles
  final int totalHintsUsed;

  /// Number of puzzles solved without using any hints
  final int perfectSolutions;

  /// Longest streak of consecutive puzzles solved
  final int longestStreak;

  /// Current streak of consecutive puzzles solved
  final int currentStreak;

  /// Timestamp of when puzzles were last played
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? lastPlayedAt;

  /// Timestamp when the statistics record was created
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// Timestamp when the statistics record was last updated
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  const PuzzleStatistics({
    required this.userId,
    required this.totalPuzzlesSolved,
    required this.puzzlesByDifficulty,
    required this.averageSolveTime,
    required this.totalHintsUsed,
    required this.perfectSolutions,
    required this.longestStreak,
    required this.currentStreak,
    this.lastPlayedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create PuzzleStatistics from JSON
  factory PuzzleStatistics.fromJson(Map<String, dynamic> json) =>
      _$PuzzleStatisticsFromJson(json);

  /// Convert PuzzleStatistics to JSON
  Map<String, dynamic> toJson() => _$PuzzleStatisticsToJson(this);

  /// Create initial statistics for a new user
  factory PuzzleStatistics.initial({required String userId}) {
    final now = DateTime.now();
    return PuzzleStatistics(
      userId: userId,
      totalPuzzlesSolved: 0,
      puzzlesByDifficulty: {
        for (final difficulty in PuzzleDifficulty.values)
          difficulty: const DifficultyStats(
            completed: 0,
            total: 0,
            hintsUsed: 0,
          ),
      },
      averageSolveTime: Duration.zero,
      totalHintsUsed: 0,
      perfectSolutions: 0,
      longestStreak: 0,
      currentStreak: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get completion percentage for a specific difficulty
  double getCompletionPercentage(PuzzleDifficulty difficulty) {
    final stats = puzzlesByDifficulty[difficulty];
    return stats?.completionPercentage ?? 0.0;
  }

  /// Get total completion percentage across all difficulties
  double get overallCompletionPercentage {
    final totalAvailable = puzzlesByDifficulty.values.fold<int>(
      0,
      (sum, stats) => sum + stats.total,
    );
    if (totalAvailable == 0) return 0.0;
    return (totalPuzzlesSolved / totalAvailable) * 100.0;
  }

  /// Create a copy of this statistics with updated fields
  PuzzleStatistics copyWith({
    String? userId,
    int? totalPuzzlesSolved,
    Map<PuzzleDifficulty, DifficultyStats>? puzzlesByDifficulty,
    Duration? averageSolveTime,
    int? totalHintsUsed,
    int? perfectSolutions,
    int? longestStreak,
    int? currentStreak,
    DateTime? lastPlayedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PuzzleStatistics(
      userId: userId ?? this.userId,
      totalPuzzlesSolved: totalPuzzlesSolved ?? this.totalPuzzlesSolved,
      puzzlesByDifficulty: puzzlesByDifficulty ?? this.puzzlesByDifficulty,
      averageSolveTime: averageSolveTime ?? this.averageSolveTime,
      totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
      perfectSolutions: perfectSolutions ?? this.perfectSolutions,
      longestStreak: longestStreak ?? this.longestStreak,
      currentStreak: currentStreak ?? this.currentStreak,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleStatistics && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'PuzzleStatistics(userId: $userId, totalSolved: $totalPuzzlesSolved, perfectSolutions: $perfectSolutions)';
  }

  // Helper methods for JSON serialization of DateTime
  static DateTime? _dateTimeFromJson(String? json) =>
      json != null ? DateTime.parse(json) : null;

  static DateTime _dateTimeFromJsonRequired(String json) =>
      DateTime.parse(json);

  static String? _dateTimeToJson(DateTime? dateTime) =>
      dateTime?.toIso8601String();

  // Helper methods for JSON serialization of Duration
  static Duration? _durationFromJson(int? json) =>
      json != null ? Duration(milliseconds: json) : null;

  static Duration _durationFromJsonRequired(int json) =>
      Duration(milliseconds: json);

  static int? _durationToJson(Duration? duration) => duration?.inMilliseconds;
}

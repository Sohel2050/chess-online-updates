import 'package:json_annotation/json_annotation.dart';
import 'puzzle_model.dart';

part 'puzzle_progress.g.dart';

/// Model for tracking puzzle completion status and statistics
@JsonSerializable()
class PuzzleProgress {
  /// User ID who solved the puzzle
  final String userId;

  /// ID of the puzzle that was solved
  final String puzzleId;

  /// Whether the puzzle has been completed successfully
  final bool completed;

  /// Timestamp when the puzzle was completed (null if not completed)
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? completedAt;

  /// Time taken to solve the puzzle (null if not completed)
  @JsonKey(fromJson: _durationFromJson, toJson: _durationToJson)
  final Duration? solveTime;

  /// Number of hints used while solving the puzzle
  final int hintsUsed;

  /// Number of attempts made to solve the puzzle
  final int attempts;

  /// Whether the puzzle was solved without using any hints
  final bool solvedWithoutHints;

  /// Difficulty level of the puzzle
  final PuzzleDifficulty difficulty;

  /// Timestamp when the progress record was created
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// Timestamp when the progress record was last updated
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  /// Whether this progress needs to be synced to the cloud
  final bool needsSync;

  const PuzzleProgress({
    required this.userId,
    required this.puzzleId,
    required this.completed,
    this.completedAt,
    this.solveTime,
    required this.hintsUsed,
    required this.attempts,
    required this.solvedWithoutHints,
    required this.difficulty,
    required this.createdAt,
    required this.updatedAt,
    this.needsSync = true,
  });

  /// Create PuzzleProgress from JSON
  factory PuzzleProgress.fromJson(Map<String, dynamic> json) =>
      _$PuzzleProgressFromJson(json);

  /// Convert PuzzleProgress to JSON
  Map<String, dynamic> toJson() => _$PuzzleProgressToJson(this);

  /// Create a new PuzzleProgress instance for a new puzzle attempt
  factory PuzzleProgress.newAttempt({
    required String userId,
    required String puzzleId,
    required PuzzleDifficulty difficulty,
  }) {
    final now = DateTime.now();
    return PuzzleProgress(
      userId: userId,
      puzzleId: puzzleId,
      completed: false,
      hintsUsed: 0,
      attempts: 1,
      solvedWithoutHints: false,
      difficulty: difficulty,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a completed PuzzleProgress instance
  PuzzleProgress markCompleted({
    required Duration solveTime,
    required int hintsUsed,
  }) {
    final now = DateTime.now();
    return copyWith(
      completed: true,
      completedAt: now,
      solveTime: solveTime,
      hintsUsed: hintsUsed,
      solvedWithoutHints: hintsUsed == 0,
      updatedAt: now,
      needsSync: true,
    );
  }

  /// Create a copy with incremented attempts
  PuzzleProgress incrementAttempts() {
    return copyWith(
      attempts: attempts + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
    );
  }

  /// Create a copy with incremented hints used
  PuzzleProgress incrementHints() {
    return copyWith(
      hintsUsed: hintsUsed + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
    );
  }

  /// Mark as synced to cloud
  PuzzleProgress markSynced() {
    return copyWith(needsSync: false);
  }

  /// Create a copy of this progress with updated fields
  PuzzleProgress copyWith({
    String? userId,
    String? puzzleId,
    bool? completed,
    DateTime? completedAt,
    Duration? solveTime,
    int? hintsUsed,
    int? attempts,
    bool? solvedWithoutHints,
    PuzzleDifficulty? difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsSync,
  }) {
    return PuzzleProgress(
      userId: userId ?? this.userId,
      puzzleId: puzzleId ?? this.puzzleId,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      solveTime: solveTime ?? this.solveTime,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      attempts: attempts ?? this.attempts,
      solvedWithoutHints: solvedWithoutHints ?? this.solvedWithoutHints,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleProgress &&
        other.userId == userId &&
        other.puzzleId == puzzleId;
  }

  @override
  int get hashCode => Object.hash(userId, puzzleId);

  @override
  String toString() {
    return 'PuzzleProgress(userId: $userId, puzzleId: $puzzleId, completed: $completed, attempts: $attempts)';
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

  static int? _durationToJson(Duration? duration) => duration?.inMilliseconds;
}

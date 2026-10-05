import 'package:json_annotation/json_annotation.dart';
import 'puzzle_model.dart';

part 'puzzle_session.g.dart';

/// Enum representing the current state of a puzzle session
enum PuzzleSessionState {
  @JsonValue('active')
  active,
  @JsonValue('solved')
  solved,
  @JsonValue('failed')
  failed,
  @JsonValue('abandoned')
  abandoned,
}

/// Extension to provide additional functionality for PuzzleSessionState
extension PuzzleSessionStateExtension on PuzzleSessionState {
  /// Get display name for the session state
  String get displayName {
    switch (this) {
      case PuzzleSessionState.active:
        return 'Active';
      case PuzzleSessionState.solved:
        return 'Solved';
      case PuzzleSessionState.failed:
        return 'Failed';
      case PuzzleSessionState.abandoned:
        return 'Abandoned';
    }
  }

  /// Check if the session is still in progress
  bool get isActive => this == PuzzleSessionState.active;

  /// Check if the session is completed (solved, failed, or abandoned)
  bool get isCompleted => !isActive;
}

/// Model representing an active puzzle-solving session
@JsonSerializable()
class PuzzleSession {
  /// The puzzle being solved in this session
  final PuzzleModel puzzle;

  /// List of moves made by the user so far
  final List<String> userMoves;

  /// Current index in the solution sequence
  final int currentMoveIndex;

  /// Number of hints used in this session
  final int hintsUsed;

  /// Timestamp when the session started
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJson)
  final DateTime startTime;

  /// Current state of the puzzle session
  final PuzzleSessionState state;

  /// Timestamp when the session ended (null if still active)
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? endTime;

  /// Number of incorrect moves made
  final int incorrectMoves;

  const PuzzleSession({
    required this.puzzle,
    required this.userMoves,
    required this.currentMoveIndex,
    required this.hintsUsed,
    required this.startTime,
    required this.state,
    this.endTime,
    required this.incorrectMoves,
  });

  /// Create PuzzleSession from JSON
  factory PuzzleSession.fromJson(Map<String, dynamic> json) =>
      _$PuzzleSessionFromJson(json);

  /// Convert PuzzleSession to JSON
  Map<String, dynamic> toJson() => _$PuzzleSessionToJson(this);

  /// Create a new puzzle session
  factory PuzzleSession.start({required PuzzleModel puzzle}) {
    return PuzzleSession(
      puzzle: puzzle,
      userMoves: [],
      currentMoveIndex: 0,
      hintsUsed: 0,
      startTime: DateTime.now(),
      state: PuzzleSessionState.active,
      incorrectMoves: 0,
    );
  }

  /// Get the elapsed time for this session
  Duration get elapsedTime {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get the next expected move in the solution
  String? get nextExpectedMove {
    if (currentMoveIndex >= puzzle.solution.length) return null;
    return puzzle.solution[currentMoveIndex];
  }

  /// Check if the puzzle is completely solved
  bool get isSolved {
    return currentMoveIndex >= puzzle.solution.length &&
        state == PuzzleSessionState.solved;
  }

  /// Check if more moves are needed to complete the puzzle
  bool get needsMoreMoves {
    return currentMoveIndex < puzzle.solution.length;
  }

  /// Get the next hint (if available)
  String? get nextHint {
    if (hintsUsed >= puzzle.hints.length) return null;
    return puzzle.hints[hintsUsed];
  }

  /// Check if more hints are available
  bool get hasMoreHints {
    return hintsUsed < puzzle.hints.length;
  }

  /// Add a correct move to the session
  PuzzleSession addCorrectMove(String move) {
    final newMoves = List<String>.from(userMoves)..add(move);
    final newIndex = currentMoveIndex + 1;
    final newState = newIndex >= puzzle.solution.length
        ? PuzzleSessionState.solved
        : PuzzleSessionState.active;
    final newEndTime = newState == PuzzleSessionState.solved
        ? DateTime.now()
        : null;

    return copyWith(
      userMoves: newMoves,
      currentMoveIndex: newIndex,
      state: newState,
      endTime: newEndTime,
    );
  }

  /// Add an incorrect move to the session
  PuzzleSession addIncorrectMove() {
    return copyWith(incorrectMoves: incorrectMoves + 1);
  }

  /// Use a hint in the session
  PuzzleSession useHint() {
    if (!hasMoreHints) return this;
    return copyWith(hintsUsed: hintsUsed + 1);
  }

  /// Mark the session as abandoned
  PuzzleSession abandon() {
    return copyWith(
      state: PuzzleSessionState.abandoned,
      endTime: DateTime.now(),
    );
  }

  /// Mark the session as failed
  PuzzleSession markFailed() {
    return copyWith(state: PuzzleSessionState.failed, endTime: DateTime.now());
  }

  /// Reset the session to start over
  PuzzleSession reset() {
    return PuzzleSession.start(puzzle: puzzle);
  }

  /// Create a copy of this session with updated fields
  PuzzleSession copyWith({
    PuzzleModel? puzzle,
    List<String>? userMoves,
    int? currentMoveIndex,
    int? hintsUsed,
    DateTime? startTime,
    PuzzleSessionState? state,
    DateTime? endTime,
    int? incorrectMoves,
  }) {
    return PuzzleSession(
      puzzle: puzzle ?? this.puzzle,
      userMoves: userMoves ?? this.userMoves,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      startTime: startTime ?? this.startTime,
      state: state ?? this.state,
      endTime: endTime ?? this.endTime,
      incorrectMoves: incorrectMoves ?? this.incorrectMoves,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleSession &&
        other.puzzle.id == puzzle.id &&
        other.startTime == startTime;
  }

  @override
  int get hashCode => Object.hash(puzzle.id, startTime);

  @override
  String toString() {
    return 'PuzzleSession(puzzleId: ${puzzle.id}, state: $state, moves: ${userMoves.length}/${puzzle.solution.length})';
  }

  // Helper methods for JSON serialization of DateTime
  static DateTime? _dateTimeFromJson(String? json) =>
      json != null ? DateTime.parse(json) : null;

  static DateTime _dateTimeFromJsonRequired(String json) =>
      DateTime.parse(json);

  static String? _dateTimeToJson(DateTime? dateTime) =>
      dateTime?.toIso8601String();
}

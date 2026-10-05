// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleProgress _$PuzzleProgressFromJson(Map<String, dynamic> json) =>
    PuzzleProgress(
      userId: json['userId'] as String,
      puzzleId: json['puzzleId'] as String,
      completed: json['completed'] as bool,
      completedAt: PuzzleProgress._dateTimeFromJson(
        json['completedAt'] as String?,
      ),
      solveTime: PuzzleProgress._durationFromJson(
        (json['solveTime'] as num?)?.toInt(),
      ),
      hintsUsed: (json['hintsUsed'] as num).toInt(),
      attempts: (json['attempts'] as num).toInt(),
      solvedWithoutHints: json['solvedWithoutHints'] as bool,
      difficulty: $enumDecode(_$PuzzleDifficultyEnumMap, json['difficulty']),
      createdAt: PuzzleProgress._dateTimeFromJsonRequired(
        json['createdAt'] as String,
      ),
      updatedAt: PuzzleProgress._dateTimeFromJsonRequired(
        json['updatedAt'] as String,
      ),
      needsSync: json['needsSync'] as bool? ?? true,
    );

Map<String, dynamic> _$PuzzleProgressToJson(PuzzleProgress instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'puzzleId': instance.puzzleId,
      'completed': instance.completed,
      'completedAt': PuzzleProgress._dateTimeToJson(instance.completedAt),
      'solveTime': PuzzleProgress._durationToJson(instance.solveTime),
      'hintsUsed': instance.hintsUsed,
      'attempts': instance.attempts,
      'solvedWithoutHints': instance.solvedWithoutHints,
      'difficulty': _$PuzzleDifficultyEnumMap[instance.difficulty]!,
      'createdAt': PuzzleProgress._dateTimeToJson(instance.createdAt),
      'updatedAt': PuzzleProgress._dateTimeToJson(instance.updatedAt),
      'needsSync': instance.needsSync,
    };

const _$PuzzleDifficultyEnumMap = {
  PuzzleDifficulty.beginner: 'beginner',
  PuzzleDifficulty.easy: 'easy',
  PuzzleDifficulty.medium: 'medium',
  PuzzleDifficulty.hard: 'hard',
  PuzzleDifficulty.expert: 'expert',
};

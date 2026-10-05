// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_statistics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DifficultyStats _$DifficultyStatsFromJson(Map<String, dynamic> json) =>
    DifficultyStats(
      completed: (json['completed'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      averageTime: DifficultyStats._durationFromJson(
        (json['averageTime'] as num?)?.toInt(),
      ),
      hintsUsed: (json['hintsUsed'] as num).toInt(),
    );

Map<String, dynamic> _$DifficultyStatsToJson(DifficultyStats instance) =>
    <String, dynamic>{
      'completed': instance.completed,
      'total': instance.total,
      'averageTime': DifficultyStats._durationToJson(instance.averageTime),
      'hintsUsed': instance.hintsUsed,
    };

PuzzleStatistics _$PuzzleStatisticsFromJson(Map<String, dynamic> json) =>
    PuzzleStatistics(
      userId: json['userId'] as String,
      totalPuzzlesSolved: (json['totalPuzzlesSolved'] as num).toInt(),
      puzzlesByDifficulty: (json['puzzlesByDifficulty'] as Map<String, dynamic>)
          .map(
            (k, e) => MapEntry(
              $enumDecode(_$PuzzleDifficultyEnumMap, k),
              DifficultyStats.fromJson(e as Map<String, dynamic>),
            ),
          ),
      averageSolveTime: PuzzleStatistics._durationFromJsonRequired(
        (json['averageSolveTime'] as num).toInt(),
      ),
      totalHintsUsed: (json['totalHintsUsed'] as num).toInt(),
      perfectSolutions: (json['perfectSolutions'] as num).toInt(),
      longestStreak: (json['longestStreak'] as num).toInt(),
      currentStreak: (json['currentStreak'] as num).toInt(),
      lastPlayedAt: PuzzleStatistics._dateTimeFromJson(
        json['lastPlayedAt'] as String?,
      ),
      createdAt: PuzzleStatistics._dateTimeFromJsonRequired(
        json['createdAt'] as String,
      ),
      updatedAt: PuzzleStatistics._dateTimeFromJsonRequired(
        json['updatedAt'] as String,
      ),
    );

Map<String, dynamic> _$PuzzleStatisticsToJson(PuzzleStatistics instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'totalPuzzlesSolved': instance.totalPuzzlesSolved,
      'puzzlesByDifficulty': instance.puzzlesByDifficulty.map(
        (k, e) => MapEntry(_$PuzzleDifficultyEnumMap[k]!, e),
      ),
      'averageSolveTime': PuzzleStatistics._durationToJson(
        instance.averageSolveTime,
      ),
      'totalHintsUsed': instance.totalHintsUsed,
      'perfectSolutions': instance.perfectSolutions,
      'longestStreak': instance.longestStreak,
      'currentStreak': instance.currentStreak,
      'lastPlayedAt': PuzzleStatistics._dateTimeToJson(instance.lastPlayedAt),
      'createdAt': PuzzleStatistics._dateTimeToJson(instance.createdAt),
      'updatedAt': PuzzleStatistics._dateTimeToJson(instance.updatedAt),
    };

const _$PuzzleDifficultyEnumMap = {
  PuzzleDifficulty.beginner: 'beginner',
  PuzzleDifficulty.easy: 'easy',
  PuzzleDifficulty.medium: 'medium',
  PuzzleDifficulty.hard: 'hard',
  PuzzleDifficulty.expert: 'expert',
};

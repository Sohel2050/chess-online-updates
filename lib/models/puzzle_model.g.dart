// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleModel _$PuzzleModelFromJson(Map<String, dynamic> json) => PuzzleModel(
  id: json['id'] as String,
  fen: json['fen'] as String,
  solution: (json['solution'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  objective: json['objective'] as String,
  difficulty: $enumDecode(_$PuzzleDifficultyEnumMap, json['difficulty']),
  hints: (json['hints'] as List<dynamic>).map((e) => e as String).toList(),
  rating: (json['rating'] as num).toInt(),
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  opponentPlaysFirst: json['opponentPlaysFirst'] as bool? ?? false,
);

Map<String, dynamic> _$PuzzleModelToJson(PuzzleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fen': instance.fen,
      'solution': instance.solution,
      'objective': instance.objective,
      'difficulty': _$PuzzleDifficultyEnumMap[instance.difficulty]!,
      'hints': instance.hints,
      'rating': instance.rating,
      'tags': instance.tags,
      'opponentPlaysFirst': instance.opponentPlaysFirst,
    };

const _$PuzzleDifficultyEnumMap = {
  PuzzleDifficulty.beginner: 'beginner',
  PuzzleDifficulty.easy: 'easy',
  PuzzleDifficulty.medium: 'medium',
  PuzzleDifficulty.hard: 'hard',
  PuzzleDifficulty.expert: 'expert',
};

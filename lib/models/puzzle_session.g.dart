// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleSession _$PuzzleSessionFromJson(Map<String, dynamic> json) =>
    PuzzleSession(
      puzzle: PuzzleModel.fromJson(json['puzzle'] as Map<String, dynamic>),
      userMoves: (json['userMoves'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      currentMoveIndex: (json['currentMoveIndex'] as num).toInt(),
      hintsUsed: (json['hintsUsed'] as num).toInt(),
      startTime: PuzzleSession._dateTimeFromJsonRequired(
        json['startTime'] as String,
      ),
      state: $enumDecode(_$PuzzleSessionStateEnumMap, json['state']),
      endTime: PuzzleSession._dateTimeFromJson(json['endTime'] as String?),
      incorrectMoves: (json['incorrectMoves'] as num).toInt(),
    );

Map<String, dynamic> _$PuzzleSessionToJson(PuzzleSession instance) =>
    <String, dynamic>{
      'puzzle': instance.puzzle,
      'userMoves': instance.userMoves,
      'currentMoveIndex': instance.currentMoveIndex,
      'hintsUsed': instance.hintsUsed,
      'startTime': PuzzleSession._dateTimeToJson(instance.startTime),
      'state': _$PuzzleSessionStateEnumMap[instance.state]!,
      'endTime': PuzzleSession._dateTimeToJson(instance.endTime),
      'incorrectMoves': instance.incorrectMoves,
    };

const _$PuzzleSessionStateEnumMap = {
  PuzzleSessionState.active: 'active',
  PuzzleSessionState.solved: 'solved',
  PuzzleSessionState.failed: 'failed',
  PuzzleSessionState.abandoned: 'abandoned',
};

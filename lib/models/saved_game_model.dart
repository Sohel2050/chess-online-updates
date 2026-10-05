import 'package:flutter_chess_app/utils/constants.dart';

class SavedGame {
  final String gameId;
  final String userId;
  final String opponentId;
  final String opponentDisplayName;
  final String initialFen;
  final List<String> moves;
  final String result; // e.g., 'win', 'loss', 'draw'
  final String winnerColor; // 'white', 'black', or 'none' for draw
  final String gameMode; // e.g., 'classical', 'blitz', 'tempo'
  final int initialWhitesTime; // in milliseconds
  final int initialBlacksTime; // in milliseconds
  final int finalWhitesTime; // in milliseconds
  final int finalBlacksTime; // in milliseconds
  final DateTime createdAt;

  SavedGame({
    required this.gameId,
    required this.userId,
    required this.opponentId,
    required this.opponentDisplayName,
    required this.initialFen,
    required this.moves,
    required this.result,
    required this.winnerColor,
    required this.gameMode,
    required this.initialWhitesTime,
    required this.initialBlacksTime,
    required this.finalWhitesTime,
    required this.finalBlacksTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      Constants.fieldGameId: gameId,
      Constants.fieldUserId: userId,
      Constants.fieldOpponentId: opponentId,
      Constants.fieldOpponentDisplayName: opponentDisplayName,
      Constants.fieldInitialFen: initialFen,
      Constants.fieldMoves: moves,
      Constants.fieldResult: result,
      Constants.fieldWinnerColor: winnerColor,
      Constants.fieldGameMode: gameMode,
      Constants.fieldInitialWhitesTime: initialWhitesTime,
      Constants.fieldInitialBlacksTime: initialBlacksTime,
      Constants.fieldFinalWhitesTime: finalWhitesTime,
      Constants.fieldFinalBlacksTime: finalBlacksTime,
      Constants.fieldCreatedAt: createdAt,
    };
  }

  factory SavedGame.fromMap(Map<String, dynamic> map) {
    return SavedGame(
      gameId: map[Constants.fieldGameId] ?? '',
      userId: map[Constants.fieldUserId] ?? '',
      opponentId: map[Constants.fieldOpponentId] ?? '',
      opponentDisplayName: map[Constants.fieldOpponentDisplayName] ?? '',
      initialFen: map[Constants.fieldInitialFen] ?? '',
      moves: List<String>.from(map[Constants.fieldMoves] ?? []),
      result: map[Constants.fieldResult] ?? '',
      winnerColor: map[Constants.fieldWinnerColor] ?? '',
      gameMode: map[Constants.fieldGameMode] ?? '',
      initialWhitesTime: map[Constants.fieldInitialWhitesTime] ?? 0,
      initialBlacksTime: map[Constants.fieldInitialBlacksTime] ?? 0,
      finalWhitesTime: map[Constants.fieldFinalWhitesTime] ?? 0,
      finalBlacksTime: map[Constants.fieldFinalBlacksTime] ?? 0,
      createdAt: map[Constants.fieldCreatedAt] is DateTime
          ? map[Constants.fieldCreatedAt]
          : DateTime.tryParse(map[Constants.fieldCreatedAt]?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

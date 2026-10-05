import 'package:flutter_chess_app/utils/constants.dart';

class GameRoom {
  final String gameId;
  final String gameMode;
  final String player1Id;
  final String? player2Id;
  final String player1DisplayName;
  final String? player2DisplayName;
  final String? player1PhotoUrl;
  final String? player2PhotoUrl;
  final String? player1Flag;
  final String? player2Flag;
  final int player1Color; // Squares.white or Squares.black
  final int? player2Color; // Squares.white or Squares.black
  final String status; // "waiting", "active", "completed", "aborted"
  final String fen;
  final List<String> moves; // List of move strings
  final DateTime createdAt;
  final DateTime lastMoveAt;
  final int player1Rating;
  final int? player2Rating;
  final bool ratingBasedSearch;
  final int initialWhitesTime; // in milliseconds
  final int initialBlacksTime; // in milliseconds
  final int whitesTimeRemaining; // in milliseconds, updated on each move
  final int blacksTimeRemaining; // in milliseconds, updated on each move
  final int player1Score;
  final int player2Score;
  final String? winnerId;
  final String? drawOfferedBy; // UID of the player who offered a draw
  final String? drawOfferStatus; // "pending", "accepted", or "rejected"
  final String? rematchOfferedBy; // UID of the player who offered a rematch
  final bool isPrivate;
  final String? spectatorLink;

  // Audio room fields
  final String audioRoomStatus; // none, invite_pending, active, declined, ended
  final String?
  audioRoomInvitedBy; // UID of the player who invited to audio room
  final List<String>
  audioRoomParticipants; // List of UIDs currently in audio room
  final DateTime? audioRoomCreatedAt;
  final DateTime? audioRoomUpdatedAt;

  GameRoom({
    required this.gameId,
    required this.gameMode,
    required this.player1Id,
    this.player2Id,
    required this.player1DisplayName,
    this.player2DisplayName,
    this.player1PhotoUrl,
    this.player2PhotoUrl,
    required this.player1Color,
    this.player2Color,
    required this.player1Flag,
    this.player2Flag,
    required this.status,
    required this.fen,
    required this.moves,
    required this.createdAt,
    required this.lastMoveAt,
    required this.player1Rating,
    this.player2Rating,
    required this.ratingBasedSearch,
    required this.initialWhitesTime,
    required this.initialBlacksTime,
    required this.whitesTimeRemaining,
    required this.blacksTimeRemaining,
    required this.player1Score,
    required this.player2Score,
    this.winnerId,
    this.drawOfferedBy,
    this.drawOfferStatus,
    this.rematchOfferedBy,
    this.isPrivate = false,
    this.spectatorLink,
    this.audioRoomStatus = Constants.audioStatusNone,
    this.audioRoomInvitedBy,
    this.audioRoomParticipants = const [],
    this.audioRoomCreatedAt,
    this.audioRoomUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      Constants.fieldGameId: gameId,
      Constants.fieldGameMode: gameMode,
      Constants.fieldPlayer1Id: player1Id,
      Constants.fieldPlayer2Id: player2Id,
      Constants.fieldPlayer1DisplayName: player1DisplayName,
      Constants.fieldPlayer2DisplayName: player2DisplayName,
      Constants.fieldPlayer1PhotoUrl: player1PhotoUrl,
      Constants.fieldPlayer2PhotoUrl: player2PhotoUrl,
      Constants.fieldPlayer1Flag: player1Flag,
      Constants.fieldPlayer2Flag: player2Flag,
      Constants.fieldPlayer1Color: player1Color,
      Constants.fieldPlayer2Color: player2Color,
      Constants.fieldStatus: status,
      Constants.fieldFen: fen,
      Constants.fieldMoves: moves,
      Constants.fieldCreatedAt: createdAt,
      Constants.fieldLastMoveAt: lastMoveAt,
      Constants.fieldPlayer1Rating: player1Rating,
      Constants.fieldPlayer2Rating: player2Rating,
      Constants.fieldRatingBasedSearch: ratingBasedSearch,
      Constants.fieldInitialWhitesTime: initialWhitesTime,
      Constants.fieldInitialBlacksTime: initialBlacksTime,
      Constants.fieldWhitesTimeRemaining: whitesTimeRemaining,
      Constants.fieldBlacksTimeRemaining: blacksTimeRemaining,
      Constants.fieldPlayer1Score: player1Score,
      Constants.fieldPlayer2Score: player2Score,
      Constants.fieldWinnerId: winnerId,
      Constants.fieldDrawOfferedBy: drawOfferedBy,
      Constants.fieldDrawOfferStatus: drawOfferStatus,
      Constants.fieldRematchOfferedBy: rematchOfferedBy,
      Constants.fieldIsPrivate: isPrivate,
      Constants.fieldSpectatorLink: spectatorLink,
      Constants.fieldAudioRoomStatus: audioRoomStatus,
      Constants.fieldAudioRoomInvitedBy: audioRoomInvitedBy,
      Constants.fieldAudioRoomParticipants: audioRoomParticipants,
      Constants.fieldAudioRoomCreatedAt: audioRoomCreatedAt,
      Constants.fieldAudioRoomUpdatedAt: audioRoomUpdatedAt,
    };
  }

  factory GameRoom.fromMap(Map<String, dynamic> map) {
    return GameRoom(
      gameId: map[Constants.fieldGameId] ?? '',
      gameMode: map[Constants.fieldGameMode] ?? 'Unknown',
      player1Id: map[Constants.fieldPlayer1Id] ?? '',
      player2Id: map[Constants.fieldPlayer2Id],
      player1DisplayName: map[Constants.fieldPlayer1DisplayName] ?? 'Player 1',
      player2DisplayName: map[Constants.fieldPlayer2DisplayName],
      player1PhotoUrl:
          (map[Constants.fieldPlayer1PhotoUrl] as String?)?.isEmpty ?? true
          ? null
          : map[Constants.fieldPlayer1PhotoUrl],
      player2PhotoUrl:
          (map[Constants.fieldPlayer2PhotoUrl] as String?)?.isEmpty ?? true
          ? null
          : map[Constants.fieldPlayer2PhotoUrl],
      player1Flag: map[Constants.fieldPlayer1Flag] ?? '',
      player2Flag: map[Constants.fieldPlayer2Flag] ?? '',
      player1Color: map[Constants.fieldPlayer1Color] ?? 0,
      player2Color: map[Constants.fieldPlayer2Color],
      status: map[Constants.fieldStatus] ?? Constants.statusWaiting,
      fen:
          map[Constants.fieldFen] ??
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: List<String>.from(map[Constants.fieldMoves] ?? []),
      createdAt: map[Constants.fieldCreatedAt] ?? DateTime.now(),
      lastMoveAt: map[Constants.fieldLastMoveAt] ?? DateTime.now(),
      player1Rating: map[Constants.fieldPlayer1Rating] ?? 0,
      player2Rating: map[Constants.fieldPlayer2Rating],
      ratingBasedSearch: map[Constants.fieldRatingBasedSearch] ?? false,
      initialWhitesTime: map[Constants.fieldInitialWhitesTime] ?? 0,
      initialBlacksTime: map[Constants.fieldInitialBlacksTime] ?? 0,
      whitesTimeRemaining: map[Constants.fieldWhitesTimeRemaining] ?? 0,
      blacksTimeRemaining: map[Constants.fieldBlacksTimeRemaining] ?? 0,
      player1Score: map[Constants.fieldPlayer1Score] ?? 0,
      player2Score: map[Constants.fieldPlayer2Score] ?? 0,
      winnerId: map[Constants.fieldWinnerId],
      drawOfferedBy: map[Constants.fieldDrawOfferedBy],
      drawOfferStatus: map[Constants.fieldDrawOfferStatus],
      rematchOfferedBy: map[Constants.fieldRematchOfferedBy],
      isPrivate: map[Constants.fieldIsPrivate] ?? false,
      spectatorLink: map[Constants.fieldSpectatorLink],
      audioRoomStatus:
          map[Constants.fieldAudioRoomStatus] ?? Constants.audioStatusNone,
      audioRoomInvitedBy: map[Constants.fieldAudioRoomInvitedBy],
      audioRoomParticipants: List<String>.from(
        map[Constants.fieldAudioRoomParticipants] ?? [],
      ),
      audioRoomCreatedAt: map[Constants.fieldAudioRoomCreatedAt],
      audioRoomUpdatedAt: map[Constants.fieldAudioRoomUpdatedAt],
    );
  }

  /// Builds a GameRoom from the backend's Socket.IO/REST JSON (MongoDB
  /// document shape) instead of a Firestore snapshot map. Used by
  /// GameProvider's socket event handlers.
  factory GameRoom.fromSocketJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return GameRoom(
      gameId: json['_id']?.toString() ?? '',
      gameMode: json['gameMode'] ?? 'Unknown',
      player1Id: json['player1Id'] ?? '',
      player2Id: json['player2Id'],
      player1DisplayName: json['player1DisplayName'] ?? 'Player 1',
      player2DisplayName: json['player2DisplayName'],
      player1PhotoUrl: (json['player1PhotoUrl'] as String?)?.isEmpty ?? true
          ? null
          : json['player1PhotoUrl'],
      player2PhotoUrl: (json['player2PhotoUrl'] as String?)?.isEmpty ?? true
          ? null
          : json['player2PhotoUrl'],
      player1Flag: json['player1Flag'] ?? '',
      player2Flag: json['player2Flag'] ?? '',
      player1Color: json['player1Color'] ?? 0,
      player2Color: json['player2Color'],
      status: json['status'] ?? Constants.statusWaiting,
      fen: json['fen'] ??
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: List<String>.from(json['moves'] ?? []),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      lastMoveAt: parseDate(json['lastMoveAt']) ?? DateTime.now(),
      player1Rating: json['player1Rating'] ?? 0,
      player2Rating: json['player2Rating'],
      ratingBasedSearch: json['ratingBasedSearch'] ?? false,
      initialWhitesTime: json['initialWhitesTime'] ?? 0,
      initialBlacksTime: json['initialBlacksTime'] ?? 0,
      whitesTimeRemaining: json['whitesTimeRemaining'] ?? 0,
      blacksTimeRemaining: json['blacksTimeRemaining'] ?? 0,
      player1Score: json['player1Score'] ?? 0,
      player2Score: json['player2Score'] ?? 0,
      winnerId: json['winnerId'],
      drawOfferedBy: json['drawOfferedBy'],
      drawOfferStatus: json['drawOfferStatus'],
      rematchOfferedBy: json['rematchOfferedBy'],
      isPrivate: json['isPrivate'] ?? false,
      spectatorLink: json['roomCode'],
      audioRoomStatus: json['audioRoomStatus'] ?? Constants.audioStatusNone,
      audioRoomInvitedBy: json['audioRoomInvitedBy'],
      audioRoomParticipants: List<String>.from(json['audioRoomParticipants'] ?? []),
      audioRoomCreatedAt: null,
      audioRoomUpdatedAt: null,
    );
  }

  GameRoom copyWith({
    String? gameId,
    String? gameMode,
    String? player1Id,
    String? player2Id,
    String? player1DisplayName,
    String? player2DisplayName,
    String? player1PhotoUrl,
    String? player2PhotoUrl,
    String? player1Flag,
    String? player2Flag,
    int? player1Color,
    int? player2Color,
    String? status,
    String? fen,
    List<String>? moves,
    DateTime? createdAt,
    DateTime? lastMoveAt,
    int? player1Rating,
    int? player2Rating,
    bool? ratingBasedSearch,
    int? initialWhitesTime,
    int? initialBlacksTime,
    int? whitesTimeRemaining,
    int? blacksTimeRemaining,
    int? player1Score,
    int? player2Score,
    String? winnerId,
    String? drawOfferedBy,
    String? drawOfferStatus,
    String? rematchOfferedBy,
    bool? isPrivate,
    String? spectatorLink,
    String? audioRoomStatus,
    String? audioRoomInvitedBy,
    List<String>? audioRoomParticipants,
    DateTime? audioRoomCreatedAt,
    DateTime? audioRoomUpdatedAt,
  }) {
    return GameRoom(
      gameId: gameId ?? this.gameId,
      gameMode: gameMode ?? this.gameMode,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      player1DisplayName: player1DisplayName ?? this.player1DisplayName,
      player2DisplayName: player2DisplayName ?? this.player2DisplayName,
      player1PhotoUrl: player1PhotoUrl ?? this.player1PhotoUrl,
      player2PhotoUrl: player2PhotoUrl ?? this.player2PhotoUrl,
      player1Flag: player1Flag ?? this.player1Flag,
      player2Flag: player2Flag ?? this.player2Flag,
      player1Color: player1Color ?? this.player1Color,
      player2Color: player2Color ?? this.player2Color,
      status: status ?? this.status,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      createdAt: createdAt ?? this.createdAt,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      player1Rating: player1Rating ?? this.player1Rating,
      player2Rating: player2Rating ?? this.player2Rating,
      ratingBasedSearch: ratingBasedSearch ?? this.ratingBasedSearch,
      initialWhitesTime: initialWhitesTime ?? this.initialWhitesTime,
      initialBlacksTime: initialBlacksTime ?? this.initialBlacksTime,
      whitesTimeRemaining: whitesTimeRemaining ?? this.whitesTimeRemaining,
      blacksTimeRemaining: blacksTimeRemaining ?? this.blacksTimeRemaining,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      winnerId: winnerId ?? this.winnerId,
      drawOfferedBy: drawOfferedBy ?? this.drawOfferedBy,
      drawOfferStatus: drawOfferStatus ?? this.drawOfferStatus,
      rematchOfferedBy: rematchOfferedBy ?? this.rematchOfferedBy,
      isPrivate: isPrivate ?? this.isPrivate,
      spectatorLink: spectatorLink ?? this.spectatorLink,
      audioRoomStatus: audioRoomStatus ?? this.audioRoomStatus,
      audioRoomInvitedBy: audioRoomInvitedBy ?? this.audioRoomInvitedBy,
      audioRoomParticipants:
          audioRoomParticipants ?? this.audioRoomParticipants,
      audioRoomCreatedAt: audioRoomCreatedAt ?? this.audioRoomCreatedAt,
      audioRoomUpdatedAt: audioRoomUpdatedAt ?? this.audioRoomUpdatedAt,
    );
  }
}

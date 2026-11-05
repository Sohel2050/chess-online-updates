import 'package:flutter_chess_app/services/api_client.dart';

/// One line of a tournament list (backend/controllers/tournamentController.js, `summary`).
class TournamentSummary {
  final String id;
  final String name;
  final String description;
  final String format; // swiss | knockout
  final String status; // registration | running | completed | cancelled
  final int daysPerMove;
  final int roundDays;
  final int maxPlayers;
  final int playerCount;
  final DateTime? startsAt;
  final DateTime? roundDeadline;
  final int currentRound;
  final int totalRounds;
  final String creatorId;
  final String creatorName;
  final bool joined;
  final String? championId;
  final String? championName;

  TournamentSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.format,
    required this.status,
    required this.daysPerMove,
    required this.roundDays,
    required this.maxPlayers,
    required this.playerCount,
    required this.startsAt,
    required this.roundDeadline,
    required this.currentRound,
    required this.totalRounds,
    required this.creatorId,
    required this.creatorName,
    required this.joined,
    required this.championId,
    required this.championName,
  });

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory TournamentSummary.fromJson(Map<String, dynamic> j) => TournamentSummary(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        format: j['format']?.toString() ?? 'swiss',
        status: j['status']?.toString() ?? '',
        daysPerMove: (j['daysPerMove'] as num?)?.toInt() ?? 3,
        roundDays: (j['roundDays'] as num?)?.toInt() ?? 14,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 16,
        playerCount: (j['playerCount'] as num?)?.toInt() ?? 0,
        startsAt: _date(j['startsAt']),
        roundDeadline: _date(j['roundDeadline']),
        currentRound: (j['currentRound'] as num?)?.toInt() ?? 0,
        totalRounds: (j['totalRounds'] as num?)?.toInt() ?? 0,
        creatorId: j['creatorId']?.toString() ?? '',
        creatorName: j['creatorName']?.toString() ?? '',
        joined: j['joined'] == true,
        championId: j['championId']?.toString(),
        championName: j['championName']?.toString(),
      );

  bool get isSwiss => format == 'swiss';
  String get formatText => isSwiss ? 'Swiss' : 'Knockout';
  bool get isRegistration => status == 'registration';
  bool get isRunning => status == 'running';
  bool get isCompleted => status == 'completed';

  /// "starts in 2d 3h" / "starts in 40m" / "starting soon"
  String get startsText {
    final d = startsAt;
    if (d == null) return '';
    final left = d.difference(DateTime.now());
    if (left.isNegative) return 'starting soon';
    if (left.inDays >= 1) return 'starts in ${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours >= 1) return 'starts in ${left.inHours}h ${left.inMinutes % 60}m';
    return 'starts in ${left.inMinutes}m';
  }

  /// "round ends in 5d 2h" for the running round.
  String get roundEndsText {
    final d = roundDeadline;
    if (d == null) return '';
    final left = d.difference(DateTime.now());
    if (left.isNegative) return 'round time is up';
    if (left.inDays >= 1) return 'round ends in ${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours >= 1) return 'round ends in ${left.inHours}h';
    return 'round ends in ${left.inMinutes}m';
  }

  String get statusText {
    switch (status) {
      case 'registration':
        return '$playerCount/$maxPlayers players · $startsText';
      case 'running':
        return 'Round $currentRound of $totalRounds · $playerCount players';
      case 'completed':
        return championName == null ? 'Finished' : 'Winner: $championName';
      default:
        return 'Cancelled';
    }
  }
}

/// A row of the player table. Before the start only name / rating are set; afterwards the standings fields too.
class TournamentRow {
  final String userId;
  final String name;
  final int? rating;
  final int rank;
  final double score;
  final double buchholz;
  final int wins;
  final int draws;
  final int losses;
  final int reached;
  final bool withdrawn;
  final bool champion;

  TournamentRow({
    required this.userId,
    required this.name,
    required this.rating,
    required this.rank,
    required this.score,
    required this.buchholz,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.reached,
    required this.withdrawn,
    required this.champion,
  });

  factory TournamentRow.fromJson(Map<String, dynamic> j) => TournamentRow(
        userId: j['userId']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Player',
        rating: (j['rating'] as num?)?.toInt(),
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toDouble() ?? 0,
        buchholz: (j['buchholz'] as num?)?.toDouble() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        reached: (j['reached'] as num?)?.toInt() ?? 0,
        withdrawn: j['withdrawn'] == true,
        champion: j['champion'] == true,
      );

  /// 2 -> "2", 2.5 -> "2.5"
  String get scoreText => score == score.roundToDouble() ? score.toInt().toString() : score.toStringAsFixed(1);
}

class TournamentPairing {
  final int board;
  final String? whiteId;
  final String? blackId;
  final String? whiteName;
  final String? blackName;
  final String? result; // null = playing | white | black | draw | bye
  final String? winnerId;
  final String? reason;
  final int attempt;
  final bool mine;
  final String? gameId; // every board that has a game (mine: play it; others: watch it)

  TournamentPairing({
    required this.board,
    required this.whiteId,
    required this.blackId,
    required this.whiteName,
    required this.blackName,
    required this.result,
    required this.winnerId,
    required this.reason,
    required this.attempt,
    required this.mine,
    required this.gameId,
  });

  factory TournamentPairing.fromJson(Map<String, dynamic> j) => TournamentPairing(
        board: (j['board'] as num?)?.toInt() ?? 0,
        whiteId: j['whiteId']?.toString(),
        blackId: j['blackId']?.toString(),
        whiteName: j['whiteName']?.toString(),
        blackName: j['blackName']?.toString(),
        result: j['result']?.toString(),
        winnerId: j['winnerId']?.toString(),
        reason: j['reason']?.toString(),
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        mine: j['mine'] == true,
        gameId: j['gameId']?.toString(),
      );

  bool get isBye => result == 'bye';

  /// "1-0", "0-1", "½-½", "bye" or "playing"
  String get resultText {
    switch (result) {
      case 'white':
        return '1-0';
      case 'black':
        return '0-1';
      case 'draw':
        return '½-½';
      case 'bye':
        return 'bye';
      default:
        return 'playing';
    }
  }
}

class TournamentRound {
  final int number;
  final DateTime? deadline;
  final List<TournamentPairing> pairings;
  TournamentRound(this.number, this.deadline, this.pairings);

  factory TournamentRound.fromJson(Map<String, dynamic> j) => TournamentRound(
        (j['number'] as num?)?.toInt() ?? 0,
        j['deadline'] == null ? null : DateTime.tryParse(j['deadline'].toString())?.toLocal(),
        ((j['pairings'] as List?) ?? const []).map((e) => TournamentPairing.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// The game I have to play right now in this tournament.
class TournamentMyGame {
  final String gameId;
  final int round;
  final String color;
  final String opponentName;
  TournamentMyGame(this.gameId, this.round, this.color, this.opponentName);
}

class TournamentDetail {
  final TournamentSummary info;
  final bool canManage;
  final List<TournamentRow> players;
  final List<TournamentRound> rounds;
  final TournamentMyGame? myGame;
  TournamentDetail(this.info, this.canManage, this.players, this.rounds, this.myGame);

  factory TournamentDetail.fromJson(Map<String, dynamic> j) {
    final my = j['myGame'];
    return TournamentDetail(
      TournamentSummary.fromJson(j),
      j['canManage'] == true,
      ((j['players'] as List?) ?? const []).map((e) => TournamentRow.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      ((j['rounds'] as List?) ?? const []).map((e) => TournamentRound.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      my == null
          ? null
          : TournamentMyGame(
              (my as Map)['gameId']?.toString() ?? '',
              (my['round'] as num?)?.toInt() ?? 0,
              my['color']?.toString() ?? 'white',
              my['opponentName']?.toString() ?? '',
            ),
    );
  }
}

class TournamentList {
  final List<TournamentSummary> mine;
  final List<TournamentSummary> open;
  final List<TournamentSummary> running;
  final List<TournamentSummary> finished;
  TournamentList(this.mine, this.open, this.running, this.finished);
}

/// A tournament board as a viewer sees it (read-only): GET /tournaments/:id/games/:gameId.
class WatchedGame {
  final String id;
  final String status; // active | completed | ...
  final String whiteId;
  final String whiteName;
  final String blackName;
  final List<String> moves;
  final DateTime? turnDeadline;
  final String? winnerId;
  final String? endReason;
  final int? round;
  final int? board;

  WatchedGame({
    required this.id,
    required this.status,
    required this.whiteId,
    required this.whiteName,
    required this.blackName,
    required this.moves,
    required this.turnDeadline,
    required this.winnerId,
    required this.endReason,
    required this.round,
    required this.board,
  });

  factory WatchedGame.fromJson(Map<String, dynamic> j) => WatchedGame(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        whiteId: j['whiteId']?.toString() ?? '',
        whiteName: j['whiteName']?.toString() ?? 'White',
        blackName: j['blackName']?.toString() ?? 'Black',
        moves: ((j['moves'] as List?) ?? const []).map((e) => e.toString()).toList(),
        turnDeadline: j['turnDeadline'] == null ? null : DateTime.tryParse(j['turnDeadline'].toString())?.toLocal(),
        winnerId: j['winnerId']?.toString(),
        endReason: j['endReason']?.toString(),
        round: (j['tournamentRound'] as num?)?.toInt(),
        board: (j['tournamentBoard'] as num?)?.toInt(),
      );

  bool get isActive => status == 'active';

  /// White to move after an even number of moves.
  bool get whiteToMove => moves.length.isEven;

  /// "White won (checkmate)", "Black won (timeout)" or "Draw (agreement)" for a finished game.
  String get resultText {
    final how = endReason == null ? '' : ' ($endReason)';
    if (winnerId == null || winnerId!.isEmpty) return 'Draw$how';
    return '${winnerId == whiteId ? 'White' : 'Black'} won$how';
  }

  /// Short text like "2d 5h left" / "3h 10m left".
  String get timeLeftText {
    final d = turnDeadline;
    if (d == null) return '';
    final left = d.difference(DateTime.now());
    if (left.isNegative) return 'time is up';
    if (left.inDays >= 1) return '${left.inDays}d ${left.inHours % 24}h left';
    if (left.inHours >= 1) return '${left.inHours}h ${left.inMinutes % 60}m left';
    return '${left.inMinutes}m left';
  }
}

class TournamentService {
  final ApiClient _api = ApiClient.instance;

  List<TournamentSummary> _list(dynamic raw) =>
      ((raw as List?) ?? const []).map((e) => TournamentSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  TournamentDetail _one(Map<String, dynamic> r) => TournamentDetail.fromJson(Map<String, dynamic>.from(r['tournament'] as Map));

  Future<TournamentList> list() async {
    final r = await _api.get('/tournaments');
    return TournamentList(_list(r['mine']), _list(r['open']), _list(r['running']), _list(r['finished']));
  }

  Future<TournamentDetail> get(String id) async => _one(await _api.get('/tournaments/$id'));

  Future<WatchedGame> watchGame(String tournamentId, String gameId) async {
    final r = await _api.get('/tournaments/$tournamentId/games/$gameId');
    return WatchedGame.fromJson(Map<String, dynamic>.from(r['game'] as Map));
  }

  Future<TournamentDetail> create({
    required String name,
    String description = '',
    required String format,
    required int daysPerMove,
    required int roundDays,
    required int maxPlayers,
    int? rounds,
    required int startsInHours,
  }) async =>
      _one(await _api.post('/tournaments', body: {
        'name': name,
        'description': description,
        'format': format,
        'daysPerMove': daysPerMove,
        'roundDays': roundDays,
        'maxPlayers': maxPlayers,
        if (rounds != null) 'rounds': rounds,
        'startsInHours': startsInHours,
      }));

  Future<TournamentDetail> join(String id) async => _one(await _api.post('/tournaments/$id/join'));
  Future<TournamentDetail> leave(String id) async => _one(await _api.post('/tournaments/$id/leave'));
  Future<TournamentDetail> start(String id) async => _one(await _api.post('/tournaments/$id/start'));
  Future<void> cancel(String id) async => _api.post('/tournaments/$id/cancel');
}

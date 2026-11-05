import 'package:flutter_chess_app/services/api_client.dart';

/// One daily (correspondence) game as the server describes it (backend/controllers/dailyGameController.js).
class DailyGame {
  final String id;
  final String status; // pending | active | completed | declined | expired
  final String whiteName;
  final String blackName;
  final String whiteId;
  final String blackId;
  final String challengerId;
  final int daysPerMove;
  final String fen;
  final List<String> moves;
  final String myColor; // white | black
  final bool myTurn;
  final DateTime? turnDeadline;
  final String? drawOfferedBy;
  final String? winnerId;
  final String? endReason;
  final String? tournamentId; // set when the game belongs to a tournament
  final int? tournamentRound;

  DailyGame({
    required this.id,
    required this.status,
    required this.whiteName,
    required this.blackName,
    required this.whiteId,
    required this.blackId,
    required this.challengerId,
    required this.daysPerMove,
    required this.fen,
    required this.moves,
    required this.myColor,
    required this.myTurn,
    required this.turnDeadline,
    required this.drawOfferedBy,
    required this.winnerId,
    required this.endReason,
    this.tournamentId,
    this.tournamentRound,
  });

  factory DailyGame.fromJson(Map<String, dynamic> j) => DailyGame(
        id: j['id']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        whiteName: j['whiteName']?.toString() ?? 'White',
        blackName: j['blackName']?.toString() ?? 'Black',
        whiteId: j['whiteId']?.toString() ?? '',
        blackId: j['blackId']?.toString() ?? '',
        challengerId: j['challengerId']?.toString() ?? '',
        daysPerMove: (j['daysPerMove'] as num?)?.toInt() ?? 3,
        fen: j['fen']?.toString() ?? '',
        moves: ((j['moves'] as List?) ?? const []).map((e) => e.toString()).toList(),
        myColor: j['myColor']?.toString() ?? 'white',
        myTurn: j['myTurn'] == true,
        turnDeadline: j['turnDeadline'] == null ? null : DateTime.tryParse(j['turnDeadline'].toString())?.toLocal(),
        drawOfferedBy: j['drawOfferedBy']?.toString(),
        winnerId: j['winnerId']?.toString(),
        endReason: j['endReason']?.toString(),
        tournamentId: j['tournamentId']?.toString(),
        tournamentRound: (j['tournamentRound'] as num?)?.toInt(),
      );

  bool get iAmWhite => myColor == 'white';
  String get myId => iAmWhite ? whiteId : blackId;
  String get opponentName => iAmWhite ? blackName : whiteName;
  bool get isActive => status == 'active';
  bool get inTournament => tournamentId != null && tournamentId!.isNotEmpty;

  /// "You won", "You lost" or "Draw" for a finished game.
  String get resultText {
    if (status != 'completed') return status;
    final how = endReason == null ? '' : ' ($endReason)';
    if (winnerId == null || winnerId!.isEmpty) return 'Draw$how';
    return (winnerId == myId ? 'You won' : 'You lost') + how;
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

class DailyGameList {
  final List<DailyGame> invites; // challenges waiting for ME
  final List<DailyGame> sent; // challenges I sent
  final List<DailyGame> active;
  final List<DailyGame> finished;
  DailyGameList(this.invites, this.sent, this.active, this.finished);
}

class DailyGameService {
  final ApiClient _api = ApiClient.instance;

  List<DailyGame> _games(dynamic raw) =>
      ((raw as List?) ?? const []).map((e) => DailyGame.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  DailyGame _one(Map<String, dynamic> r) => DailyGame.fromJson(Map<String, dynamic>.from(r['game'] as Map));

  Future<DailyGameList> list() async {
    final r = await _api.get('/daily');
    return DailyGameList(_games(r['invites']), _games(r['sent']), _games(r['active']), _games(r['finished']));
  }

  Future<DailyGame> get(String id) async => _one(await _api.get('/daily/$id'));

  Future<DailyGame> challenge(String friendId, int daysPerMove, {String color = 'random'}) async =>
      _one(await _api.post('/daily/challenge', body: {'friendId': friendId, 'daysPerMove': daysPerMove, 'color': color}));

  Future<DailyGame> accept(String id) async => _one(await _api.post('/daily/$id/accept'));
  Future<void> decline(String id) async => _api.post('/daily/$id/decline');
  Future<DailyGame> move(String id, String uci) async => _one(await _api.post('/daily/$id/move', body: {'move': uci}));
  Future<DailyGame> resign(String id) async => _one(await _api.post('/daily/$id/resign'));
  Future<DailyGame> draw(String id, String action) async => _one(await _api.post('/daily/$id/draw', body: {'action': action}));
}

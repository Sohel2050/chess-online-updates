import 'dart:math';

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

  /// [meId] = the logged-in user's id. My colour is worked out from the white/black player
  /// ids when possible, so both players can never be shown the same colour.
  factory DailyGame.fromJson(Map<String, dynamic> j, {String? meId}) {
    final whiteId = j['whiteId']?.toString() ?? '';
    final blackId = j['blackId']?.toString() ?? '';
    var color = j['myColor']?.toString() ?? 'white';
    if (meId != null && meId.isNotEmpty && whiteId != blackId) {
      if (meId == whiteId) {
        color = 'white';
      } else if (meId == blackId) {
        color = 'black';
      }
    }
    return DailyGame._fromJson(j, color);
  }

  factory DailyGame._fromJson(Map<String, dynamic> j, String myColor) => DailyGame(
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
        myColor: myColor,
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
  String get opponentId => iAmWhite ? blackId : whiteId;
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

  List<DailyGame> _games(dynamic raw, String? me) => ((raw as List?) ?? const [])
      .map((e) => DailyGame.fromJson(Map<String, dynamic>.from(e as Map), meId: me))
      .toList();

  Future<DailyGame> _one(Map<String, dynamic> r) async =>
      DailyGame.fromJson(Map<String, dynamic>.from(r['game'] as Map), meId: await _api.currentUserId);

  Future<DailyGameList> list() async {
    final r = await _api.get('/daily');
    final me = await _api.currentUserId;
    return DailyGameList(_games(r['invites'], me), _games(r['sent'], me), _games(r['active'], me), _games(r['finished'], me));
  }

  Future<DailyGame> get(String id) async => _one(await _api.get('/daily/$id'));

  /// "random" is decided HERE (a real coin flip) so the server always receives an explicit
  /// colour for the challenger and the opponent gets the other one.
  Future<DailyGame> challenge(String friendId, int daysPerMove, {String color = 'random'}) async {
    final c = color == 'random' ? (Random().nextBool() ? 'white' : 'black') : color;
    return _one(await _api.post('/daily/challenge', body: {'friendId': friendId, 'daysPerMove': daysPerMove, 'color': c}));
  }

  /// Rematch = a new challenge to the same opponent with the colours swapped.
  Future<DailyGame> rematch(DailyGame g) =>
      challenge(g.opponentId, g.daysPerMove, color: g.iAmWhite ? 'black' : 'white');

  Future<DailyGame> accept(String id) async => _one(await _api.post('/daily/$id/accept'));
  Future<void> decline(String id) async => _api.post('/daily/$id/decline');
  Future<DailyGame> move(String id, String uci) async => _one(await _api.post('/daily/$id/move', body: {'move': uci}));
  Future<DailyGame> resign(String id) async => _one(await _api.post('/daily/$id/resign'));
  Future<DailyGame> draw(String id, String action) async => _one(await _api.post('/daily/$id/draw', body: {'action': action}));
}

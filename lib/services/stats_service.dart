import 'package:logger/logger.dart';
import 'api_client.dart';

class RecordStats {
  final int games, wins, draws, losses;
  final double winRate;
  const RecordStats(this.games, this.wins, this.draws, this.losses, this.winRate);

  factory RecordStats.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RecordStats(0, 0, 0, 0, 0);
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return RecordStats(n('games'), n('wins'), n('draws'), n('losses'), (j['winRate'] as num?)?.toDouble() ?? 0);
  }
}

class OpeningStat {
  final String name;
  final RecordStats record;
  const OpeningStat(this.name, this.record);
}

/// Server-computed statistics (roadmap item 10), from GET /users/me/stats.
class PlayerStats {
  final RecordStats total;
  final RecordStats white;
  final RecordStats black;
  final Map<String, List<int>> ratingHistory; // pool -> ratings after each game, oldest first
  final List<OpeningStat> whiteOpenings;
  final List<OpeningStat> blackOpenings;
  final double? accuracy; // average over analysed games, null when none
  final int accuracyGames;
  final int gamesConsidered;

  const PlayerStats({
    required this.total,
    required this.white,
    required this.black,
    required this.ratingHistory,
    required this.whiteOpenings,
    required this.blackOpenings,
    required this.accuracy,
    required this.accuracyGames,
    required this.gamesConsidered,
  });
}

class StatsService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  List<OpeningStat> _openings(dynamic raw) => (raw as List? ?? const []).map((o) {
        final m = Map<String, dynamic>.from(o as Map);
        return OpeningStat(m['name'].toString(), RecordStats.fromJson(m));
      }).toList();

  /// Never throws; null on any error.
  Future<PlayerStats?> load() async {
    try {
      final r = await _api.get('/users/me/stats');
      final byColor = Map<String, dynamic>.from(r['byColor'] ?? const {});
      final openings = Map<String, dynamic>.from(r['openings'] ?? const {});
      final accuracy = Map<String, dynamic>.from(r['accuracy'] ?? const {});
      final history = <String, List<int>>{};
      Map<String, dynamic>.from(r['ratingHistory'] ?? const {}).forEach((pool, list) {
        history[pool] = (list as List)
            .map((p) => ((p as Map)['rating'] as num?)?.toInt())
            .whereType<int>()
            .toList();
      });
      return PlayerStats(
        total: RecordStats.fromJson(r['total'] as Map<String, dynamic>?),
        white: RecordStats.fromJson(byColor['white'] as Map<String, dynamic>?),
        black: RecordStats.fromJson(byColor['black'] as Map<String, dynamic>?),
        ratingHistory: history,
        whiteOpenings: _openings(openings['white']),
        blackOpenings: _openings(openings['black']),
        accuracy: (accuracy['average'] as num?)?.toDouble(),
        accuracyGames: (accuracy['games'] as num?)?.toInt() ?? 0,
        gamesConsidered: (r['gamesConsidered'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      _logger.e('stats load failed: $e');
      return null;
    }
  }
}

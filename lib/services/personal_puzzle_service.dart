import 'package:logger/logger.dart';
import '../models/puzzle_model.dart';
import 'api_client.dart';

/// A puzzle made from a blunder in one of the user's own lost games (roadmap item 9).
class PersonalPuzzle {
  final String id;
  final PuzzleModel puzzle;
  final String playedMove; // what the user played in the game
  final int cpLoss;
  const PersonalPuzzle({
    required this.id,
    required this.puzzle,
    required this.playedMove,
    required this.cpLoss,
  });
}

/// Talks to /puzzles/mine/*. Methods never throw.
class PersonalPuzzleService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  Future<List<PersonalPuzzle>> list() async {
    try {
      final r = await _api.get('/puzzles/mine');
      return (r['puzzles'] as List? ?? const []).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['_id'].toString();
        return PersonalPuzzle(
          id: id,
          playedMove: m['playedMove']?.toString() ?? '',
          cpLoss: (m['cpLoss'] as num?)?.toInt() ?? 0,
          puzzle: PuzzleModel.fromJson({
            'id': id,
            'fen': m['fen'],
            'solution': List<String>.from(m['solution'] ?? const []),
            'objective': 'Find the move you missed',
            'difficulty': 'medium',
            'hints': const [],
            'rating': 1200,
            'tags': const ['myBlunder'],
            'opponentPlaysFirst': false,
          }),
        );
      }).toList();
    } catch (e) {
      _logger.e('personal puzzles list failed: $e');
      return [];
    }
  }

  Future<bool> solve(String id, List<String> moves, String dateKey) async {
    try {
      await _api.post('/puzzles/mine/$id/solve', body: {'moves': moves, 'date': dateKey});
      return true;
    } catch (e) {
      _logger.e('personal puzzle solve failed: $e');
      return false;
    }
  }

  Future<bool> dismiss(String id) async {
    try {
      await _api.post('/puzzles/mine/$id/dismiss');
      return true;
    } catch (e) {
      _logger.e('personal puzzle dismiss failed: $e');
      return false;
    }
  }
}

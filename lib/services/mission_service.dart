import 'package:logger/logger.dart';
import 'api_client.dart';
import 'puzzle_service.dart';

class Mission {
  final String id; // "game" | "puzzle" | "emoji"
  final String title;
  final int target;
  final int progress;
  final int xp;
  final bool completed;
  final bool claimed;

  const Mission({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.xp,
    required this.completed,
    required this.claimed,
  });

  bool get canClaim => completed && !claimed;

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        target: (j['target'] as num?)?.toInt() ?? 1,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        completed: j['completed'] == true,
        claimed: j['claimed'] == true,
      );
}

class MissionsState {
  final List<Mission> missions;
  final int xp;
  const MissionsState({required this.missions, required this.xp});

  bool get hasClaimable => missions.any((m) => m.canClaim);
  int get completedCount => missions.where((m) => m.completed).length;
}

class MissionService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  List<Mission> _parse(dynamic raw) => (raw as List)
      .map((e) => Mission.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  /// Also tells the server this device's UTC offset, so emoji sent during a
  /// game are counted on the user's local day.
  Future<MissionsState?> getMissions() async {
    try {
      final result = await _api.get(
        '/missions',
        query: {
          'date': PuzzleService.localDateKey(),
          'tz': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      return MissionsState(
        missions: _parse(result['missions']),
        xp: (result['xp'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      _logger.e('Error loading missions: $e');
      return null;
    }
  }

  /// Returns the updated state, or null if the claim failed.
  Future<MissionsState?> claim(String missionId) async {
    try {
      final result = await _api.post(
        '/missions/claim',
        body: {'date': PuzzleService.localDateKey(), 'missionId': missionId},
      );
      return MissionsState(
        missions: _parse(result['missions']),
        xp: (result['xp'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      _logger.e('Error claiming mission $missionId: $e');
      return null;
    }
  }
}

import 'package:logger/logger.dart';
import 'api_client.dart';
import 'puzzle_service.dart';

/// The user's daily-activity streak.
class StreakInfo {
  final int current; // consecutive days, ending today (or yesterday if at risk)
  final int best;
  final bool activeToday;
  final bool atRisk; // alive only thanks to yesterday: breaks if today is missed

  const StreakInfo({
    required this.current,
    required this.best,
    required this.activeToday,
    required this.atRisk,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) => StreakInfo(
        current: (json['current'] as num?)?.toInt() ?? 0,
        best: (json['best'] as num?)?.toInt() ?? 0,
        activeToday: json['activeToday'] == true,
        atRisk: json['atRisk'] == true,
      );
}

class StreakService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  /// Days are counted on the user's LOCAL date, so streaks don't break at the
  /// wrong moment for users in other countries.
  Future<StreakInfo?> getStreak() async {
    try {
      final result = await _api.get(
        '/streak',
        query: {'date': PuzzleService.localDateKey()},
      );
      return StreakInfo.fromJson(Map<String, dynamic>.from(result['streak']));
    } catch (e) {
      _logger.e('Error loading streak: $e');
      return null;
    }
  }

  /// [type] is "game" or "puzzle". Returns the updated streak, or null on failure.
  Future<StreakInfo?> recordActivity(String type) async {
    try {
      final result = await _api.post(
        '/streak/activity',
        body: {'date': PuzzleService.localDateKey(), 'type': type},
      );
      return StreakInfo.fromJson(Map<String, dynamic>.from(result['streak']));
    } catch (e) {
      _logger.e('Error recording streak activity: $e');
      return null;
    }
  }
}

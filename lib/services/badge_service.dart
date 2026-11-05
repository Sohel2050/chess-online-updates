import 'package:logger/logger.dart';
import 'api_client.dart';

class BadgeInfo {
  final String id;
  final String group; // wins | streak | puzzles | emoji | level
  final String title;
  final String desc;
  final String icon; // name from the server catalog, mapped in widgets/badge_widgets.dart
  final int target;
  final int progress;
  final bool earned;
  final DateTime? earnedAt;
  final bool isNew; // earned but the player has not been shown it yet

  const BadgeInfo({
    required this.id,
    required this.group,
    required this.title,
    required this.desc,
    required this.icon,
    required this.target,
    required this.progress,
    required this.earned,
    required this.earnedAt,
    required this.isNew,
  });

  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory BadgeInfo.fromJson(Map<String, dynamic> j) => BadgeInfo(
        id: j['id']?.toString() ?? '',
        group: j['group']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        desc: j['desc']?.toString() ?? '',
        icon: j['icon']?.toString() ?? '',
        target: (j['target'] as num?)?.toInt() ?? 1,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        earned: j['earned'] == true,
        earnedAt: DateTime.tryParse(j['earnedAt']?.toString() ?? ''),
        isNew: j['isNew'] == true,
      );
}

class BadgeService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  /// Null if the request failed (offline etc.).
  Future<List<BadgeInfo>?> getBadges() async {
    try {
      final result = await _api.get('/badges');
      return (result['badges'] as List)
          .map((e) => BadgeInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _logger.e('Error loading badges: $e');
      return null;
    }
  }

  Future<void> markSeen() async {
    try {
      await _api.post('/badges/seen');
    } catch (e) {
      _logger.e('Error marking badges seen: $e');
    }
  }
}

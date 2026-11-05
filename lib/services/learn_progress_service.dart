import 'package:flutter_chess_app/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the player has finished in the Learn section (roadmap item 11). Stored on the device only:
/// openings, endgame drills and lessons all work offline, so there is nothing for the server to know.
class LearnProgress {
  final Set<String> openingsDone;
  final Set<String> openingsPerfect;
  final Set<String> endgamesDone;
  final Set<String> lessonsDone;

  LearnProgress({
    required this.openingsDone,
    required this.openingsPerfect,
    required this.endgamesDone,
    required this.lessonsDone,
  });

  factory LearnProgress.empty() => LearnProgress(
        openingsDone: <String>{},
        openingsPerfect: <String>{},
        endgamesDone: <String>{},
        lessonsDone: <String>{},
      );

  static const _kOpenings = 'learn.openings.done';
  static const _kPerfect = 'learn.openings.perfect';
  static const _kEndgames = 'learn.endgames.done';
  static const _kLessons = 'learn.lessons.done';

  static Future<LearnProgress> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return LearnProgress(
        openingsDone: (p.getStringList(_kOpenings) ?? const <String>[]).toSet(),
        openingsPerfect: (p.getStringList(_kPerfect) ?? const <String>[]).toSet(),
        endgamesDone: (p.getStringList(_kEndgames) ?? const <String>[]).toSet(),
        lessonsDone: (p.getStringList(_kLessons) ?? const <String>[]).toSet(),
      );
    } catch (_) {
      return LearnProgress.empty();
    }
  }

  Future<void> _save(String key, Set<String> value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(key, value.toList());
    } catch (_) {
      // Progress is a convenience; never break a lesson because storage failed.
    }
  }

  /// [perfect] = finished without a mistake and without a hint.
  static Future<void> markOpening(String id, {required bool perfect}) async {
    final cur = await load();
    cur.openingsDone.add(id);
    if (perfect) cur.openingsPerfect.add(id);
    await cur._save(_kOpenings, cur.openingsDone);
    await cur._save(_kPerfect, cur.openingsPerfect);
    AnalyticsService.instance.track('lesson_done', {'kind': 'opening'});
  }

  static Future<void> markEndgame(String id) async {
    final cur = await load();
    cur.endgamesDone.add(id);
    await cur._save(_kEndgames, cur.endgamesDone);
    AnalyticsService.instance.track('lesson_done', {'kind': 'endgame'});
  }

  static Future<void> markLesson(String id) async {
    final cur = await load();
    cur.lessonsDone.add(id);
    await cur._save(_kLessons, cur.lessonsDone);
    AnalyticsService.instance.track('lesson_done', {'kind': 'lesson'});
  }
}

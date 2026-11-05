import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad frequency limits. Values come from the admin panel
/// (`/public/ads-settings`); 0 = no limit.
class AdFrequency {
  AdFrequency._();

  static int appOpenMaxPerDay = 3;
  static double appOpenMinGapHours = 4;
  static int interstitialMaxPerHour = 3;
  static int interstitialEveryNGameOvers = 2;

  static const _kAppOpen = 'adf_app_open_ms';
  static const _kInter = 'adf_inter_ms';
  static const _kGameOvers = 'adf_game_overs';

  static void applySettings(Map s) {
    int i(dynamic v, int d) => v is num ? v.toInt() : d;
    double f(dynamic v, double d) => v is num ? v.toDouble() : d;
    appOpenMaxPerDay = i(s['appOpenMaxPerDay'], appOpenMaxPerDay);
    appOpenMinGapHours = f(s['appOpenMinGapHours'], appOpenMinGapHours);
    interstitialMaxPerHour =
        i(s['interstitialMaxPerHour'], interstitialMaxPerHour);
    interstitialEveryNGameOvers =
        i(s['interstitialEveryNGameOvers'], interstitialEveryNGameOvers);
  }

  static Future<List<int>> _load(String key, Duration keep) async {
    final p = await SharedPreferences.getInstance();
    final cutoff = DateTime.now().millisecondsSinceEpoch - keep.inMilliseconds;
    return (p.getStringList(key) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .where((t) => t > cutoff)
        .toList();
  }

  static Future<void> _save(String key, List<int> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, l.map((e) => '$e').toList());
  }

  // ---------- App open ----------
  static Future<bool> canShowAppOpen() async {
    final l = await _load(_kAppOpen, const Duration(days: 2));
    final now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    if (appOpenMaxPerDay > 0 &&
        l.where((t) => t >= midnight).length >= appOpenMaxPerDay) {
      return false;
    }
    if (appOpenMinGapHours > 0 && l.isNotEmpty) {
      final gapMs = now.millisecondsSinceEpoch - l.reduce(max);
      if (gapMs < appOpenMinGapHours * 3600000) return false;
    }
    return true;
  }

  static Future<void> markAppOpenShown() async {
    final l = await _load(_kAppOpen, const Duration(days: 2));
    l.add(DateTime.now().millisecondsSinceEpoch);
    await _save(_kAppOpen, l);
  }

  // ---------- Interstitial (call once per finished game) ----------
  static Future<bool> shouldShowGameOverInterstitial() async {
    final p = await SharedPreferences.getInstance();
    final count = (p.getInt(_kGameOvers) ?? 0) + 1;
    final every =
        interstitialEveryNGameOvers < 1 ? 1 : interstitialEveryNGameOvers;
    if (count < every) {
      await p.setInt(_kGameOvers, count);
      return false;
    }
    final l = await _load(_kInter, const Duration(hours: 1));
    if (interstitialMaxPerHour > 0 && l.length >= interstitialMaxPerHour) {
      await p.setInt(_kGameOvers, count); // hourly cap hit, retry next game
      return false;
    }
    await p.setInt(_kGameOvers, 0);
    l.add(DateTime.now().millisecondsSinceEpoch);
    await _save(_kInter, l);
    return true;
  }
}

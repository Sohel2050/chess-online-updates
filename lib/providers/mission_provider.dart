import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mission_service.dart';
import '../utils/levels.dart';

class MissionProvider extends ChangeNotifier {
  final MissionService _service = MissionService();
  MissionsState? _state;
  bool _claiming = false;

  // XP is kept on the device too, so unlocked themes still work with no network.
  static const _xpKey = 'cachedXp';
  int _cachedXp = 0;

  MissionProvider() {
    _loadCachedXp();
  }

  MissionsState? get state => _state;
  bool get claiming => _claiming;

  /// The server's number once loaded, else the last one seen on this device.
  int get xp => _state?.xp ?? _cachedXp;
  LevelInfo get levelInfo => levelForXp(xp);
  int get level => levelInfo.level;

  Future<void> _loadCachedXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedXp = prefs.getInt(_xpKey) ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveXp(int xp) async {
    _cachedXp = xp;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_xpKey, xp);
    } catch (_) {}
  }

  /// Call on logout so the next account on this phone does not inherit this one's level.
  Future<void> reset() async {
    _state = null;
    await _saveXp(0);
    notifyListeners();
  }

  Future<void> refresh() async {
    final s = await _service.getMissions();
    if (s != null) {
      _state = s;
      await _saveXp(s.xp);
      notifyListeners();
    }
  }

  /// Returns true if the reward was paid out.
  Future<bool> claim(String missionId) async {
    if (_claiming) return false;
    _claiming = true;
    notifyListeners();
    final s = await _service.claim(missionId);
    _claiming = false;
    if (s != null) {
      _state = s;
      await _saveXp(s.xp);
    } else {
      await refresh(); // e.g. already claimed elsewhere: show the true state
    }
    notifyListeners();
    return s != null;
  }
}

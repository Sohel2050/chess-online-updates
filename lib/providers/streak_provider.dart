import 'package:flutter/foundation.dart';
import '../services/streak_service.dart';

class StreakProvider extends ChangeNotifier {
  final StreakService _service = StreakService();
  StreakInfo? _info;

  StreakInfo? get info => _info;

  Future<void> refresh() async {
    final info = await _service.getStreak();
    if (info != null) {
      _info = info;
      notifyListeners();
    }
  }

  /// LEGACY: the server no longer counts anything the app reports here (see STEP5_ANTICHEAT.md).
  /// Use [refresh] after a game or puzzle instead.
  Future<void> recordActivity(String type) async {
    final info = await _service.recordActivity(type);
    if (info != null) {
      _info = info;
      notifyListeners();
    }
  }
}

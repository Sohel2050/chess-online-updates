import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../widgets/badge_widgets.dart';

class BadgeProvider extends ChangeNotifier {
  final BadgeService _service = BadgeService();
  List<BadgeInfo> _badges = const [];
  bool _loaded = false;
  bool _celebrating = false;

  List<BadgeInfo> get badges => _badges;
  bool get loaded => _loaded;
  int get earnedCount => _badges.where((b) => b.earned).length;

  Future<void> refresh() async {
    final list = await _service.getBadges();
    if (list != null) {
      _badges = list;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Refreshes, and if there are badges the player has not been shown yet, shows a popup once.
  /// Skipped when [context]'s screen is not the one on top (e.g. a game is open over the home screen).
  Future<void> refreshAndCelebrate(BuildContext context) async {
    await refresh();
    if (!context.mounted || _celebrating) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final fresh = _badges.where((b) => b.isNew).toList();
    if (fresh.isEmpty) return;
    _celebrating = true;
    try {
      await showNewBadgesDialog(context, fresh);
      await _service.markSeen();
      await refresh();
    } finally {
      _celebrating = false;
    }
  }

  /// Call on logout so the next account does not see this one's badges.
  void reset() {
    _badges = const [];
    _loaded = false;
    notifyListeners();
  }
}

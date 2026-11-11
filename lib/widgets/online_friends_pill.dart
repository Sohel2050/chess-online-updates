import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';

/// Header pill "friends online / all players online", e.g. 3/5900:
/// 3 of my friends are online out of 5900 players online in total.
class OnlineFriendsPill extends StatefulWidget {
  /// Logged-in user id; null (guest) shows 0 friends online.
  final String? userId;

  const OnlineFriendsPill({super.key, required this.userId});

  @override
  State<OnlineFriendsPill> createState() => _OnlineFriendsPillState();
}

class _OnlineFriendsPillState extends State<OnlineFriendsPill> {
  static const _green = Color(0xFF22C55E);
  StreamSubscription<List<ChessUser>>? _friendsSub;
  StreamSubscription<Map<String, int>>? _statsSub;
  int _friendsOnline = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    // Subscribe manually (once) instead of handing single-subscription
    // streams to a StreamBuilder, which re-listens when it is remounted
    // (e.g. on tab change) and throws "Stream has already been listened to".
    _statsSub = UserService().getGameStatsStream().listen((s) {
      if (!mounted) return;
      setState(() => _total = s['online'] ?? 0);
    }, onError: (_) {});
    _subscribeFriends();
  }

  void _subscribeFriends() {
    _friendsSub?.cancel();
    _friendsSub = null;
    final id = widget.userId;
    if (id == null || id.isEmpty) {
      _friendsOnline = 0;
      return;
    }
    _friendsSub = FriendService().getFriends(id).listen((list) {
      if (!mounted) return;
      setState(() => _friendsOnline = list.where((f) => f.isOnline).length);
    }, onError: (_) {});
  }

  @override
  void didUpdateWidget(OnlineFriendsPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _subscribeFriends();
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 76),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _pill(context),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.4)),
      ),
      child: Tooltip(
        message: 'Friends online / players online',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people, color: _green, size: 13),
            const SizedBox(width: 3),
            Text(
              '$_friendsOnline/$_total',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

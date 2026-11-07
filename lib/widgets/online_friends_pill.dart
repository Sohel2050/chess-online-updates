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
  Stream<List<ChessUser>>? _friends;
  late Stream<Map<String, int>> _stats;

  @override
  void initState() {
    super.initState();
    _stats = UserService().getGameStatsStream();
    _friends = _friendsStream();
  }

  Stream<List<ChessUser>>? _friendsStream() {
    final id = widget.userId;
    if (id == null || id.isEmpty) return null;
    return FriendService().getFriends(id);
  }

  @override
  void didUpdateWidget(OnlineFriendsPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _friends = _friendsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.4)),
      ),
      child: StreamBuilder<Map<String, int>>(
        stream: _stats,
        builder: (context, statsSnap) {
          final total = statsSnap.data?['online'] ?? 0;
          return StreamBuilder<List<ChessUser>>(
            stream: _friends,
            builder: (context, friendsSnap) {
              final friendsOnline =
                  (friendsSnap.data ?? const <ChessUser>[]).where((f) => f.isOnline).length;
              return Tooltip(
                message: 'Friends online / players online',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, color: _green, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '$friendsOnline/$total',
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';

/// Small pill for one game mode card: players waiting for a game in that
/// mode and games running in it. Each pill listens to its own live stream
/// (the stream is cancelled automatically when the card leaves the screen).
class ModeLiveStats extends StatefulWidget {
  /// Game mode key, e.g. "60 sec/move".
  final String gameMode;

  const ModeLiveStats({super.key, required this.gameMode});

  @override
  State<ModeLiveStats> createState() => _ModeLiveStatsState();
}

class _ModeLiveStatsState extends State<ModeLiveStats> {
  late Stream<Map<String, int>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = UserService().getGameStatsStream(gameMode: widget.gameMode);
  }

  @override
  void didUpdateWidget(ModeLiveStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameMode != widget.gameMode) {
      _stream = UserService().getGameStatsStream(gameMode: widget.gameMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _stream,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final waiting = stats?['waiting'] ?? 0;
        final games = stats?['games'] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Waiting',
                child: _item(Icons.hourglass_top_rounded, waiting),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Games running',
                child: _item(Icons.sports_esports, games),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _item(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';

class OnlinePlayersCountWidget extends StatefulWidget {
  final String? selectedGameMode;

  const OnlinePlayersCountWidget({super.key, this.selectedGameMode});

  @override
  State<OnlinePlayersCountWidget> createState() =>
      _OnlinePlayersCountWidgetState();
}

class _OnlinePlayersCountWidgetState extends State<OnlinePlayersCountWidget> {
  final UserService _userService = UserService();
  Stream<Map<String, int>>? _statsStream;

  @override
  void initState() {
    super.initState();
    _statsStream = _userService.getGameStatsStream(
      gameMode: widget.selectedGameMode,
    );
  }

  @override
  void didUpdateWidget(OnlinePlayersCountWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGameMode != widget.selectedGameMode) {
      setState(() {
        _statsStream = _userService.getGameStatsStream(
          gameMode: widget.selectedGameMode,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onContainer = Theme.of(context).colorScheme.onPrimaryContainer;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10.0),
          ),
        ),
        child: StreamBuilder<Map<String, int>>(
          stream: _statsStream,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final online = stats?['online'] ?? 0;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            if (isLoading) {
              return SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onContainer,
                ),
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatChip(
                  icon: Icons.people,
                  count: online,
                  label: 'Online',
                  color: onContainer,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

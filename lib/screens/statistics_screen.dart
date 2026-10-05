import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';

class StatisticsScreen extends StatelessWidget {
  final ChessUser user;

  const StatisticsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Stats for ${user.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _buildStatRow(
              context,
              'Classical Rating:',
              user.classicalRating.toString(),
            ),
            _buildStatRow(
              context,
              'Blitz Rating:',
              user.blitzRating.toString(),
            ),
            _buildStatRow(
              context,
              'Tempo Rating:',
              user.tempoRating.toString(),
            ),
            const Divider(),
            _buildStatRow(
              context,
              'Games Played:',
              user.gamesPlayed.toString(),
            ),
            _buildStatRow(
              context,
              'Games Won:',
              user.gamesWon.toString(),
              color: Colors.green,
            ),
            _buildStatRow(
              context,
              'Games Lost:',
              user.gamesLost.toString(),
              color: Colors.red,
            ),
            _buildStatRow(
              context,
              'Games Drawn:',
              user.gamesDraw.toString(),
              color: Colors.blueGrey,
            ),
            const Divider(),
            Text(
              'Win Streaks:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...user.winStreak.entries.map(
              (entry) => _buildStatRow(
                context,
                '${entry.key} Streak:',
                entry.value.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

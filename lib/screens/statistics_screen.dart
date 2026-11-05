import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/analytics_service.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import '../services/stats_service.dart';

class StatisticsScreen extends StatefulWidget {
  final ChessUser user;

  const StatisticsScreen({super.key, required this.user});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  PlayerStats? _stats;
  bool _loading = true;
  String _pool = 'classical';

  ChessUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('statistics');
    StatsService().load().then((s) {
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SingleChildScrollView(
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
            const Divider(),
            ..._buildServerStats(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildServerStats(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return [const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))];
    }
    final st = _stats;
    if (st == null || st.total.games == 0) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            st == null ? 'Detailed statistics are not available right now.' : 'Play some online games to see detailed statistics.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ];
    }
    final history = st.ratingHistory[_pool] ?? const <int>[];
    return [
      Text('Rating graph', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final p in const ['classical', 'blitz', 'tempo'])
            ChoiceChip(
              label: Text(p[0].toUpperCase() + p.substring(1)),
              selected: _pool == p,
              onSelected: (_) => setState(() => _pool = p),
            ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 160,
        width: double.infinity,
        child: history.length < 2
            ? const Center(child: Text('Not enough games in this mode yet.'))
            : CustomPaint(painter: _RatingGraphPainter(history, theme.colorScheme.primary, theme.colorScheme.onSurfaceVariant)),
      ),
      if (history.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Last ${history.length} games: ${history.first} to ${history.last}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      const Divider(height: 32),
      Text('Win rate by colour', style: theme.textTheme.titleMedium),
      _buildStatRow(context, 'As White:', _record(st.white)),
      _buildStatRow(context, 'As Black:', _record(st.black)),
      const Divider(),
      _buildStatRow(
        context,
        'Average accuracy:',
        st.accuracy == null ? 'not analysed yet' : '${st.accuracy!.toStringAsFixed(1)}% (${st.accuracyGames} games)',
      ),
      const Divider(),
      Text('Favourite openings', style: theme.textTheme.titleMedium),
      ..._openingRows(context, 'As White', st.whiteOpenings),
      ..._openingRows(context, 'As Black', st.blackOpenings),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Based on your last ${st.gamesConsidered} finished online games.', style: theme.textTheme.bodySmall),
      ),
    ];
  }

  String _record(RecordStats r) =>
      r.games == 0 ? '-' : '${(r.winRate * 100).round()}% (${r.wins}W ${r.draws}D ${r.losses}L)';

  List<Widget> _openingRows(BuildContext context, String title, List<OpeningStat> list) {
    if (list.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      for (final o in list)
        _buildStatRow(context, o.name, '${o.record.games} games, ${(o.record.winRate * 100).round()}% won'),
    ];
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

/// Simple line graph of ratings, oldest to newest.
class _RatingGraphPainter extends CustomPainter {
  final List<int> values;
  final Color line;
  final Color axis;
  _RatingGraphPainter(this.values, this.line, this.axis);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (hi - lo) < 10 ? 10.0 : (hi - lo);
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    Offset at(int i) => Offset(
          pad + w * i / (values.length - 1),
          pad + h * (1 - (values[i] - lo) / span),
        );

    final grid = Paint()
      ..color = axis.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(pad, pad), Offset(size.width - pad, pad), grid);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(size.width - pad, size.height - pad), grid);

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _RatingGraphPainter old) => old.values != values || old.line != line;
}

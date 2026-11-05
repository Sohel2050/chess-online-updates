import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/leaderboard_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';

/// Weekly leaderboard (everyone, top 50) and friends leaderboard. Points come from the server only
/// (online games: win 3 / draw 2 / loss 1, solved puzzle 1). The week resets Monday 00:00 UTC.
class WeeklyLeaderboardScreen extends StatelessWidget {
  const WeeklyLeaderboardScreen({super.key});

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How points work'),
        content: const Text(
          'Online game: win 3, draw 2, loss 1.\n'
          'Solved puzzle: 1.\n\n'
          'Games against the computer do not count. '
          'The week resets every Monday (00:00 UTC). '
          'At equal points, whoever reached them first is ahead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = LeaderboardService();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'How points work',
              onPressed: () => _showRules(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Friends'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BoardTab(load: service.getWeekly, showTopNote: true),
            _BoardTab(load: service.getFriends, showTopNote: false),
          ],
        ),
      ),
    );
  }
}

class _BoardTab extends StatefulWidget {
  final Future<LeaderboardData?> Function() load;
  final bool showTopNote;

  const _BoardTab({required this.load, required this.showTopNote});

  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> with AutomaticKeepAliveClientMixin {
  LeaderboardData? _data;
  bool _loading = true;
  bool _failed = false;
  Timer? _ticker;
  final Stopwatch _sinceLoad = Stopwatch();
  Duration _left = Duration.zero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    final data = await widget.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _failed = _data == null; // keep showing the old board if a refresh fails
      } else {
        _failed = false;
        _data = data;
        _sinceLoad
          ..reset()
          ..start();
        _left = data.untilReset;
      }
    });
  }

  void _tick() {
    final data = _data;
    if (data == null || !mounted) return;
    final left = data.untilReset - _sinceLoad.elapsed;
    if (left <= Duration.zero) {
      // The week just ended: load the new (empty) board once.
      if (!_loading) _refresh();
      return;
    }
    setState(() => _left = left);
  }

  String _formatLeft(Duration d) {
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (days > 0) return '${days}d ${two(h)}h ${two(m)}m';
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    if (data == null) {
      if (_loading) return const Center(child: CircularProgressIndicator.adaptive());
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_failed ? 'Could not load the leaderboard.' : 'Nothing to show.'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Resets in ${_formatLeft(_left)}',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: data.entries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No points yet this week.\nPlay an online game or solve a puzzle!',
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: data.entries.length,
                    itemBuilder: (context, i) => _row(context, data.entries[i]),
                  ),
          ),
        ),
        _myRankBar(context, data),
      ],
    );
  }

  Widget _row(BuildContext context, LeaderboardEntry e) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: e.isMe ? scheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          child: Text('#${e.rank}',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(e.isMe ? '${e.displayName} (you)' : e.displayName,
                  overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Lv ${e.level}',
                  style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
        subtitle: Text('${e.points} pts'),
        trailing: ProfileImageWidget(
          imageUrl: e.photoUrl,
          radius: 20,
          isEditable: false,
          backgroundColor: scheme.primaryContainer,
        ),
      ),
    );
  }

  Widget _myRankBar(BuildContext context, LeaderboardData data) {
    final scheme = Theme.of(context).colorScheme;
    final text = data.myRank == null
        ? 'You have no points yet this week'
        : 'Your rank: #${data.myRank}  ·  ${data.myPoints} pts';
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 20),
              const SizedBox(width: 8),
              Text(text, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

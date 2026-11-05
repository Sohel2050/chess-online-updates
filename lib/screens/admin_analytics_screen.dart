import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';

/// Admin: anonymous usage summary (GET /admin/analytics/summary). The server checks the admin JWT.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  int _days = 14;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiClient.instance.get('/admin/analytics/summary', query: {'days': _days});
      if (!mounted) return;
      setState(() {
        _s = Map<String, dynamic>.from(r['summary'] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load. Check your connection.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _list(String key) =>
      ((_s?[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage summary'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Period',
            icon: const Icon(Icons.date_range),
            initialValue: _days,
            onSelected: (v) {
              _days = v;
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Try again')),
                    ]),
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final dau = _list('dailyActiveUsers');
    final maxUsers = dau.fold<int>(1, (m, d) => ((d['users'] as num).toInt() > m) ? (d['users'] as num).toInt() : m);
    final ret = _s?['retention'] as Map?;
    final solve = _s?['puzzleSolveRate'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _title('Active players per day (last $_days days)'),
        Text('Average: ${_s?['averageDailyUsers'] ?? 0} per day'),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in dau)
                Expanded(
                  child: Tooltip(
                    message: '${d['day']}: ${d['users']}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 4 + 86 * ((d['users'] as num).toInt() / maxUsers),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _title('Retention of new players'),
        _retentionRow('Day 1', ret?['d1']),
        _retentionRow('Day 7', ret?['d7']),
        _title('Games ended'),
        ..._rows(_list('gamesEnded'), (r) => '${r['mode']} / ${r['result']}'),
        _title('Puzzles${solve == null ? '' : ' (solved $solve%)'}'),
        ..._rows(_list('puzzleResults'), (r) => '${r['kind']} / ${r['result']}'),
        _title('Most opened screens'),
        ..._rows(_list('topScreens'), (r) => '${r['name'] ?? 'unknown'}'),
        _title('Features used'),
        ..._rows(_list('topFeatures'), (r) => '${r['name'] ?? 'unknown'}'),
        _title('App versions (players)'),
        for (final v in _list('appVersions'))
          ListTile(dense: true, title: Text('${v['version']}'), trailing: Text('${v['users']}')),
        _title('All events'),
        ..._rows(_list('eventsByName'), (r) => '${r['name']}'),
      ],
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _retentionRow(String label, dynamic v) {
    final m = v is Map ? v : const {};
    final rate = m['rate'];
    final users = m['users'] ?? 0;
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text('$users new players counted'),
      trailing: Text(rate == null ? 'no data yet' : '$rate%'),
    );
  }

  List<Widget> _rows(List<Map<String, dynamic>> rows, String Function(Map<String, dynamic>) label) {
    if (rows.isEmpty) return [const ListTile(dense: true, title: Text('No data yet'))];
    return [for (final r in rows) ListTile(dense: true, title: Text(label(r)), trailing: Text('${r['count']}'))];
  }
}

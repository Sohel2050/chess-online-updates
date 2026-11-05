import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';

/// Admin: reports about tournaments / clubs / announcements, the tournament list and the club list.
/// The server decides who may call these endpoints (admin JWT); this screen only shows the results.
class AdminCommunityScreen extends StatelessWidget {
  const AdminCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tournaments and clubs'),
          bottom: const TabBar(tabs: [Tab(text: 'Reports'), Tab(text: 'Tournaments'), Tab(text: 'Clubs')]),
        ),
        body: const TabBarView(children: [_ReportsTab(), _TournamentsTab(), _ClubsTab()]),
      ),
    );
  }
}

String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> _confirm(BuildContext context, String title, String text) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
      ],
    ),
  );
  return ok == true;
}

/// Loads a list once and again on pull-to-refresh; shared by the three tabs.
class _ListTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, Map<String, dynamic>, Future<void> Function() reload) row;
  final String empty;
  final Widget? header;
  const _ListTab({super.key, required this.load, required this.row, required this.empty, this.header});

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  List<Map<String, dynamic>>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final r = await widget.load();
      if (mounted) setState(() {
        _rows = r;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(children: [
        if (widget.header != null) widget.header!,
        if (rows.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Text(widget.empty, textAlign: TextAlign.center)),
        for (final r in rows) widget.row(context, r, _reload),
      ]),
    );
  }
}

// ====================================================================== reports

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  static const _kinds = {'tournament': 'Tournament', 'club': 'Club', 'club_post': 'Announcement', 'club_message': 'Chat message'};

  @override
  Widget build(BuildContext context) {
    final service = ClubService();
    return _ListTab(
      load: () => service.adminReports(),
      empty: 'No open reports.',
      row: (context, r, reload) {
        final kind = r['kind']?.toString() ?? '';
        final text = r['targetText']?.toString() ?? '';
        final details = r['details']?.toString() ?? '';
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_kinds[kind] ?? kind}: ${r['targetName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Reason: ${r['reason']} · ${r['reporters']} reporter${r['reporters'] == 1 ? '' : 's'}'),
              if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('"$text"')),
              if (details.isNotEmpty) Text('Details: $details', style: Theme.of(context).textTheme.bodySmall),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () async {
                    try {
                      await service.adminResolve(r['id'].toString(), 'dismiss');
                      await reload();
                    } catch (e) {
                      if (context.mounted) _toast(context, _err(e));
                    }
                  },
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: () async {
                    final what = kind == 'tournament' ? 'Cancel this tournament?' : kind == 'club' ? 'Delete this club?' : 'Delete this announcement?';
                    if (!await _confirm(context, what, 'This cannot be undone.')) return;
                    try {
                      await service.adminResolve(r['id'].toString(), 'remove');
                      await reload();
                    } catch (e) {
                      if (context.mounted) _toast(context, _err(e));
                    }
                  },
                  child: Text(kind == 'tournament' ? 'Cancel it' : 'Remove'),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ====================================================================== tournaments

class _TournamentsTab extends StatefulWidget {
  const _TournamentsTab();

  @override
  State<_TournamentsTab> createState() => _TournamentsTabState();
}

class _TournamentsTabState extends State<_TournamentsTab> {
  final ClubService _service = ClubService();
  String _status = 'running';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, children: [
          for (final s in const ['registration', 'running', 'completed', 'cancelled'])
            ChoiceChip(label: Text(s), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
      ),
      Expanded(
        child: _ListTab(
          key: ValueKey(_status),
          load: () => _service.adminTournaments(_status),
          empty: 'Nothing here.',
          row: (context, t, reload) {
            final open = t['status'] == 'registration' || t['status'] == 'running';
            final reports = (t['openReports'] as num?)?.toInt() ?? 0;
            return ListTile(
              title: Text(t['name']?.toString() ?? ''),
              subtitle: Text('${t['format']} · ${t['playerCount']} players · by ${t['creatorName']}'
                  '${t['status'] == 'running' ? ' · round ${t['currentRound']}/${t['totalRounds']}' : ''}'
                  '${reports > 0 ? ' · $reports open report${reports == 1 ? '' : 's'}' : ''}'),
              trailing: open
                  ? IconButton(
                      icon: const Icon(Icons.cancel_outlined),
                      tooltip: 'Cancel tournament',
                      onPressed: () async {
                        if (!await _confirm(context, 'Cancel this tournament?', 'All players are told. Games that are still running end as a draw.')) return;
                        try {
                          await _service.adminCancelTournament(t['id'].toString());
                          await reload();
                        } catch (e) {
                          if (context.mounted) _toast(context, _err(e));
                        }
                      },
                    )
                  : null,
            );
          },
        ),
      ),
    ]);
  }
}

// ====================================================================== clubs

class _ClubsTab extends StatefulWidget {
  const _ClubsTab();

  @override
  State<_ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<_ClubsTab> {
  final ClubService _service = ClubService();
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => setState(() => _query = v.trim()),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search clubs'),
        ),
      ),
      Expanded(
        child: _ListTab(
          key: ValueKey(_query),
          load: () => _service.adminClubs(q: _query),
          empty: 'No clubs.',
          row: (context, c, reload) => ListTile(
            title: Text(c['name']?.toString() ?? ''),
            subtitle: Text('${c['memberCount']} members · owner ${c['ownerName']}${(c['description']?.toString() ?? '').isEmpty ? '' : '\n${c['description']}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete club',
              onPressed: () async {
                if (!await _confirm(context, 'Delete this club?', 'Members and announcements are removed. This cannot be undone.')) return;
                try {
                  await _service.adminDeleteClub(c['id'].toString());
                  await reload();
                } catch (e) {
                  if (context.mounted) _toast(context, _err(e));
                }
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

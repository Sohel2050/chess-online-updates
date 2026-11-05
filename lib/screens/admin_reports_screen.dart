import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/moderation_service.dart';

/// Admin: review queue for game reports and ban appeals.
/// The server decides who may call these endpoints (admin JWT); this screen only shows the results.
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(tabs: [Tab(text: 'Game reports'), Tab(text: 'Appeals')]),
        ),
        body: const TabBarView(children: [_ReportsTab(), _AppealsTab()]),
      ),
    );
  }
}

String _short(String? iso) => iso == null || iso.length < 10 ? '' : iso.substring(0, 10);

void _toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';

// ====================================================================== reports

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final ModerationService _service = ModerationService();
  String _status = 'open';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await _service.listReports(_status);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> report) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReportSheet(summary: report, service: _service),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final s in const ['open', 'actioned', 'dismissed'])
                ChoiceChip(
                  label: Text(s),
                  selected: _status == s,
                  onSelected: (_) {
                    setState(() => _status = s);
                    _load();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('Nothing here'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = _items[i];
                              final reported = r['reported'] as Map?;
                              final many = (r['reportersLast30Days'] as num?)?.toInt() ?? 1;
                              return ListTile(
                                title: Text('${reported?['displayName'] ?? 'Unknown'}  ·  ${r['reason']}'),
                                subtitle: Text(
                                  '${_short(r['createdAt']?.toString())}  ·  reported by $many player(s) in 30 days'
                                  '${(reported?['warnings'] ?? 0) > 0 ? '  ·  ${reported?['warnings']} warning(s)' : ''}'
                                  '${reported?['ban'] != null ? '  ·  BANNED' : ''}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _open(r),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final Map<String, dynamic> summary;
  final ModerationService service;
  const _ReportSheet({required this.summary, required this.service});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _busy = false;
  final TextEditingController _note = TextEditingController();

  String get _id => widget.summary['_id'].toString();
  bool get _open => widget.summary['status'] == 'open';

  @override
  void initState() {
    super.initState();
    widget.service.getReport(_id).then((d) {
      if (mounted) setState(() => _detail = d);
    }).catchError((e) {
      if (mounted) setState(() => _error = _err(e));
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _act(String action, {String? kind, int? days}) async {
    setState(() => _busy = true);
    try {
      await widget.service.resolveReport(_id, action, kind: kind, days: days, note: _note.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(context, _err(e));
      }
    }
  }

  Future<void> _banDialog() async {
    String kind = 'play';
    int? days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ban player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(value: 'play', child: Text('Online play only')),
                  DropdownMenuItem(value: 'full', child: Text('Whole account (cannot sign in)')),
                ],
                onChanged: (v) => setD(() => kind = v ?? kind),
              ),
              DropdownButtonFormField<int?>(
                value: days,
                decoration: const InputDecoration(labelText: 'Length'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: null, child: Text('Permanent')),
                ],
                onChanged: (v) => setD(() => days = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ban')),
          ],
        ),
      ),
    );
    if (ok == true) _act('ban', kind: kind, days: days);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.summary;
    final reported = r['reported'] as Map?;
    final snap = (r['snapshot'] as Map?) ?? {};
    final game = _detail?['game'] as Map?;
    final review = _detail?['engineReview'] as Map?;
    final moves = (game?['uciMoves'] as List?)?.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text('${reported?['displayName'] ?? 'Unknown'} reported for ${r['reason']}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if ((r['details'] ?? '').toString().isNotEmpty) Text('Reporter says: ${r['details']}'),
            const SizedBox(height: 8),
            Text('Mode: ${snap['gameMode'] ?? '?'}   Moves: ${snap['plies'] ?? '?'}   Ended: ${snap['endReason'] ?? 'running'}'),
            Text('Reported player was ${snap['reportedColor'] ?? '?'}'),
            Text('Different reporters in 30 days: ${r['reportersLast30Days']}   Warnings so far: ${reported?['warnings'] ?? 0}'),
            const Divider(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_detail == null && _error == null) const LinearProgressIndicator(),
            if (_detail != null) ...[
              Text('Game record: ${moves ?? 0} moves${game == null ? ' (game no longer stored)' : ''}'),
              if (review != null)
                Text(
                  'Engine check of this player: ${review.entries.map((e) => '${e.key}: ${e.value}').join('  ·  ')}',
                )
              else
                const Text('Engine check: not available (too short, engine off or training game)'),
            ],
            const SizedBox(height: 12),
            if (_open) ...[
              TextField(
                controller: _note,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Note (shown to the player if you warn or ban)',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _act('dismiss'),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _act('warn'),
                      child: const Text('Warn'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _busy ? null : _banDialog,
                      child: const Text('Ban'),
                    ),
                  ),
                ],
              ),
            ] else
              Text('Decision: ${r['resolution'] ?? r['status']}   ${(r['adminNote'] ?? '').toString()}'),
          ],
        ),
      ),
    );
  }
}

// ====================================================================== appeals

class _AppealsTab extends StatefulWidget {
  const _AppealsTab();
  @override
  State<_AppealsTab> createState() => _AppealsTabState();
}

class _AppealsTabState extends State<_AppealsTab> {
  final ModerationService _service = ModerationService();
  String _status = 'open';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await _service.listAppeals(_status);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _decide(Map<String, dynamic> a) async {
    final note = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Appeal from ${a['user']?['displayName'] ?? 'player'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ban: ${a['banKind']}  ${a['bannedUntil'] == null ? 'permanent' : 'until ${_short(a['bannedUntil'].toString())}'}'),
              if ((a['banReason'] ?? '').toString().isNotEmpty) Text('Reason: ${a['banReason']}'),
              const SizedBox(height: 8),
              Text(a['message'].toString()),
              if (a['status'] == 'open') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Note to the player', border: OutlineInputBorder()),
                ),
              ] else
                Text('\nDecision: ${a['status']}  ${a['adminNote'] ?? ''}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (a['status'] == 'open') ...[
            OutlinedButton(onPressed: () => Navigator.pop(ctx, 'reject'), child: const Text('Reject')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'unban'), child: const Text('Lift ban')),
          ],
        ],
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (action == null) return;
    try {
      await _service.decideAppeal(a['_id'].toString(), action, note: text);
      _load();
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final s in const ['open', 'unbanned', 'rejected'])
                ChoiceChip(
                  label: Text(s),
                  selected: _status == s,
                  onSelected: (_) {
                    setState(() => _status = s);
                    _load();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _items.isEmpty
                      ? const Center(child: Text('Nothing here'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final a = _items[i];
                              return ListTile(
                                title: Text('${a['user']?['displayName'] ?? 'Unknown'}  ·  ${a['banKind']} ban'),
                                subtitle: Text(a['message'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: Text(_short(a['createdAt']?.toString())),
                                onTap: () => _decide(a),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

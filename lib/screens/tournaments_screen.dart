import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/tournament_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/tournament_service.dart';

/// Tournaments (swiss or knockout). Games are daily games (days per move), unrated.
class TournamentsScreen extends StatefulWidget {
  final ChessUser user;
  const TournamentsScreen({super.key, required this.user});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final TournamentService _service = TournamentService();
  TournamentList? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _service.list();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load. Check your connection.';
      });
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';

  Future<void> _open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TournamentScreen(tournamentId: id, user: widget.user)));
    _load();
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String format = 'swiss';
    int days = 3;
    int roundDays = 14;
    int maxPlayers = 16;
    int? rounds;
    int startHours = 48;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New tournament'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: nameCtrl, maxLength: 50, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: descCtrl, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 8),
              const Text('Format'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Swiss'), selected: format == 'swiss', onSelected: (_) => setLocal(() => format = 'swiss')),
                ChoiceChip(label: const Text('Knockout'), selected: format == 'knockout', onSelected: (_) => setLocal(() => format = 'knockout')),
              ]),
              Text(
                format == 'swiss'
                    ? 'Everybody plays every round. 1 point for a win, ½ for a draw.'
                    : 'Lose and you are out. A drawn game is replayed once with colors swapped.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text('Time per move'),
              Wrap(spacing: 8, children: [
                for (final d in const [1, 2, 3, 5, 7])
                  ChoiceChip(label: Text('$d day${d > 1 ? 's' : ''}'), selected: days == d, onSelected: (_) => setLocal(() => days = d)),
              ]),
              const SizedBox(height: 12),
              const Text('Time for one round'),
              Wrap(spacing: 8, children: [
                for (final d in const [7, 10, 14, 21, 30])
                  ChoiceChip(label: Text('$d days'), selected: roundDays == d, onSelected: (_) => setLocal(() => roundDays = d)),
              ]),
              const Text('Games not finished by then end as a draw.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              const Text('Maximum players'),
              Wrap(spacing: 8, children: [
                for (final n in const [8, 16, 32, 64])
                  ChoiceChip(label: Text('$n'), selected: maxPlayers == n, onSelected: (_) => setLocal(() => maxPlayers = n)),
              ]),
              if (format == 'swiss') ...[
                const SizedBox(height: 12),
                const Text('Rounds'),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('Auto'), selected: rounds == null, onSelected: (_) => setLocal(() => rounds = null)),
                  for (final r in const [3, 4, 5, 6, 7])
                    ChoiceChip(label: Text('$r'), selected: rounds == r, onSelected: (_) => setLocal(() => rounds = r)),
                ]),
              ],
              const SizedBox(height: 12),
              const Text('Registration closes in'),
              Wrap(spacing: 8, children: [
                for (final h in const [24, 48, 72, 168])
                  ChoiceChip(label: Text('${h ~/ 24} day${h ~/ 24 > 1 ? 's' : ''}'), selected: startHours == h, onSelected: (_) => setLocal(() => startHours = h)),
              ]),
              const SizedBox(height: 8),
              const Text('Needs at least 4 players, otherwise it is cancelled. You can also start it early.', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text;
    final desc = descCtrl.text;
    nameCtrl.dispose();
    descCtrl.dispose();
    if (ok != true) return;
    try {
      final t = await _service.create(
        name: name,
        description: desc,
        format: format,
        daysPerMove: days,
        roundDays: roundDays,
        maxPlayers: maxPlayers,
        rounds: format == 'swiss' ? rounds : null,
        startsInHours: startHours,
      );
      if (!mounted) return;
      _toast('Tournament created. Invite your friends!');
      _open(t.info.id);
    } catch (e) {
      _toast(_err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      floatingActionButton: widget.user.isGuest
          ? null
          : FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Organise')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final d = _data!;
    final empty = d.mine.isEmpty && d.open.isEmpty && d.running.isEmpty && d.finished.isEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        if (empty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No tournaments yet. Organise one and invite your friends: every game has 1 to 7 days per move.', textAlign: TextAlign.center),
          ),
        if (d.mine.isNotEmpty) _header('My tournaments'),
        for (final t in d.mine) _tile(t),
        if (d.open.isNotEmpty) _header('Open for registration'),
        for (final t in d.open) _tile(t),
        if (d.running.isNotEmpty) _header('Running'),
        for (final t in d.running) _tile(t),
        if (d.finished.isNotEmpty) _header('Finished'),
        for (final t in d.finished) _tile(t),
      ],
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _tile(TournamentSummary t) => ListTile(
        leading: Icon(t.isCompleted ? Icons.emoji_events : Icons.emoji_events_outlined, color: t.joined ? Colors.orange : null),
        title: Text(t.name, style: t.joined ? const TextStyle(fontWeight: FontWeight.bold) : null),
        subtitle: Text('${t.formatText} · ${t.daysPerMove} day${t.daysPerMove > 1 ? 's' : ''}/move · ${t.statusText}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(t.id),
      );
}

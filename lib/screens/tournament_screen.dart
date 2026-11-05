import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/daily_game_screen.dart';
import 'package:flutter_chess_app/screens/tournament_watch_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/tournament_service.dart';
import 'package:flutter_chess_app/widgets/report_dialog.dart';

/// One tournament: info, join / leave, my current game, standings and all rounds.
class TournamentScreen extends StatefulWidget {
  final String tournamentId;
  final ChessUser user;
  const TournamentScreen({super.key, required this.tournamentId, required this.user});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final TournamentService _service = TournamentService();
  TournamentDetail? _t;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _service.get(widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _t = t;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<TournamentDetail> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final t = await action();
      if (mounted) setState(() => _t = t);
    } catch (e) {
      _toast(_err(e));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ask(String title, String text) async {
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

  Future<void> _cancel() async {
    if (!await _ask('Cancel this tournament?', 'All players are told. Games that are still running end as a draw.')) return;
    try {
      await _service.cancel(widget.tournamentId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _playMyGame(TournamentMyGame g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: g.gameId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      appBar: AppBar(title: Text(t == null ? 'Tournament' : t.info.name), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
        if (t != null && t.info.creatorId != widget.user.uid && !widget.user.isGuest)
          PopupMenuButton<String>(
            onSelected: (_) => showReportDialog(context, kind: 'tournament', targetId: t.info.id, title: 'Report this tournament'),
            itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report tournament'))],
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : t == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Tournament not found', textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _body(t)),
    );
  }

  Widget _body(TournamentDetail t) {
    final info = t.info;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(info),
        const SizedBox(height: 8),
        if (t.myGame != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text('Round ${t.myGame!.round}: you play ${t.myGame!.color} against ${t.myGame!.opponentName}'),
              subtitle: const Text('Tap to open your game'),
              onTap: () => _playMyGame(t.myGame!),
            ),
          ),
        ..._actions(t),
        if (info.isCompleted && info.championName != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('🏆 ${info.championName}', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          ),
        _section(info.isRegistration ? 'Players (${t.players.length}/${info.maxPlayers})' : 'Standings'),
        if (info.isRegistration) ..._registered(t) else ..._standings(t),
        if (t.rounds.isNotEmpty) _section('Rounds'),
        for (final r in t.rounds.reversed) _roundTile(t, r),
      ],
    );
  }

  Widget _infoCard(TournamentSummary info) {
    final lines = <String>[
      '${info.formatText} · ${info.daysPerMove} day${info.daysPerMove > 1 ? 's' : ''} per move · unrated',
      'Organiser: ${info.creatorName}',
      if (info.isRegistration) '${info.playerCount}/${info.maxPlayers} players · ${info.startsText}',
      if (info.isRunning) 'Round ${info.currentRound} of ${info.totalRounds} · ${info.roundEndsText}',
      if (info.status == 'cancelled') 'This tournament was cancelled.',
      if (info.isRunning || info.isRegistration) 'Unfinished games end as a draw after ${info.roundDays} days of a round.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (info.description.isNotEmpty) ...[Text(info.description), const SizedBox(height: 8)],
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(l, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }

  List<Widget> _actions(TournamentDetail t) {
    final info = t.info;
    final isMine = info.creatorId == widget.user.uid;
    final canJoin = info.isRegistration && !info.joined && !widget.user.isGuest && info.playerCount < info.maxPlayers;
    return [
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        if (canJoin) FilledButton.icon(icon: const Icon(Icons.login), label: const Text('Join'), onPressed: _busy ? null : () => _run(() => _service.join(info.id))),
        if (info.isRegistration && info.joined && !isMine)
          OutlinedButton(onPressed: _busy ? null : () => _run(() => _service.leave(info.id)), child: const Text('Leave')),
        if (info.isRunning && info.joined)
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (await _ask('Withdraw?', 'You lose your current game and are not paired again.')) {
                      await _run(() => _service.leave(info.id));
                    }
                  },
            child: const Text('Withdraw'),
          ),
        if (info.isRegistration && t.canManage && t.players.length >= 4)
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () async {
                    if (await _ask('Start now?', 'Registration closes and round 1 is paired.')) {
                      await _run(() => _service.start(info.id));
                    }
                  },
            child: const Text('Start now'),
          ),
        if (t.canManage && (info.isRegistration || info.isRunning)) TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel tournament')),
      ]),
      if (info.isRegistration && widget.user.isGuest) const Padding(padding: EdgeInsets.all(8), child: Text('Create an account to join tournaments.', textAlign: TextAlign.center)),
    ];
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  List<Widget> _registered(TournamentDetail t) => [
        if (t.players.isEmpty) const Text('Nobody yet.'),
        for (final p in t.players)
          ListTile(dense: true, leading: const Icon(Icons.person_outline), title: Text(p.name), trailing: Text(p.rating == null ? '' : '${p.rating}')),
        if (t.players.isNotEmpty) const Text('Seeds follow the rating when the tournament starts.', style: TextStyle(fontSize: 12)),
      ];

  List<Widget> _standings(TournamentDetail t) {
    final swiss = t.info.isSwiss;
    return [
      for (final r in t.players)
        ListTile(
          dense: true,
          selected: r.userId == widget.user.uid,
          leading: CircleAvatar(radius: 14, child: Text('${r.rank}', style: const TextStyle(fontSize: 12))),
          title: Text(r.champion ? '🏆 ${r.name}' : r.name, style: r.withdrawn ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
          subtitle: Text(swiss ? 'W${r.wins} D${r.draws} L${r.losses} · tiebreak ${r.buchholz.toStringAsFixed(1)}' : 'reached round ${r.reached}'),
          trailing: swiss ? Text(r.scoreText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)) : null,
        ),
    ];
  }

  Widget _roundTile(TournamentDetail t, TournamentRound r) {
    final isCurrent = t.info.isRunning && r.number == t.info.currentRound;
    final title = !t.info.isSwiss && r.number == t.info.totalRounds ? 'Final' : 'Round ${r.number}';
    return ExpansionTile(
      initiallyExpanded: isCurrent,
      tilePadding: EdgeInsets.zero,
      title: Text(isCurrent ? '$title (now)' : title),
      children: [
        for (final p in r.pairings)
          ListTile(
            dense: true,
            selected: p.mine,
            leading: Text('${p.board}'),
            title: Text(p.isBye ? '${p.whiteName ?? '?'} (bye)' : '${p.whiteName ?? '?'} - ${p.blackName ?? '?'}'),
            subtitle: p.attempt > 1 ? const Text('rematch (colors swapped)') : null,
            trailing: Text(p.resultText),
            // My own board opens to play; any other board with a game opens read-only (watch).
            onTap: p.gameId == null || p.gameId!.isEmpty
                ? null
                : p.mine
                    ? () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: p.gameId!)));
                        _load();
                      }
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TournamentWatchScreen(tournamentId: t.info.id, gameId: p.gameId!)),
                        ),
          ),
      ],
    );
  }
}

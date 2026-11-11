import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/daily_game_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';

/// "Daily games": slow games against friends (1-7 days per move), unrated. Works with the app closed (push on every move).
class DailyGamesScreen extends StatefulWidget {
  final ChessUser user;
  /// Inside the Friends tab: no app bar of its own.
  final bool embedded;
  const DailyGamesScreen({super.key, required this.user, this.embedded = false});

  @override
  State<DailyGamesScreen> createState() => _DailyGamesScreenState();
}

class _DailyGamesScreenState extends State<DailyGamesScreen> {
  final DailyGameService _service = DailyGameService();
  DailyGameList? _data;
  bool _loading = true;
  String? _error;

  StreamSubscription<Map<String, dynamic>>? _liveSub;

  @override
  void initState() {
    super.initState();
    _load();
    // New challenge / opponent moved / game ended -> refresh the list live.
    _liveSub = GameSocketService.instance.onDailyUpdate.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
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

  Future<void> _open(DailyGame g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: g.id)));
    _load();
  }

  Future<void> _answer(DailyGame g, bool accept) async {
    try {
      if (accept) {
        await _service.accept(g.id);
      } else {
        await _service.decline(g.id);
      }
      _load();
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _newChallenge() async {
    final friends = await FriendService().getFriends(widget.user.uid ?? '').first;
    if (!mounted) return;
    if (friends.isEmpty) {
      _toast('Add a friend first, then you can challenge them.');
      return;
    }
    ChessUser? friend;
    int days = 3;
    String color = 'random';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New daily game'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButton<ChessUser>(
                isExpanded: true,
                hint: const Text('Choose a friend'),
                value: friend,
                items: [for (final f in friends) DropdownMenuItem(value: f, child: Text(f.displayName))],
                onChanged: (v) => setLocal(() => friend = v),
              ),
              const SizedBox(height: 12),
              const Text('Time per move'),
              Wrap(spacing: 8, children: [
                for (final d in const [1, 2, 3, 5, 7])
                  ChoiceChip(label: Text('$d day${d > 1 ? 's' : ''}'), selected: days == d, onSelected: (_) => setLocal(() => days = d)),
              ]),
              const SizedBox(height: 12),
              const Text('Your color'),
              Wrap(spacing: 8, children: [
                for (final c in const ['random', 'white', 'black'])
                  ChoiceChip(label: Text(c), selected: color == c, onSelected: (_) => setLocal(() => color = c)),
              ]),
              const SizedBox(height: 8),
              const Text('Daily games are unrated.', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: friend == null ? null : () => Navigator.pop(ctx, true), child: const Text('Send challenge')),
          ],
        ),
      ),
    );
    if (ok != true || friend == null) return;
    try {
      await _service.challenge(friend!.uid!, days, color: color);
      _toast('Challenge sent to ${friend!.displayName}.');
      _load();
    } catch (e) {
      _toast(_err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Daily games'), actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ]),
      floatingActionButton: widget.user.isGuest
          ? null
          : FloatingActionButton.extended(onPressed: _newChallenge, icon: const Icon(Icons.add), label: const Text('Challenge a friend')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final d = _data!;
    final yourTurn = d.active.where((g) => g.myTurn).toList();
    final theirTurn = d.active.where((g) => !g.myTurn).toList();
    final empty = d.invites.isEmpty && d.sent.isEmpty && d.active.isEmpty && d.finished.isEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        if (empty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No daily games yet. Challenge a friend: you get 1 to 7 days for each move, and a notification when it is your turn.',
                textAlign: TextAlign.center),
          ),
        if (d.invites.isNotEmpty) _header('Challenges for you'),
        for (final g in d.invites)
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text('${g.iAmWhite ? g.blackName : g.whiteName} challenges you'),
            subtitle: Text('${g.daysPerMove} day(s) per move, you play ${g.myColor}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.close), tooltip: 'Decline', onPressed: () => _answer(g, false)),
              IconButton(icon: const Icon(Icons.check), tooltip: 'Accept', onPressed: () => _answer(g, true)),
            ]),
          ),
        if (yourTurn.isNotEmpty) _header('Your turn'),
        for (final g in yourTurn) _gameTile(g, highlight: true),
        if (theirTurn.isNotEmpty) _header("Opponent's turn"),
        for (final g in theirTurn) _gameTile(g),
        if (d.sent.isNotEmpty) _header('Waiting for an answer'),
        for (final g in d.sent)
          ListTile(
            leading: const Icon(Icons.hourglass_empty),
            title: Text('Challenge to ${g.opponentName}'),
            subtitle: Text('${g.daysPerMove} day(s) per move'),
            trailing: TextButton(onPressed: () => _answer(g, false), child: const Text('Cancel')),
          ),
        if (d.finished.isNotEmpty) _header('Finished'),
        for (final g in d.finished)
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text('vs ${g.opponentName}'),
            subtitle: Text('${g.inTournament ? 'Tournament · ' : ''}${g.resultText}'),
            onTap: () => _open(g),
          ),
      ],
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _gameTile(DailyGame g, {bool highlight = false}) => ListTile(
        leading: Icon(Icons.crop_square, color: g.iAmWhite ? Colors.white : Colors.black, shadows: const [Shadow(blurRadius: 2)]),
        title: Text('vs ${g.opponentName}', style: highlight ? const TextStyle(fontWeight: FontWeight.bold) : null),
        subtitle: Text('${g.inTournament ? 'Tournament, round ${g.tournamentRound ?? ''} · ' : ''}Move ${g.moves.length ~/ 2 + 1} · ${g.timeLeftText}'),
        trailing: highlight ? const Icon(Icons.notifications_active, color: Colors.orange) : null,
        onTap: () => _open(g),
      );
}

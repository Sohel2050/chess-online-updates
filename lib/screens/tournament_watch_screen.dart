import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/tournament_service.dart';
import 'package:flutter_chess_app/utils/uci_game.dart';
import 'package:flutter_chess_app/widgets/learn_board.dart';

/// Read-only view of one tournament board (daily game). No moves can be made here.
/// While the game is running the screen refreshes itself every minute; the refresh button does it at once.
class TournamentWatchScreen extends StatefulWidget {
  final String tournamentId;
  final String gameId;
  const TournamentWatchScreen({super.key, required this.tournamentId, required this.gameId});

  @override
  State<TournamentWatchScreen> createState() => _TournamentWatchScreenState();
}

class _TournamentWatchScreenState extends State<TournamentWatchScreen> {
  final TournamentService _service = TournamentService();
  final UciGame _g = UciGame();
  WatchedGame? _game;
  bool _loading = true;
  String? _error;
  bool _flipped = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_game?.isActive ?? true) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final game = await _service.watchGame(widget.tournamentId, widget.gameId);
      if (!mounted) return;
      _g.rebuild(game.moves);
      setState(() {
        _game = game;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Request failed. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      appBar: AppBar(
        title: Text(g == null ? 'Watch game' : '${g.whiteName} - ${g.blackName}'),
        actions: [
          IconButton(icon: const Icon(Icons.flip), onPressed: () => setState(() => _flipped = !_flipped)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Game not found', textAlign: TextAlign.center)))
              : SafeArea(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text(_statusText(g), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    LearnBoard(state: _g.squares(_g.turn), flipped: _flipped), // no onMove: nobody can move here
                    const SizedBox(height: 12),
                    Text(_moveText(g.moves), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
    );
  }

  String _statusText(WatchedGame g) {
    if (g.status == 'completed') return g.resultText;
    if (g.isActive) {
      final who = g.whiteToMove ? g.whiteName : g.blackName;
      return '$who to move · ${g.timeLeftText}';
    }
    return 'Not started (${g.status})';
  }

  String _moveText(List<String> moves) {
    final b = StringBuffer();
    for (var i = 0; i < moves.length; i++) {
      if (i % 2 == 0) b.write('${i ~/ 2 + 1}. ');
      b.write('${moves[i]} ');
    }
    return b.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';
import 'package:flutter_chess_app/utils/uci_game.dart';
import 'package:flutter_chess_app/widgets/learn_board.dart';
import 'package:squares/squares.dart';

/// One daily game: the board, whose turn it is, and resign / draw. The server checks every move.
class DailyGameScreen extends StatefulWidget {
  final String gameId;
  const DailyGameScreen({super.key, required this.gameId});

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  final DailyGameService _service = DailyGameService();
  final UciGame _g = UciGame();
  DailyGame? _game;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _apply(await _service.get(widget.gameId), first: _game == null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  void _apply(DailyGame g, {bool first = false}) {
    if (!mounted) return;
    _g.rebuild(g.moves);
    setState(() {
      _game = g;
      _loading = false;
      _error = null;
      if (first) _flipped = !g.iAmWhite;
    });
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<DailyGame> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _apply(await action());
    } catch (e) {
      _toast(_err(e));
      await _load(); // the server's copy is the truth: repair the board
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onMove(Move move) {
    final g = _game;
    if (g == null || !g.isActive || !g.myTurn || _busy) return;
    final uci = move.algebraic();
    final probe = UciGame()..rebuild(g.moves);
    if (!probe.play(uci)) return; // not legal on this device: ignore
    _run(() => _service.move(g.id, uci));
  }

  Future<void> _confirm(String title, String text, Future<DailyGame> Function() action) async {
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
    if (ok == true) await _run(action);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      appBar: AppBar(
        title: Text(g == null ? 'Daily game' : 'vs ${g.opponentName}'),
        actions: [
          IconButton(icon: const Icon(Icons.flip), onPressed: () => setState(() => _flipped = !_flipped)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : g == null
              ? Center(child: Text(_error ?? 'Game not found'))
              : SafeArea(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _status(g),
                    const SizedBox(height: 12),
                    LearnBoard(
                      state: _g.squares(_g.turn),
                      flipped: _flipped,
                      onMove: g.isActive && g.myTurn && !_busy ? _onMove : null,
                    ),
                    const SizedBox(height: 12),
                    if (g.isActive) ..._actions(g),
                    const SizedBox(height: 8),
                    Text(_moveText(g.moves), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
    );
  }

  Widget _status(DailyGame g) {
    String text;
    if (g.status == 'completed') {
      text = g.resultText;
    } else if (g.isActive) {
      text = g.myTurn ? 'Your turn · ${g.timeLeftText}' : "Waiting for ${g.opponentName} · ${g.timeLeftText}";
    } else {
      text = 'Not started (${g.status})';
    }
    return Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center);
  }

  List<Widget> _actions(DailyGame g) {
    final offeredToMe = g.drawOfferedBy != null && g.drawOfferedBy!.isNotEmpty && g.drawOfferedBy != g.myId;
    final offeredByMe = g.drawOfferedBy == g.myId;
    return [
      if (offeredToMe)
        Card(
          child: ListTile(
            title: Text('${g.opponentName} offers a draw'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: _busy ? null : () => _run(() => _service.draw(g.id, 'decline')), child: const Text('Decline')),
              FilledButton(onPressed: _busy ? null : () => _run(() => _service.draw(g.id, 'accept')), child: const Text('Accept')),
            ]),
          ),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.handshake_outlined),
          label: Text(offeredByMe ? 'Draw offered' : 'Offer draw'),
          onPressed: _busy || offeredByMe || offeredToMe
              ? null
              : () => _confirm('Offer a draw?', 'Your opponent can accept or decline.', () => _service.draw(g.id, 'offer')),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.flag),
          label: const Text('Resign'),
          onPressed: _busy ? null : () => _confirm('Resign?', 'You lose this game.', () => _service.resign(g.id)),
        ),
      ]),
    ];
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

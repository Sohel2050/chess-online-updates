import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

import '../data/learn_content.dart';
import '../services/learn_progress_service.dart';
import '../utils/uci_game.dart';
import '../widgets/learn_board.dart';

/// One scripted endgame drill. You play the side to move and must find the winning moves; the opponent answers with
/// the most stubborn defence. Every drill was solved by brute force when the content was generated.
class EndgameDrillScreen extends StatefulWidget {
  final EndgameDrill drill;

  const EndgameDrillScreen({super.key, required this.drill});

  @override
  State<EndgameDrillScreen> createState() => _EndgameDrillScreenState();
}

class _EndgameDrillScreenState extends State<EndgameDrillScreen> {
  late UciGame _g;
  late int _mySide;
  int _next = 0;
  int _mistakes = 0;
  bool _busy = false;
  bool _finished = false;
  bool _showHint = false;
  bool _showSolution = false;
  String? _message;
  bool _messageIsError = false;
  Timer? _timer;

  EndgameDrill get drill => widget.drill;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _g = UciGame(startFen: drill.fen);
    _mySide = _g.turn;
    _next = 0;
    _mistakes = 0;
    _busy = false;
    _finished = false;
    _showHint = false;
    _showSolution = false;
    _message = null;
    _messageIsError = false;
  }

  void _onMove(Move move) {
    if (_busy || _finished || _g.turn != _mySide) return;
    final expected = drill.uci[_next];
    final got = move.algebraic();
    if (got == expected && _g.play(got)) {
      setState(() {
        _next++;
        _message = null;
        if (_next >= drill.uci.length) {
          _finish();
        } else {
          _scheduleReply();
        }
      });
      return;
    }
    setState(() {
      _mistakes++;
      _messageIsError = true;
      if (got.length == 5 && expected.length == 5 && got.substring(0, 4) == expected.substring(0, 4)) {
        _message = 'Right move, but promote to a queen.';
      } else {
        _message =
            'That is not the move this drill is looking for. Check the hint, or restart and think about the opponent\'s king.';
      }
    });
  }

  void _scheduleReply() {
    _busy = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        if (_next < drill.uci.length && _g.play(drill.uci[_next])) {
          _next++;
        }
        _busy = false;
        if (_next >= drill.uci.length) _finish();
      });
    });
  }

  void _finish() {
    _finished = true;
    _messageIsError = false;
    _message = _mistakes == 0
        ? 'Well done! You found every move.'
        : 'Solved, with $_mistakes wrong attempt${_mistakes == 1 ? '' : 's'}. Restart to try for a clean run.';
    LearnProgress.markEndgame(drill.id);
  }

  EndgameDrill? get _nextDrill {
    final i = kEndgameDrills.indexWhere((d) => d.id == drill.id);
    if (i < 0 || i + 1 >= kEndgameDrills.length) return null;
    return kEndgameDrills[i + 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _g.squares(_g.turn);
    final canMove = !_busy && !_finished && _g.turn == _mySide;
    final next = _nextDrill;
    return Scaffold(
      appBar: AppBar(title: Text(drill.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(drill.category, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(drill.goal, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LearnBoard(
              state: state,
              flipped: _mySide == 1,
              onMove: canMove ? _onMove : null,
            ),
            const SizedBox(height: 12),
            if (_message != null)
              Card(
                color: _messageIsError ? Colors.red.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_message!, style: const TextStyle(color: Colors.black87)),
                ),
              ),
            if (_showHint)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(drill.hint)),
                    ],
                  ),
                ),
              ),
            if (_showSolution)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Solution: ${drill.san.join(' ')}'),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showHint = true),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Hint'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showSolution = true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Solution'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(_restart),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart'),
                  ),
                ),
              ],
            ),
            if (_finished && next != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => EndgameDrillScreen(drill: next)),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text('Next: ${next.title}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

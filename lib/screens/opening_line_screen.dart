import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

import '../data/learn_content.dart';
import '../services/learn_progress_service.dart';
import '../utils/uci_game.dart';
import '../widgets/learn_board.dart';

/// One opening line, two modes: Study (step through it with explanations) and Train (play your side from memory).
class OpeningLineScreen extends StatefulWidget {
  final OpeningLine line;
  final bool startInTrain;

  const OpeningLineScreen({
    super.key,
    required this.line,
    this.startInTrain = false,
  });

  @override
  State<OpeningLineScreen> createState() => _OpeningLineScreenState();
}

class _OpeningLineScreenState extends State<OpeningLineScreen> {
  late bool _train;
  final UciGame _g = UciGame();

  // Study mode
  int _ply = 0;

  // Train mode
  int _next = 0; // index of the next ply of the line
  int _mistakes = 0;
  int _hints = 0;
  bool _busy = false; // opponent reply pending
  bool _finished = false;
  String? _message;
  bool _messageIsError = false;
  Timer? _timer;

  OpeningLine get line => widget.line;
  bool get _flipped => line.side == 1;

  @override
  void initState() {
    super.initState();
    _train = widget.startInTrain;
    _enter();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enter() {
    _timer?.cancel();
    _busy = false;
    _finished = false;
    _message = null;
    _messageIsError = false;
    if (_train) {
      _g.reset();
      _next = 0;
      _mistakes = 0;
      _hints = 0;
      // When you play Black, White's first move is played for you.
      if (line.side == 1) _scheduleOpponent();
    } else {
      _ply = 0;
      _g.reset();
    }
  }

  void _setMode(bool train) {
    if (train == _train) return;
    setState(() {
      _train = train;
      _enter();
    });
  }

  // ---------------------------------------------------------------- study

  void _goTo(int ply) {
    final p = ply.clamp(0, line.uci.length);
    setState(() {
      _ply = p;
      _g.rebuild(line.uci.sublist(0, p));
    });
  }

  // ---------------------------------------------------------------- train

  bool get _isMyTurn => (_next % 2) == line.side;

  void _scheduleOpponent() {
    _busy = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted || !_train) return;
      setState(() {
        if (_next < line.uci.length && _g.play(line.uci[_next])) {
          _next++;
        }
        _busy = false;
        _afterPly();
      });
    });
  }

  /// Called after any ply was played: show the note, detect the end of the line.
  void _afterPly() {
    final idx = _next - 1;
    if (idx >= 0 && line.notes.containsKey(idx)) {
      _message = line.notes[idx];
      _messageIsError = false;
    }
    if (_next >= line.uci.length) {
      _finish();
    }
  }

  void _finish() {
    _finished = true;
    final perfect = _mistakes == 0 && _hints == 0;
    _message = perfect
        ? 'Perfect! You played the whole line from memory without a mistake.'
        : 'Line complete. Mistakes: $_mistakes, hints: $_hints. Try again for a perfect run.';
    _messageIsError = false;
    LearnProgress.markOpening(line.id, perfect: perfect);
  }

  void _onMove(Move move) {
    if (!_train || _busy || _finished || !_isMyTurn) return;
    final expected = line.uci[_next];
    final got = move.algebraic();
    if (got == expected && _g.play(got)) {
      setState(() {
        _next++;
        _afterPly();
        if (!_finished && _next < line.uci.length) _scheduleOpponent();
      });
    } else {
      setState(() {
        _mistakes++;
        _message =
            'That is not the move from this line. Think about what the opening is trying to do, or use a hint.';
        _messageIsError = true;
      });
    }
  }

  void _hint() {
    if (_finished || !_isMyTurn || _busy) return;
    setState(() {
      _hints++;
      _message = 'Hint: play ${line.san[_next]}';
      _messageIsError = false;
    });
  }

  // ---------------------------------------------------------------- ui

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _g.squares(_g.turn);
    return Scaffold(
      appBar: AppBar(title: Text(line.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Chip(
                  label: Text(line.side == 0 ? 'You play White' : 'You play Black'),
                ),
                const SizedBox(width: 8),
                Text('Level ${line.level}/3', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Study'), icon: Icon(Icons.menu_book)),
                ButtonSegment(value: true, label: Text('Train'), icon: Icon(Icons.fitness_center)),
              ],
              selected: {_train},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
            const SizedBox(height: 12),
            LearnBoard(
              state: state,
              flipped: _flipped,
              onMove: _train && !_finished && _isMyTurn && !_busy ? _onMove : null,
            ),
            const SizedBox(height: 12),
            if (_train) ..._trainPanel(theme) else ..._studyPanel(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _studyPanel(ThemeData theme) {
    final note = _ply > 0 ? line.notes[_ply - 1] : null;
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Start',
            onPressed: _ply > 0 ? () => _goTo(0) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Back',
            onPressed: _ply > 0 ? () => _goTo(_ply - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$_ply / ${line.uci.length}', style: theme.textTheme.titleMedium),
          IconButton(
            tooltip: 'Next',
            onPressed: _ply < line.uci.length ? () => _goTo(_ply + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'End',
            onPressed: _ply < line.uci.length ? () => _goTo(line.uci.length) : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
      if (note != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(note)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(line.summary, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 12),
      Text('Key ideas', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      for (final idea in line.ideas)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(idea)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text('The line', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(sanText(line.san)),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _setMode(true),
        icon: const Icon(Icons.fitness_center),
        label: const Text('Train this line'),
      ),
    ];
  }

  List<Widget> _trainPanel(ThemeData theme) {
    final total = line.uci.length;
    final progress = total == 0 ? 0.0 : _next / total;
    return [
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text(
        _finished
            ? 'Finished'
            : (_busy
                ? 'Opponent is thinking…'
                : 'Your move (${line.side == 0 ? 'White' : 'Black'}). Mistakes: $_mistakes'),
        style: theme.textTheme.titleMedium,
      ),
      if (_message != null)
        Card(
          color: _messageIsError ? Colors.red.shade50 : Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _message!,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _finished || !_isMyTurn || _busy ? null : _hint,
              icon: const Icon(Icons.help_outline),
              label: const Text('Hint'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(_enter),
              icon: const Icon(Icons.refresh),
              label: const Text('Restart'),
            ),
          ),
        ],
      ),
    ];
  }
}

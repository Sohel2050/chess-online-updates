import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

import '../utils/uci_game.dart';
import '../widgets/learn_board.dart';
import 'opening_line_screen.dart';

/// Opening explorer: play any moves; the screen names the opening and shows which continuations are in the app's book.
class OpeningExplorerScreen extends StatefulWidget {
  const OpeningExplorerScreen({super.key});

  @override
  State<OpeningExplorerScreen> createState() => _OpeningExplorerScreenState();
}

class _OpeningExplorerScreenState extends State<OpeningExplorerScreen> {
  final UciGame _g = UciGame();
  bool _flipped = false;

  void _onMove(Move move) {
    final uci = move.algebraic();
    if (_g.isOver) return;
    setState(() {
      _g.play(uci);
    });
  }

  void _playBook(BookMove m) {
    setState(() {
      _g.play(m.uci);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final played = _g.played;
    final name = openingNameFor(played);
    final book = bookMovesAfter(played);
    final lines = linesThrough(played);
    final labels = labelsFor(played);
    final state = _g.squares(_g.turn);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opening explorer'),
        actions: [
          IconButton(
            tooltip: 'Flip board',
            onPressed: () => setState(() => _flipped = !_flipped),
            icon: const Icon(Icons.swap_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              name ?? 'Starting position',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LearnBoard(
              state: state,
              flipped: _flipped,
              onMove: _g.isOver ? null : _onMove,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Undo',
                  onPressed: played.isEmpty ? null : () => setState(_g.undo),
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Reset',
                  onPressed: played.isEmpty ? null : () => setState(_g.reset),
                  icon: const Icon(Icons.restart_alt),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    played.isEmpty ? 'Make a move on the board, or pick one below.' : sanText(labels),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Book moves', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (book.isEmpty)
              Text(
                played.isEmpty
                    ? 'No book moves.'
                    : 'You are out of the app\'s book. Use Undo to go back, or keep playing to explore.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in book)
                    ActionChip(
                      label: Text('${m.san}  ·  ${m.lines.map((l) => l.name).toSet().join(', ')}'),
                      onPressed: () => _playBook(m),
                    ),
                ],
              ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Lines to learn from here', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final l in lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.name),
                  subtitle: Text(l.side == 0 ? 'As White' : 'As Black'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OpeningLineScreen(line: l)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

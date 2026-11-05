import 'package:flutter/material.dart';
import '../services/rated_puzzle_service.dart';
import 'puzzle_board_screen.dart';

/// Rated puzzles + practice by theme (roadmap item 8). Shows the user's puzzle rating and every
/// theme with the user's own success rate; tapping starts rated puzzles (all themes or one theme).
class PuzzleRatedScreen extends StatefulWidget {
  const PuzzleRatedScreen({super.key});

  @override
  State<PuzzleRatedScreen> createState() => _PuzzleRatedScreenState();
}

class _PuzzleRatedScreenState extends State<PuzzleRatedScreen> {
  final RatedPuzzleService _service = RatedPuzzleService();
  PuzzleRatingInfo? _rating;
  List<PuzzleThemeStat> _themes = [];
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rating = await _service.getRating();
    final themes = await _service.getThemes();
    if (!mounted) return;
    setState(() {
      _rating = rating;
      _themes = themes;
      _loading = false;
    });
  }

  Future<void> _start(String? theme) async {
    if (_starting) return;
    setState(() => _starting = true);
    final rated = await _service.nextPuzzle(theme: theme);
    if (!mounted) return;
    setState(() => _starting = false);
    if (rated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puzzle available right now.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleBoardScreen(
          puzzle: rated.puzzle,
          ratedAttemptId: rated.attemptId,
          ratedTheme: theme,
        ),
      ),
    );
    if (mounted) _load(); // the rating may have changed
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rated puzzles')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Puzzle rating', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(
                            _rating == null
                                ? '-'
                                : '${_rating!.rating}${_rating!.provisional ? '?' : ''}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                          ),
                          if (_rating != null && _rating!.rated > 0)
                            Text('${_rating!.rated} rated puzzles played',
                                style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _starting ? null : () => _start(null),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start rated puzzles'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Practice by theme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_themes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No themes yet.'),
                    ),
                  for (final t in _themes)
                    Card(
                      child: ListTile(
                        title: Text(RatedPuzzleService.prettyTheme(t.theme)),
                        subtitle: Text(
                          t.attempts == 0
                              ? '${t.count} puzzles'
                              : '${t.count} puzzles · ${(t.successRate * 100).round()}% solved (${t.solved}/${t.attempts})',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _starting ? null : () => _start(t.theme),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

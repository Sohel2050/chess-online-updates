import 'package:flutter/material.dart';
import '../services/personal_puzzle_service.dart';
import 'puzzle_board_screen.dart';

/// Puzzles made from the user's own blunders in lost games (roadmap item 9).
class MyBlundersScreen extends StatefulWidget {
  const MyBlundersScreen({super.key});

  @override
  State<MyBlundersScreen> createState() => _MyBlundersScreenState();
}

class _MyBlundersScreenState extends State<MyBlundersScreen> {
  final PersonalPuzzleService _service = PersonalPuzzleService();
  List<PersonalPuzzle> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(PersonalPuzzle p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleBoardScreen(puzzle: p.puzzle, personalPuzzleId: p.id),
      ),
    );
    if (mounted) _load(); // a solved puzzle drops off the list
  }

  Future<void> _dismiss(PersonalPuzzle p) async {
    setState(() => _items = _items.where((x) => x.id != p.id).toList());
    await _service.dismiss(p.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My blunders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No puzzles yet. After you lose a longer online game, the biggest mistakes show up here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final p = _items[i];
                      return Dismissible(
                        key: ValueKey(p.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _dismiss(p),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red.shade400,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.extension),
                            title: const Text('Find the move you missed'),
                            subtitle: Text('That mistake cost about ${(p.cpLoss / 100).toStringAsFixed(1)} pawns'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(p),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/puzzle_provider.dart';
import '../providers/user_provider.dart';
import '../screens/puzzle_board_screen.dart';
import '../services/puzzle_service.dart';

/// Compact "Daily Puzzle" card for the Play tab. One puzzle per day, the same
/// for everyone; shows "Solved today" once the user has finished it.
class DailyPuzzleCard extends StatefulWidget {
  const DailyPuzzleCard({super.key});

  @override
  State<DailyPuzzleCard> createState() => _DailyPuzzleCardState();
}

class _DailyPuzzleCardState extends State<DailyPuzzleCard>
    with WidgetsBindingObserver {
  final PuzzleService _service = PuzzleService();
  DailyPuzzleInfo? _info;
  bool _loading = true;
  bool _opening = false;
  String? _loadedDateKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// If the app stays open past midnight, pick up the new day on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _loadedDateKey != PuzzleService.localDateKey()) {
      _load();
    }
  }

  Future<void> _load() async {
    final info = await _service.getDailyPuzzle();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
      _loadedDateKey = PuzzleService.localDateKey();
    });
  }

  Future<void> _open() async {
    final info = _info;
    if (info == null || _opening) return;
    _opening = true;
    try {
      final puzzleProvider = context.read<PuzzleProvider>();
      final user = context.read<UserProvider>().user;
      await puzzleProvider.initialize(
        userId: (user?.uid != null && user!.uid!.isNotEmpty)
            ? user.uid
            : 'guest_local',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PuzzleBoardScreen(
            puzzle: info.puzzle,
            dailyDateKey: info.dateKey,
          ),
        ),
      );
      if (mounted) await _load(); // refresh solved state after returning
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show while loading, or if the backend has no puzzles / is offline.
    if (_loading || _info == null) return const SizedBox.shrink();

    final info = _info!;
    final scheme = Theme.of(context).colorScheme;
    final solved = info.solved;
    final accent = solved ? Colors.green : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _open,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  solved ? Icons.check_circle : Icons.extension,
                  color: accent,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Puzzle',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        solved
                            ? 'Solved today - come back tomorrow'
                            : 'Rating ${info.puzzle.rating} - tap to solve',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  solved ? Icons.replay : Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

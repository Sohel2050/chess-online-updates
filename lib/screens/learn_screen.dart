import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/analytics_service.dart';

import '../data/learn_content.dart';
import '../services/learn_progress_service.dart';
import 'endgame_drill_screen.dart';
import 'lesson_screen.dart';
import 'opening_explorer_screen.dart';
import 'opening_line_screen.dart';

/// Learn hub (roadmap item 11): opening explorer + trainer, endgame drills, short lessons.
/// Everything here is bundled with the app and works offline, for guests too.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  LearnProgress _progress = LearnProgress.empty();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('learn');
    _reload();
  }

  Future<void> _reload() async {
    final p = await LearnProgress.load();
    if (mounted) setState(() => _progress = p);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learn'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Openings ${_progress.openingsDone.length}/${kOpeningLines.length}'),
              Tab(text: 'Endgames ${_progress.endgamesDone.length}/${kEndgameDrills.length}'),
              Tab(text: 'Lessons ${_progress.lessonsDone.length}/${kLessons.length}'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _openingsTab(),
            _endgamesTab(),
            _lessonsTab(),
          ],
        ),
      ),
    );
  }

  /// Overall progress across the three tabs, shown at the top of each.
  Widget _summaryCard() {
    final total = kOpeningLines.length + kEndgameDrills.length + kLessons.length;
    final done = _progress.openingsDone.length + _progress.endgamesDone.length + _progress.lessonsDone.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your progress: $done of $total finished', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _openingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Opening explorer'),
            subtitle: const Text('Play any moves and see the opening name and book continuations.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(const OpeningExplorerScreen()),
          ),
        ),
        const SizedBox(height: 8),
        for (final l in kOpeningLines)
          Card(
            child: ListTile(
              leading: Icon(
                _progress.openingsPerfect.contains(l.id)
                    ? Icons.verified
                    : (_progress.openingsDone.contains(l.id) ? Icons.check_circle_outline : Icons.circle_outlined),
                color: _progress.openingsPerfect.contains(l.id) ? Colors.green : null,
              ),
              title: Text(l.name),
              subtitle: Text('${l.side == 0 ? 'As White' : 'As Black'}  ·  Level ${l.level}/3\n${l.summary}'),
              isThreeLine: true,
              onTap: () => _open(OpeningLineScreen(line: l)),
            ),
          ),
      ],
    );
  }

  Widget _endgamesTab() {
    final categories = <String>[];
    for (final d in kEndgameDrills) {
      if (!categories.contains(d.category)) categories.add(d.category);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        for (final c in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(c, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final d in kEndgameDrills.where((d) => d.category == c))
            Card(
              child: ListTile(
                leading: Icon(
                  _progress.endgamesDone.contains(d.id) ? Icons.check_circle : Icons.circle_outlined,
                  color: _progress.endgamesDone.contains(d.id) ? Colors.green : null,
                ),
                title: Text(d.title),
                subtitle: Text(d.goal),
                onTap: () => _open(EndgameDrillScreen(drill: d)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _lessonsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        const SizedBox(height: 8),
        for (final l in kLessons)
          Card(
            child: ListTile(
              leading: Icon(
                _progress.lessonsDone.contains(l.id) ? Icons.check_circle : Icons.circle_outlined,
                color: _progress.lessonsDone.contains(l.id) ? Colors.green : null,
              ),
              title: Text(l.title),
              subtitle: Text('${l.minutes} min'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(LessonScreen(lesson: l)),
            ),
          ),
      ],
    );
  }
}

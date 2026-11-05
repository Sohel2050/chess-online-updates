import 'package:flutter/material.dart';

import '../data/learn_content.dart';
import '../services/learn_progress_service.dart';
import '../utils/uci_game.dart';
import '../widgets/learn_board.dart';

/// A short lesson: a few paragraphs and, for most of them, a board diagram.
class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  UciGame? _diagram;
  bool _done = false;

  Lesson get lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    if (lesson.fen != null) {
      try {
        _diagram = UciGame(startFen: lesson.fen);
      } catch (_) {
        _diagram = null; // a bad diagram must not hide the lesson text
      }
    }
    LearnProgress.load().then((p) {
      if (mounted) setState(() => _done = p.lessonsDone.contains(lesson.id));
    });
  }

  Future<void> _complete() async {
    await LearnProgress.markLesson(lesson.id);
    if (!mounted) return;
    setState(() => _done = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _diagram;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${lesson.minutes} min read', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (d != null) ...[
              LearnBoard(state: d.squares(d.turn)),
              if (lesson.caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    lesson.caption!,
                    style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            for (final p in lesson.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p, style: theme.textTheme.bodyLarge),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _complete,
              icon: Icon(_done ? Icons.check_circle : Icons.check),
              label: Text(_done ? 'Read again later' : 'Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

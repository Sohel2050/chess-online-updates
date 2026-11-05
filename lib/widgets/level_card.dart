import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mission_provider.dart';
import '../utils/chess_styles.dart';
import '../utils/levels.dart';

String boardLabelFor(String id) => boardStyleById(id).label;

String pieceLabelFor(String id) {
  if (id == 'merida') return 'Merida';
  if (id == 'letters') return 'Letters';
  for (final p in imagePieceStyles) {
    if (p.id == id) return p.label;
  }
  for (final p in glyphPieceStyles) {
    if (p.id == id) return p.label;
  }
  return id;
}

List<String> unlocksAt(int level) =>
    unlocksAtLevel(level, boardLabel: boardLabelFor, pieceLabel: pieceLabelFor);

/// The next level above [level] that unlocks something, with what it unlocks. Null if none left.
({int level, List<String> items})? nextUnlock(int level) {
  for (var l = level + 1; l <= maxLevel; l++) {
    final items = unlocksAt(l);
    if (items.isNotEmpty) return (level: l, items: items);
  }
  return null;
}

/// Level badge + XP bar for the profile screen.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.watch<MissionProvider>().levelInfo;
    final scheme = Theme.of(context).colorScheme;
    final next = nextUnlock(info.level);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
              child: Text('${info.level}',
                  style: TextStyle(color: scheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Level ${info.level} \u00B7 ${levelTitle(info.level)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  info.isMax ? '${info.xp} XP \u00B7 Max level' : '${info.xp} XP \u00B7 ${info.xpToNext} to level ${info.level + 1}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: info.progress, minHeight: 8),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text('Level ${next.level} unlocks: ${next.items.join(', ')}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Shown when claiming a mission pushes the player over a level boundary.
Future<void> showLevelUpDialog(BuildContext context, int fromLevel, int toLevel) {
  final items = <String>[
    for (var l = fromLevel + 1; l <= toLevel; l++) ...unlocksAt(l),
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('\u{1F389} Level $toLevel!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You are now a ${levelTitle(toLevel)}.'),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Unlocked:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final i in items) Text('\u2022 $i'),
            const SizedBox(height: 8),
            const Text('Find them in Options \u2192 Appearance.', style: TextStyle(fontSize: 12.5)),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nice!'))],
    ),
  );
}

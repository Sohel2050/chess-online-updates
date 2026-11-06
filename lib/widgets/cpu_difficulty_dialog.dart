import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

/// "Play With Computer" dialog content: pick your colour (White / Black) and the computer strength, with a live summary and a big Start
/// button. Calls [onConfirm] with the chosen difficulty level and colour.
class CPUDifficultyDialog extends StatefulWidget {
  final Function(int difficulty, int playerColor) onConfirm;

  const CPUDifficultyDialog({super.key, required this.onConfirm});

  @override
  State<CPUDifficultyDialog> createState() => _CPUDifficultyDialogState();
}

enum _ColorChoice { white, black }

class _CPUDifficultyDialogState extends State<CPUDifficultyDialog> {
  int _selectedDifficulty = 0; // Beginner
  _ColorChoice _color = _ColorChoice.white;

  static const List<Color> _levelColors = [
    Color(0xFF43A047), // Beginner
    Color(0xFF00ACC1), // Easy
    Color(0xFFFB8C00), // Normal
    Color(0xFFE53935), // Hard
  ];

  Color get _accent =>
      _levelColors[_selectedDifficulty.clamp(0, _levelColors.length - 1)];

  int _resolveColor() {
    switch (_color) {
      case _ColorChoice.white:
        return Squares.white;
      case _ColorChoice.black:
        return Squares.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final difficulty = Constants.difficulties.firstWhere(
          (d) => d[Constants.level] == _selectedDifficulty,
      orElse: () => Constants.difficulties.first,
    );
    final colorLabel = switch (_color) {
      _ColorChoice.white => 'White',
      _ColorChoice.black => 'Black',
    };

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, Icons.palette_outlined, 'Play as'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _colorCard(
                  context,
                  choice: _ColorChoice.white,
                  label: 'White',
                  badge: _pieceBadge('assets/pieces/chessnut/wK.png', Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _colorCard(
                  context,
                  choice: _ColorChoice.black,
                  label: 'Black',
                  badge: _pieceBadge('assets/pieces/chessnut/bK.png', const Color(0xFF263238)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, Icons.speed_rounded, 'Computer strength'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: Constants.difficulties.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 148,
            ),
            itemBuilder: (context, i) => _difficultyCard(
              context,
              Constants.difficulties[i],
            ),
          ),
          const SizedBox(height: 16),

          // Live summary of what will start
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: _accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You play $colorLabel vs ${difficulty[Constants.name]} computer',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  onPressed: () {
                    // dispose stockfish engine if needed
                    context.read<GameProvider>().disposeStockfish();
                    Navigator.of(context).pop(); // close without action
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  onPressed: () {
                    final color = _resolveColor();
                    log(
                      'Selected Difficulty: $_selectedDifficulty, Color: $color',
                    );
                    widget.onConfirm(_selectedDifficulty, color);
                  },
                  label: const Text(
                    'Start Game',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _pieceBadge(String asset, Color bg) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }

  Widget _colorCard(
      BuildContext context, {
        required _ColorChoice choice,
        required String label,
        required Widget badge,
      }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _color == choice;
    return GestureDetector(
      onTap: () => setState(() => _color = choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyCard(BuildContext context, Map<String, dynamic> d) {
    final scheme = Theme.of(context).colorScheme;
    final int level = d[Constants.level];
    final accent = _levelColors[level.clamp(0, _levelColors.length - 1)];
    final selected = _selectedDifficulty == level;

    return GestureDetector(
      onTap: () => setState(() => _selectedDifficulty = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
            colors: [
              accent.withValues(alpha: 0.25),
              accent.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: selected ? null : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? accent : accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    d[Constants.icon] as IconData,
                    size: 22,
                    color: selected ? Colors.white : accent,
                  ),
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              d[Constants.name] as String,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Strength meter: 1..4 bars
            Row(
              children: List.generate(4, (i) {
                final on = i <= level;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: on ? accent : accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              d[Constants.description] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

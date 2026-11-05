import 'package:flutter/material.dart';

class DifficultyOption extends StatelessWidget {
  final String name;
  final int level;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const DifficultyOption({
    super.key,
    required this.name,
    required this.level,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  static const List<Color> _levelColors = [
    Color(0xFF43A047), // Beginner
    Color(0xFF00ACC1), // Easy
    Color(0xFFFB8C00), // Normal
    Color(0xFFE53935), // Hard
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _levelColors[level.clamp(0, _levelColors.length - 1)];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.08),
                ])
              : null,
          color: isSelected ? null : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isSelected ? 1 : 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: isSelected ? Colors.white : accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                    ),
                    if (level == 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Recommended',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(Icons.check_circle, key: const ValueKey('on'), color: accent, size: 28)
                  : Icon(Icons.radio_button_unchecked, key: const ValueKey('off'), color: scheme.outline, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

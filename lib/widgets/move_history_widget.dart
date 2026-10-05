import 'package:flutter/material.dart';

class MoveHistoryWidget extends StatelessWidget {
  final List<String> moveHistory;

  const MoveHistoryWidget({super.key, required this.moveHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moves',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child:
                moveHistory.isEmpty
                    ? Center(
                      child: Text(
                        'No moves yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                    : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children:
                            moveHistory.asMap().entries.map((entry) {
                              int index = entry.key;
                              String move = entry.value;
                              bool isWhiteMove = index % 2 == 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isWhiteMove
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.surface
                                          : Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(index ~/ 2) + 1}${isWhiteMove ? '.' : '...'} $move',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

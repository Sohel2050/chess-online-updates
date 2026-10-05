import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final List<String> capturedPieces;
  final int materialAdvantage;
  final bool isWhite;
  final PieceSet pieceSet;
  final bool isCompact;

  const CapturedPiecesWidget({
    super.key,
    required this.capturedPieces,
    required this.materialAdvantage,
    required this.isWhite,
    required this.pieceSet,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (capturedPieces.isEmpty && materialAdvantage == 0) {
      return const SizedBox.shrink();
    }

    // Group pieces by type and count them
    Map<String, int> pieceCount = {};
    for (String piece in capturedPieces) {
      pieceCount[piece] = (pieceCount[piece] ?? 0) + 1;
    }

    final pieceSize = isCompact ? 16.0 : 24.0;
    final containerHeight = isCompact ? 20.0 : 32.0;

    return SizedBox(
      height: containerHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Captured pieces
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    pieceCount.entries.map((entry) {
                      final pieceName = entry.key;
                      final count = entry.value;

                      return Container(
                        margin: EdgeInsets.only(right: isCompact ? 2 : 4),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: pieceSize,
                              height: pieceSize,
                              child: pieceSet.piece(context, pieceName),
                            ),
                            if (count > 1)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  padding: EdgeInsets.all(isCompact ? 1 : 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: isCompact ? 12 : 16,
                                    minHeight: isCompact ? 12 : 16,
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: isCompact ? 8 : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          // Material advantage
          if (materialAdvantage > 0) ...[
            SizedBox(width: isCompact ? 4 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 4 : 6,
                vertical: isCompact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
              ),
              child: Text(
                '+$materialAdvantage',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isCompact ? 10 : null,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

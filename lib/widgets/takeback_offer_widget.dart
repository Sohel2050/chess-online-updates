import 'package:flutter/material.dart';

/// Shown to the player who RECEIVED a takeback request from the opponent.
class TakebackOfferWidget extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TakebackOfferWidget({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Opponent asks to take back a move',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Allow takeback',
                onPressed: onAccept,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Decline takeback',
                onPressed: onDecline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

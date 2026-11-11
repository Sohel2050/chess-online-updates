import 'package:flutter/material.dart';

class FriendRequestWidget extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FriendRequestWidget({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'You have a friend request!',
              style: TextStyle(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onAccept, child: const Text('Accept')),
          TextButton(onPressed: onDecline, child: const Text('Decline')),
        ],
      ),
    );
  }
}

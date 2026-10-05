import 'package:flutter/material.dart';

/// A reusable dialog widget for confirming actions.
/// It provides a title, a message, and customizable action buttons.
class ConfirmationDialog extends StatelessWidget {
  final String message;
  final String confirmButtonText;
  final String cancelButtonText;

  const ConfirmationDialog({
    super.key,
    required this.message,
    this.confirmButtonText = 'Yes',
    this.cancelButtonText = 'No',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmButtonText),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelButtonText),
            ),
          ],
        ),
      ],
    );
  }
}

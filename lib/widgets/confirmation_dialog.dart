import 'package:flutter/material.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

/// A reusable dialog body for confirming actions: message + two big buttons.
/// Pops `true` for the confirm button and `false` for cancel.
///
/// Set [isDestructive] for actions that lose something (quit a game, delete...):
/// the confirm button turns red.
class ConfirmationDialog extends StatelessWidget {
  final String message;
  final String confirmButtonText;
  final String cancelButtonText;
  final bool isDestructive;
  final IconData? confirmIcon;

  const ConfirmationDialog({
    super.key,
    required this.message,
    this.confirmButtonText = 'Yes',
    this.cancelButtonText = 'No',
    this.isDestructive = false,
    this.confirmIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.35),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: cs.outline),
                ),
                child: Text(cancelButtonText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isDestructive
                  ? DialogDangerButton(
                      text: confirmButtonText,
                      icon: confirmIcon,
                    )
                  : FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: Text(confirmButtonText),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

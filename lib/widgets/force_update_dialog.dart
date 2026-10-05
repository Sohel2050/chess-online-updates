import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/version_service.dart';

/// Dialog shown when a force update is required
class ForceUpdateDialog extends StatefulWidget {
  final String? message;
  final String? changelog;
  final String currentVersion;
  final String requiredVersion;
  final bool isForced; // true = force update, false = optional update

  const ForceUpdateDialog({
    super.key,
    this.message,
    this.changelog,
    required this.currentVersion,
    required this.requiredVersion,
    this.isForced = true,
  });

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForced, // Allow back button if optional
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('App Update Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.message ??
                    'A new version of the app is required to continue playing. '
                        'Please update from the app store.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Version:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          widget.currentVersion,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Required Version:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          widget.requiredVersion,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.changelog != null && widget.changelog!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "What's New:",
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.changelog!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.isForced)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
          ElevatedButton.icon(
            onPressed: _isOpening
                ? null
                : () async {
                    setState(() => _isOpening = true);
                    await VersionService.openAppStore();
                    // Keep dialog showing even after opening store
                    setState(() => _isOpening = false);
                  },
            icon: _isOpening
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new),
            label: Text(_isOpening ? 'Opening...' : 'Update Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show force update dialog
Future<void> showForceUpdateDialog({
  required BuildContext context,
  required String currentVersion,
  required String requiredVersion,
  String? message,
  String? changelog,
  bool isForced = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !isForced, // Can't dismiss by tapping outside if forced
    builder: (BuildContext context) {
      return ForceUpdateDialog(
        message: message,
        changelog: changelog,
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
        isForced: isForced,
      );
    },
  );
}

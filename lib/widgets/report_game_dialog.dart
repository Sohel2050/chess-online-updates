import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/moderation_service.dart';

/// Lets a player report their opponent in an online game. Shows its own result message.
/// [gameId] is the online room id (GameRoom.gameId).
Future<void> showReportGameDialog(BuildContext context, String gameId) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportGameDialog(gameId: gameId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks. A moderator will review your report.')),
    );
  }
}

class _ReportGameDialog extends StatefulWidget {
  final String gameId;
  const _ReportGameDialog({required this.gameId});

  @override
  State<_ReportGameDialog> createState() => _ReportGameDialogState();
}

class _ReportGameDialogState extends State<_ReportGameDialog> {
  String _reason = 'cheating';
  final TextEditingController _details = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ModerationService().reportGame(widget.gameId, _reason, _details.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send. Check your connection and try again.');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report opponent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in kReportReasons.entries)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: e.key,
                groupValue: _reason,
                title: Text(e.value),
                onChanged: _sending ? null : (v) => setState(() => _reason = v ?? _reason),
              ),
            TextField(
              controller: _details,
              enabled: !_sending,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send report'),
        ),
      ],
    );
  }
}

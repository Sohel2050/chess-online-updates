import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';

/// Asks for a reason and sends a report about a tournament, a club or a club announcement.
/// kind: tournament | club | club_post | club_message. Shows its own confirmation / error message.
Future<void> showReportDialog(BuildContext context, {required String kind, required String targetId, required String title}) async {
  const reasons = <String, String>{
    'inappropriate_name': 'Inappropriate name',
    'offensive_text': 'Offensive text',
    'spam': 'Spam',
    'cheating': 'Cheating',
    'other': 'Other',
  };
  String reason = 'offensive_text';
  final details = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in reasons.entries)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                value: e.key,
                groupValue: reason,
                onChanged: (v) => setLocal(() => reason = v ?? reason),
              ),
            TextField(controller: details, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Details (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
        ],
      ),
    ),
  );
  final text = details.text.trim();
  details.dispose();
  if (send != true || !context.mounted) return;
  String message;
  try {
    await ClubService().report(kind: kind, targetId: targetId, reason: reason, details: text);
    message = 'Thank you. A moderator will look at it.';
  } catch (e) {
    message = e is ApiException ? e.message : 'Request failed. Check your connection.';
  }
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/moderation_service.dart';

/// Settings > Account status: warnings, any ban, and the appeal form.
class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  final ModerationService _service = ModerationService();
  final TextEditingController _message = TextEditingController();
  MyModerationStatus? _status;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.myStatus();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load. Check your connection.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendAppeal() async {
    final text = _message.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Please write at least 10 characters.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.appeal(text);
      _message.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send. Try again.');
    }
    if (mounted) setState(() => _sending = false);
  }

  String _until(DateTime? d) =>
      d == null ? 'permanently' : 'until ${d.toLocal().toString().substring(0, 10)}';

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Account status')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (s == null)
                  Text(_error ?? 'Could not load.', style: const TextStyle(color: Colors.red))
                else ...[
                  Card(
                    child: ListTile(
                      leading: Icon(s.banned ? Icons.block : Icons.verified_user,
                          color: s.banned ? Colors.red : Colors.green),
                      title: Text(s.banned ? 'Banned from online play' : 'In good standing'),
                      subtitle: s.banned
                          ? Text('${_until(s.banUntil)}${s.banReason.isEmpty ? '' : '\nReason: ${s.banReason}'}')
                          : const Text('You can play online games.'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: Text('Warnings: ${s.warnings}'),
                      subtitle: const Text('Repeated violations lead to a ban.'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (s.appealStatus == 'open')
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.hourglass_top),
                        title: Text('Your appeal is being reviewed'),
                      ),
                    )
                  else ...[
                    if (s.appealStatus == 'rejected')
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Your last appeal was rejected'),
                          subtitle: s.appealNote.isEmpty ? null : Text(s.appealNote),
                        ),
                      ),
                    if (s.appealStatus == 'unbanned' && !s.banned)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Your last appeal was accepted'),
                        ),
                      ),
                    if (s.banned) ...[
                      const Text('Think this is a mistake? Tell us what happened.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _message,
                        enabled: !_sending,
                        maxLength: 1000,
                        maxLines: 5,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your appeal'),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      FilledButton(
                        onPressed: _sending ? null : _sendAppeal,
                        child: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Send appeal'),
                      ),
                    ],
                  ],
                ],
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/admin_service.dart';

/// Admin panel card: turn WhatsApp on/off, set the WhatsApp number and the support email
/// shown on the Contact Us screen.
class ContactSettingsCard extends StatefulWidget {
  const ContactSettingsCard({super.key});

  @override
  State<ContactSettingsCard> createState() => _ContactSettingsCardState();
}

class _ContactSettingsCardState extends State<ContactSettingsCard> {
  final _admin = AdminService();
  final _emailCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  bool _waEnabled = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _waCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _admin.getContactConfig();
    if (!mounted) return;
    setState(() {
      _emailCtrl.text = c.email;
      _waCtrl.text = c.whatsappNumber;
      _waEnabled = c.whatsappEnabled;
      _loaded = true;
    });
  }

  bool _validEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    final wa = _waCtrl.text.trim();
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    String? error;
    if (email.isNotEmpty && !_validEmail(email)) {
      error = 'Enter a valid email address';
    } else if (_waEnabled && digits.length < 8) {
      error = 'Enter the WhatsApp number with country code (e.g. +15059103477)';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      await _admin.updateContactConfig(
        ContactConfig(whatsappEnabled: _waEnabled, whatsappNumber: wa, email: email),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: !_loaded
            ? const Center(child: CircularProgressIndicator.adaptive())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Support email',
                      helperText: 'Users tap it to open their mail app (mailto). Empty = default support@albonik.com.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live chat (WhatsApp)'),
                    subtitle: const Text('Show or hide the Live chat card in Contact Us'),
                    value: _waEnabled,
                    onChanged: (v) => setState(() => _waEnabled = v),
                  ),
                  TextField(
                    controller: _waCtrl,
                    enabled: _waEnabled,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Live chat WhatsApp number',
                      helperText: 'With country code, e.g. +15059103477',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

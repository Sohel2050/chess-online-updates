import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'privacy_policy_screen.dart';

/// One-time age + terms confirmation shown before a guest account is created.
/// This app is for people aged 13 and over (COPPA / GDPR-K).
class AgeGate extends StatefulWidget {
  /// Built only after the user has confirmed.
  final WidgetBuilder builder;
  const AgeGate({super.key, required this.builder});

  static const String _prefsKey = 'age_gate_accepted_v1';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  bool? _accepted; // null = still loading
  bool _agree = false;

  @override
  void initState() {
    super.initState();
    AgeGate.isAccepted().then((v) {
      if (mounted) setState(() => _accepted = v);
    });
  }

  Future<void> _confirm() async {
    await AgeGate.markAccepted();
    if (mounted) setState(() => _accepted = true);
  }

  Future<void> _underAge() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sorry'),
        content: const Text(
          'This app is only for people aged 13 and over. '
          'Please ask a parent or guardian for help finding a suitable app.',
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Close app'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
    }
    if (_accepted == true) return widget.builder(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Before you play',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app is for people aged 13 and over. It shows ads and '
                  'lets you play and chat with other players online.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I am 13 or older and I accept the Privacy Policy.',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                    child: const Text('Read Privacy Policy'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _agree ? _confirm : null,
                    child: const Text('Continue'),
                  ),
                ),
                TextButton(
                  onPressed: _underAge,
                  child: const Text('I am under 13'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

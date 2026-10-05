import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/levelplay_provider.dart';
import '../services/consent_service.dart';

/// Lets the user view and change their ad-consent choice.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = true;
  AdConsentStatus _status = AdConsentStatus.unknown;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await ConsentService.getConsentStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _set(bool granted) async {
    setState(() => _isLoading = true);
    await ConsentService.setConsent(granted);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Personalised ads allowed'
              : 'Personalised ads turned off',
        ),
      ),
    );
  }

  String get _statusText {
    switch (_status) {
      case AdConsentStatus.granted:
        return 'Personalised ads: allowed';
      case AdConsentStatus.denied:
        return 'Personalised ads: not allowed';
      case AdConsentStatus.unknown:
        return 'No choice made yet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gdprEnabled =
        context.watch<LevelPlayProvider>().config?.gdprEnabled ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ad consent',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(_statusText),
                        const SizedBox(height: 8),
                        Text(
                          gdprEnabled
                              ? 'Ads are shown to keep the app free. Your '
                                    'choice controls whether ad partners may '
                                    'use your data for personalisation.'
                              : 'Consent prompts are turned off for this app.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _set(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Allow personalised ads'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _set(false),
                  icon: const Icon(Icons.block),
                  label: const Text('Don\'t allow'),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/levelplay_config_model.dart';
import '../models/monetization_config_model.dart';
import '../providers/levelplay_provider.dart';
import '../providers/monetization_provider.dart';
import '../services/levelplay_service.dart';

/// Admin screen to edit Unity LevelPlay settings (App Key + ad unit IDs).
class LevelPlayAdminScreen extends StatefulWidget {
  const LevelPlayAdminScreen({super.key});

  @override
  State<LevelPlayAdminScreen> createState() => _LevelPlayAdminScreenState();
}

class _LevelPlayAdminScreenState extends State<LevelPlayAdminScreen> {
  final _androidAppKey = TextEditingController();
  final _iosAppKey = TextEditingController();
  final _androidBanner = TextEditingController();
  final _iosBanner = TextEditingController();
  final _androidInterstitial = TextEditingController();
  final _iosInterstitial = TextEditingController();
  final _androidRewarded = TextEditingController();
  final _iosRewarded = TextEditingController();
  final _nativePlacement = TextEditingController();

  bool _adsOn = true;
  bool _gdpr = true;
  bool _childDirected = false;
  bool _testSuite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [
      _androidAppKey,
      _iosAppKey,
      _androidBanner,
      _iosBanner,
      _androidInterstitial,
      _iosInterstitial,
      _androidRewarded,
      _iosRewarded,
      _nativePlacement,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final lp = context.read<LevelPlayProvider>();
    final mp = context.read<MonetizationProvider>();
    await lp.loadConfig();
    await mp.loadMonetizationConfig();
    final c = lp.config ?? LevelPlayConfig();
    if (!mounted) return;
    setState(() {
      _androidAppKey.text = c.androidAppKey;
      _iosAppKey.text = c.iosAppKey;
      _androidBanner.text = c.androidBannerId;
      _iosBanner.text = c.iosBannerId;
      _androidInterstitial.text = c.androidInterstitialId;
      _iosInterstitial.text = c.iosInterstitialId;
      _androidRewarded.text = c.androidRewardedId;
      _iosRewarded.text = c.iosRewardedId;
      _nativePlacement.text = c.nativePlacement;
      _gdpr = c.gdprEnabled;
      _childDirected = c.childDirected;
      _testSuite = c.testSuiteEnabled;
      _adsOn = mp.monetizationConfig?.isLevelPlayEnabled ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final lp = context.read<LevelPlayProvider>();
    final mp = context.read<MonetizationProvider>();

    final ok = await lp.updateConfig(
      LevelPlayConfig(
        androidAppKey: _androidAppKey.text.trim(),
        iosAppKey: _iosAppKey.text.trim(),
        androidBannerId: _androidBanner.text.trim(),
        iosBannerId: _iosBanner.text.trim(),
        androidInterstitialId: _androidInterstitial.text.trim(),
        iosInterstitialId: _iosInterstitial.text.trim(),
        androidRewardedId: _androidRewarded.text.trim(),
        iosRewardedId: _iosRewarded.text.trim(),
        nativePlacement: _nativePlacement.text.trim(),
        enabled: _adsOn,
        gdprEnabled: _gdpr,
        childDirected: _childDirected,
        testSuiteEnabled: _testSuite,
      ),
    );
    await mp.updateMonetizationConfig(
      MonetizationConfig(
        provider: _adsOn
            ? MonetizationProviderType.levelplay
            : MonetizationProviderType.disabled,
        adsEnabled: _adsOn,
      ),
    );

    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saved. Restart the app to apply SDK changes.'
              : (lp.error ?? 'Save failed'),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _field(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LevelPlay Ads'),
        actions: [
          IconButton(
            tooltip: 'Open integration test suite',
            icon: const Icon(Icons.bug_report),
            onPressed: LevelPlayService.isInitialized
                ? LevelPlayService.launchTestSuite
                : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Ads enabled'),
                  value: _adsOn,
                  onChanged: (v) => setState(() => _adsOn = v),
                ),
                SwitchListTile(
                  title: const Text('Ask for ad consent (GDPR)'),
                  value: _gdpr,
                  onChanged: (v) => setState(() => _gdpr = v),
                ),
                SwitchListTile(
                  title: const Text('Child-directed app'),
                  value: _childDirected,
                  onChanged: (v) => setState(() => _childDirected = v),
                ),
                SwitchListTile(
                  title: const Text('Enable test suite (next launch)'),
                  value: _testSuite,
                  onChanged: (v) => setState(() => _testSuite = v),
                ),
                _section('Android'),
                _field('App Key', _androidAppKey),
                _field('Banner ad unit ID', _androidBanner),
                _field('Interstitial ad unit ID', _androidInterstitial),
                _field('Rewarded ad unit ID', _androidRewarded),
                _section('iOS'),
                _field('App Key', _iosAppKey),
                _field('Banner ad unit ID', _iosBanner),
                _field('Interstitial ad unit ID', _iosInterstitial),
                _field('Rewarded ad unit ID', _iosRewarded),
                _section('Native'),
                _field('Native placement name (optional)', _nativePlacement),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
    );
  }
}

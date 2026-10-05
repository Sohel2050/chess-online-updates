import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

enum AdConsentStatus { unknown, granted, denied }

/// Simple in-app ad-consent handling for LevelPlay.
///
/// Stores the user's choice locally and forwards it to the LevelPlay SDK
/// (`LevelPlay.setConsent`). This is NOT an IAB-certified CMP; if you need a
/// certified GDPR flow, add a CMP such as Google UMP and LevelPlay will pick
/// its result up automatically.
class ConsentService {
  static final Logger _logger = Logger();

  /// Set once from main.dart. The context used at app start sits above the
  /// MaterialApp, so dialogs must be shown through the navigator key.
  static GlobalKey<NavigatorState>? navigatorKey;
  static const String _key = 'ad_consent_status'; // granted | denied

  static Future<AdConsentStatus> getConsentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'granted':
        return AdConsentStatus.granted;
      case 'denied':
        return AdConsentStatus.denied;
      default:
        return AdConsentStatus.unknown;
    }
  }

  static Future<void> setConsent(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, granted ? 'granted' : 'denied');
    await applyToSdk();
  }

  /// Push the stored choice to LevelPlay. Safe to call before or after init.
  static Future<void> applyToSdk() async {
    final status = await getConsentStatus();
    if (status == AdConsentStatus.unknown) return;
    try {
      LevelPlay.setConsent(status == AdConsentStatus.granted);
    } catch (e) {
      _logger.w('Could not pass consent to LevelPlay: $e');
    }
  }

  static Future<bool> hasConsent() async =>
      await getConsentStatus() == AdConsentStatus.granted;

  /// Ads may be requested once the user has made a choice, or when GDPR
  /// handling is turned off in the admin config.
  static Future<bool> canRequestAds({bool gdprEnabled = true}) async {
    if (!gdprEnabled) return true;
    return await getConsentStatus() != AdConsentStatus.unknown;
  }

  static Future<void> resetConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Shows the consent dialog if no choice has been stored yet.
  static Future<void> showConsentIfNeeded(
    BuildContext context, {
    bool gdprEnabled = true,
  }) async {
    if (!gdprEnabled) return;
    if (await getConsentStatus() != AdConsentStatus.unknown) {
      await applyToSdk();
      return;
    }
    final dialogContext = navigatorKey?.currentContext ?? context;
    if (!dialogContext.mounted) return;
    await showConsentDialog(dialogContext);
  }

  static Future<void> showConsentDialog(BuildContext context) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ads & your data'),
        content: const Text(
          'We show ads to keep this app free. Allow partners to use your '
          'device data for personalised ads? If you decline you will still '
          'see ads, but they will be less relevant. You can change this any '
          'time in Settings → Privacy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Don\'t allow'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await setConsent(granted ?? false);
  }
}

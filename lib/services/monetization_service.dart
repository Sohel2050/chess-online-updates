import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/monetization_provider.dart';
import '../providers/levelplay_provider.dart';
import '../models/user_model.dart';
import '../models/monetization_config_model.dart';
import 'levelplay_service.dart';
import 'consent_service.dart';
import 'api_client.dart';

/// Monetization service (Unity LevelPlay only).
class MonetizationService {
  static final Logger _logger = Logger();

  /// Initialize the monetization system
  static Future<void> initialize(BuildContext context) async {
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );

      // Load monetization configuration
      await monetizationProvider.loadMonetizationConfig();

      if (monetizationProvider.isLevelPlayEnabled) {
        final levelPlayProvider = Provider.of<LevelPlayProvider>(
          context,
          listen: false,
        );
        await levelPlayProvider.loadConfig();
        final config = levelPlayProvider.config;

        if (config != null && context.mounted) {
          // Ask for ad consent (only when GDPR handling is on), then init.
          await ConsentService.showConsentIfNeeded(
            context,
            gdprEnabled: config.gdprEnabled,
          );
          final canRequest = await ConsentService.canRequestAds(
            gdprEnabled: config.gdprEnabled,
          );
          if (canRequest) {
            final ok = await LevelPlayService.initialize(config);
            _logger.i('LevelPlay initialized: $ok');
          } else {
            _logger.w('No ad consent yet, LevelPlay not initialized');
          }
        }
      }

      _logger.i(
        'Monetization system initialized with provider: ${monetizationProvider.currentProvider.value}',
      );
    } catch (e) {
      _logger.e('Failed to initialize monetization system: $e');
    }
  }

  /// Show app launch ad
  static Future<void> showAppLaunchAd({
    required BuildContext context,
    required ChessUser user,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    _logger.i('Attempting to show app launch ad for user: ${user.uid}');
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );

      // Check if app open ads are enabled using cached value
      if (!monetizationProvider.appOpenAdsEnabled) {
        _logger.i('App open ads are disabled by admin, not showing ad');
        onAdFailedToLoad?.call();
        return;
      }

      await monetizationProvider.showAppLaunchAd(
        context: context,
        user: user,
        onAdClosed: onAdClosed ?? () {},
        onAdFailedToLoad: onAdFailedToLoad,
      );
    } catch (e) {
      _logger.e('Error showing app launch ad: $e');
      onAdFailedToLoad?.call();
    }
  }

  /// Show interstitial ad
  static Future<void> showInterstitialAd({
    required BuildContext context,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );

      // Check if interstitial ads are enabled using cached value
      if (!monetizationProvider.interstitialAdsEnabled) {
        _logger.i('Interstitial ads are disabled by admin, not showing ad');
        onAdFailedToLoad?.call();
        return;
      }

      await monetizationProvider.showInterstitialAd(
        context: context,
        onAdClosed: onAdClosed ?? () {},
        onAdFailedToLoad: onAdFailedToLoad,
      );
    } catch (e) {
      _logger.e('Error showing interstitial ad: $e');
      onAdFailedToLoad?.call();
    }
  }

  /// Show rewarded ad
  static Future<void> showRewardedAd({
    required BuildContext context,
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );

      await monetizationProvider.showRewardedAd(
        context: context,
        onUserEarnedReward: onUserEarnedReward,
        onAdClosed: onAdClosed ?? () {},
        onAdFailedToLoad: onAdFailedToLoad,
      );
    } catch (e) {
      _logger.e('Error showing rewarded ad: $e');
      onAdFailedToLoad?.call();
    }
  }

  /// Check if ads should be shown for a user
  static bool shouldShowAds(BuildContext context, ChessUser? user) {
    _logger.d(
      'MonetizationService.shouldShowAds: Checking if ads should be shown for user: ${user?.uid}',
    );
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );

      _logger.d(
        'DEBUG: MonetizationProvider.globalAdsEnabled=${monetizationProvider.globalAdsEnabled}',
      );

      if (user == null) {
        _logger.w('User is null, ads will not be shown.');
        return false;
      }

      bool shouldShow;
      if (user.isGuest) {
        _logger.d('User is a guest. Checking guest ad conditions...');
        shouldShow = monetizationProvider.shouldShowAdsForGuestUser(
          context,
          user,
        );
      } else {
        _logger.d(
          'User is a registered user. Checking standard ad conditions...',
        );
        shouldShow = monetizationProvider.shouldShowAds(
          context,
          user.removeAds,
        );
      }
      _logger.i(
        'MonetizationService.shouldShowAds result: $shouldShow (global=${monetizationProvider.globalAdsEnabled})',
      );
      return shouldShow;
    } catch (e) {
      _logger.e('Error checking if ads should be shown: $e');
      return false;
    }
  }

  /// Check if ads are globally enabled (async version)
  static Future<bool> areAdsGloballyEnabled() async {
    try {
      // Same backend endpoint AdminService's static ad-check methods use
      // (GET /public/ads-settings, no admin login required) — replaces the
      // old direct Firestore `config/ads` read.
      final result = await ApiClient.instance.get('/public/ads-settings', withAuth: false);
      return result['enabled'] ?? true;
    } catch (e) {
      _logger.e('Error checking global ads setting: $e');
      // Default to enabled if there's an error
      return true;
    }
  }

  /// Get current monetization provider name
  static String getCurrentProvider(BuildContext context) {
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );
      return monetizationProvider.currentProvider.value;
    } catch (e) {
      _logger.e('Error getting current provider: $e');
      return 'disabled';
    }
  }

  /// Check if monetization is enabled
  static bool isEnabled(BuildContext context) {
    try {
      final monetizationProvider = Provider.of<MonetizationProvider>(
        context,
        listen: false,
      );
      return !monetizationProvider.isAdsDisabled;
    } catch (e) {
      _logger.e('Error checking if monetization is enabled: $e');
      return false;
    }
  }
}

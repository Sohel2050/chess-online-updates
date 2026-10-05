import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:logger/logger.dart';

import '../models/monetization_config_model.dart';
import '../models/user_model.dart';
import '../services/levelplay_service.dart';
import 'premium_provider.dart';
import 'package:provider/provider.dart';

class MonetizationProvider with ChangeNotifier {
  final Logger _logger = Logger();

  MonetizationConfig? _monetizationConfig;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _globalAdsEnabled = true; // Cache for global ads setting from admin

  // Cache for individual ad type settings
  bool _bannerAdsEnabled = true;
  bool _interstitialAdsEnabled = true;
  bool _appOpenAdsEnabled = true;
  bool _nativeAdsEnabled = true;

  // Getters
  MonetizationConfig? get monetizationConfig => _monetizationConfig;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get globalAdsEnabled => _globalAdsEnabled;
  bool get bannerAdsEnabled => _bannerAdsEnabled;
  bool get interstitialAdsEnabled => _interstitialAdsEnabled;
  bool get appOpenAdsEnabled => _appOpenAdsEnabled;
  bool get nativeAdsEnabled => _nativeAdsEnabled;

  MonetizationProviderType get currentProvider =>
      _monetizationConfig?.provider ?? MonetizationProviderType.disabled;
  bool get adsEnabled => _monetizationConfig?.adsEnabled ?? false;
  bool get isLevelPlayEnabled =>
      _monetizationConfig?.isLevelPlayEnabled ?? false;
  bool get isAdsDisabled => _monetizationConfig?.isAdsDisabled ?? true;

  MonetizationProvider() {
    _initializeMonetizationConfig();
  }

  Future<void> _initializeMonetizationConfig() async {
    _logger.i('DEBUG: MonetizationProvider initialization started');
    await loadMonetizationConfig();
    _logger.i('DEBUG: loadMonetizationConfig complete');
    await _loadGlobalAdsSettings();
    _logger.i('DEBUG: _loadGlobalAdsSettings complete');
    _listenToGlobalAdsChanges();
    _logger.i('DEBUG: _listenToGlobalAdsChanges setup complete');
    _isInitialized = true;
    _logger.i(
      'DEBUG: MonetizationProvider initialization finished (globalAdsEnabled=$_globalAdsEnabled)',
    );
    notifyListeners();
  }

  /// Load global ads setting from the backend (`GET /public/ads-settings`,
  /// already used for this same purpose in monetization_service.dart's
  /// areAdsGloballyEnabled()).
  Future<void> _loadGlobalAdsSettings() async {
    try {
      final result = await ApiClient.instance.get('/public/ads-settings', withAuth: false);

      _globalAdsEnabled = result['enabled'] ?? true;
      _bannerAdsEnabled = result['bannerAdsEnabled'] ?? true;
      _interstitialAdsEnabled = result['interstitialAdsEnabled'] ?? true;
      _appOpenAdsEnabled = result['appOpenAdsEnabled'] ?? true;
      _nativeAdsEnabled = result['nativeAdsEnabled'] ?? true;

      _logger.i(
        'Ads settings loaded: global=$_globalAdsEnabled, banner=$_bannerAdsEnabled, interstitial=$_interstitialAdsEnabled, appOpen=$_appOpenAdsEnabled, native=$_nativeAdsEnabled',
      );
    } catch (e) {
      _logger.e('Error loading global ads settings: $e');
      _globalAdsEnabled = true; // Default to enabled on error
      _bannerAdsEnabled = true;
      _interstitialAdsEnabled = true;
      _appOpenAdsEnabled = true;
      _nativeAdsEnabled = true;
    }
  }

  /// Polls for updates to the global ads setting every 30s — same
  /// effect as the old Firestore realtime listener, without a live socket.
  void _listenToGlobalAdsChanges() {
    Future<void> poll() async {
      try {
        final result = await ApiClient.instance.get('/public/ads-settings', withAuth: false);

        final newGlobalValue = result['enabled'] ?? true;
        final newBannerValue = result['bannerAdsEnabled'] ?? true;
        final newInterstitialValue = result['interstitialAdsEnabled'] ?? true;
        final newAppOpenValue = result['appOpenAdsEnabled'] ?? true;
        final newNativeValue = result['nativeAdsEnabled'] ?? true;

        if (_globalAdsEnabled != newGlobalValue ||
            _bannerAdsEnabled != newBannerValue ||
            _interstitialAdsEnabled != newInterstitialValue ||
            _appOpenAdsEnabled != newAppOpenValue ||
            _nativeAdsEnabled != newNativeValue) {
          _globalAdsEnabled = newGlobalValue;
          _bannerAdsEnabled = newBannerValue;
          _interstitialAdsEnabled = newInterstitialValue;
          _appOpenAdsEnabled = newAppOpenValue;
          _nativeAdsEnabled = newNativeValue;
          _logger.i('Ads settings changed! Notifying listeners...');
          notifyListeners();
        }
      } catch (error) {
        _logger.e('Error polling global ads changes: $error');
      }
    }

    Timer.periodic(const Duration(seconds: 30), (_) => poll());
  }

  /// Load monetization configuration from the backend
  Future<void> loadMonetizationConfig() async {
    try {
      _setLoading(true);
      _error = null;

      final result = await ApiClient.instance.get('/public/config/monetizationConfig', withAuth: false);
      final value = Map<String, dynamic>.from(result['value'] ?? {});

      if (value.isNotEmpty) {
        _monetizationConfig = MonetizationConfig.fromMap(value);
        _logger.i(
          'Monetization config loaded successfully: ${_monetizationConfig?.provider.value}',
        );
      } else {
        _logger.w('Monetization config not found on backend. Using default config.');
        _monetizationConfig = MonetizationConfig.defaultConfig();
      }
    } catch (e) {
      _error = 'Failed to load monetization configuration: $e';
      _logger.e('Error loading monetization config: $e');
      _monetizationConfig = MonetizationConfig.defaultConfig();
      _logger.i('Using default monetization config as fallback');
    } finally {
      _setLoading(false);
    }
  }

  /// Update monetization configuration on the backend (admin functionality)
  Future<void> updateMonetizationConfig(MonetizationConfig config) async {
    try {
      _setLoading(true);
      _error = null;

      final updated = config.copyWith(lastUpdated: DateTime.now());
      await ApiClient.instance.put('/admin/config/monetizationConfig', body: {'value': updated.toMap()});

      _monetizationConfig = config;
      _logger.i(
        'Monetization config updated successfully: ${config.provider.value}',
      );
    } catch (e) {
      _error = 'Failed to update monetization configuration: $e';
      _logger.e('Error updating monetization config: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Polling-based "live" monetization config (every 30s — this rarely
  /// changes) — same Stream-shaped API the Firestore version exposed.
  Stream<MonetizationConfig?> getMonetizationConfigStream() async* {
    while (true) {
      try {
        final result = await ApiClient.instance.get('/public/config/monetizationConfig', withAuth: false);
        final value = Map<String, dynamic>.from(result['value'] ?? {});
        if (value.isNotEmpty) {
          final config = MonetizationConfig.fromMap(value);
          _monetizationConfig = config;
          notifyListeners();
          yield config;
        } else {
          yield null;
        }
      } catch (e) {
        _error = 'Error in monetization config stream: $e';
        _logger.e('Stream error: $e');
        notifyListeners();
        yield null;
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if ads should be shown based on current monetization provider and user preferences
  bool shouldShowAds(BuildContext context, bool? userRemoveAds) {
    _logger.d(
      'DEBUG: shouldShowAds called - isInitialized=$_isInitialized, globalAdsEnabled=$_globalAdsEnabled, userRemoveAds=$userRemoveAds',
    );
    // Ensure config is loaded
    if (!_isInitialized || _monetizationConfig == null) {
      _logger.w('Monetization not initialized, defaulting to no ads');
      return false;
    }

    // Don't show ads if global ads are disabled by admin
    if (!_globalAdsEnabled) {
      _logger.i(
        'DEBUG: BLOCKING ADS - Global ads disabled by admin (globalAdsEnabled=$_globalAdsEnabled)',
      );
      return false;
    }

    // Don't show ads if the user has purchased ad removal
    if (userRemoveAds == true) {
      _logger.d('DEBUG: BLOCKING ADS - User has purchased ad removal');
      return false;
    }

    // Don't show ads if ads are disabled globally
    if (isAdsDisabled) {
      _logger.d(
        'DEBUG: BLOCKING ADS - Ads disabled in config (isAdsDisabled=true)',
      );
      return false;
    }

    // Premium users never see ads
    if (_isPremium(context)) {
      _logger.d('DEBUG: BLOCKING ADS - premium user');
      return false;
    }

    return isLevelPlayEnabled;
  }

  bool _isPremium(BuildContext context) {
    try {
      return Provider.of<PremiumProvider>(context, listen: false).isPremium;
    } catch (_) {
      return false;
    }
  }

  /// Check if ads should be shown for guest users
  bool shouldShowAdsForGuestUser(BuildContext context, ChessUser? user) {
    _logger.d(
      'DEBUG: shouldShowAdsForGuestUser called - isInitialized=$_isInitialized, globalAdsEnabled=$_globalAdsEnabled, userIsGuest=${user?.isGuest}',
    );
    // Ensure config is loaded
    if (!_isInitialized || _monetizationConfig == null) {
      _logger.w('Monetization not initialized, defaulting to no ads');
      return false;
    }

    // Don't show ads if global ads are disabled by admin
    if (!_globalAdsEnabled) {
      _logger.i(
        'DEBUG: BLOCKING ADS FOR GUEST - Global ads disabled by admin (globalAdsEnabled=$_globalAdsEnabled)',
      );
      return false;
    }

    // Don't show ads if ads are disabled globally
    if (isAdsDisabled) {
      _logger.d('DEBUG: BLOCKING ADS FOR GUEST - Ads disabled in config');
      return false;
    }

    if (_isPremium(context)) return false;

    // Guests can't purchase ad removal, so they always see ads when enabled.
    return isLevelPlayEnabled;
  }

  /// Load and show app launch ad based on current provider
  Future<void> showAppLaunchAd({
    required BuildContext context,
    required ChessUser user,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    _logger.i(
      'DEBUG: showAppLaunchAd called - globalAdsEnabled=$_globalAdsEnabled, isInitialized=$_isInitialized',
    );
    // Ensure config is loaded before checking ad status
    if (!_isInitialized || _monetizationConfig == null) {
      _logger.w('Monetization not initialized, waiting for config...');
      await loadMonetizationConfig();
    }

    if (isAdsDisabled) {
      _logger.i(
        'DEBUG: BLOCKING APP LAUNCH AD - Ads disabled in config (isAdsDisabled=true)',
      );
      onAdFailedToLoad?.call();
      return;
    }

    bool shouldShow;
    if (user.isGuest) {
      _logger.d('DEBUG: Checking shouldShowAdsForGuestUser...');
      shouldShow = shouldShowAdsForGuestUser(context, user);
    } else {
      _logger.d('DEBUG: Checking shouldShowAds...');
      shouldShow = shouldShowAds(context, user.removeAds);
    }

    _logger.i(
      'DEBUG: shouldShow decision: $shouldShow (globalAdsEnabled=$_globalAdsEnabled)',
    );
    if (!shouldShow) {
      _logger.i(
        'DEBUG: BLOCKING APP LAUNCH AD - shouldShow returned false (likely due to global ads disabled)',
      );
      onAdFailedToLoad?.call();
      return;
    }

    // LevelPlay has no dedicated app-open format, so the launch ad is an
    // interstitial.
    if (isLevelPlayEnabled) {
      _logger.i('Showing LevelPlay app launch (interstitial) ad');
      await LevelPlayService.showInterstitial(
        onAdClosed: onAdClosed,
        onAdFailed: onAdFailedToLoad,
      );
    } else {
      onAdFailedToLoad?.call();
    }
  }

  /// Load and show interstitial ad based on current provider
  Future<void> showInterstitialAd({
    required BuildContext context,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    _logger.i(
      'DEBUG: showInterstitialAd called - globalAdsEnabled=$_globalAdsEnabled, isInitialized=$_isInitialized',
    );
    // Ensure config is loaded before checking ad status
    if (!_isInitialized || _monetizationConfig == null) {
      _logger.w('Monetization not initialized, waiting for config...');
      await loadMonetizationConfig();
    }

    // Check global ads setting first
    if (!_globalAdsEnabled) {
      _logger.i(
        'DEBUG: BLOCKING INTERSTITIAL AD - Global ads disabled by admin',
      );
      onAdFailedToLoad?.call();
      return;
    }

    if (isAdsDisabled) {
      _logger.i('DEBUG: BLOCKING INTERSTITIAL AD - Ads disabled in config');
      onAdFailedToLoad?.call();
      return;
    }

    if (isLevelPlayEnabled) {
      await LevelPlayService.showInterstitial(
        onAdClosed: onAdClosed,
        onAdFailed: onAdFailedToLoad,
      );
    } else {
      _logger.w('LevelPlay is not enabled');
      onAdFailedToLoad?.call();
    }
  }

  /// Load and show rewarded ad based on current provider
  Future<void> showRewardedAd({
    required BuildContext context,
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailedToLoad,
  }) async {
    _logger.i(
      'DEBUG: showRewardedAd called - globalAdsEnabled=$_globalAdsEnabled, isInitialized=$_isInitialized',
    );
    // Ensure config is loaded before checking ad status
    if (!_isInitialized || _monetizationConfig == null) {
      _logger.w('Monetization not initialized, waiting for config...');
      await loadMonetizationConfig();
    }

    // Check global ads setting first
    if (!_globalAdsEnabled) {
      _logger.i('DEBUG: BLOCKING REWARDED AD - Global ads disabled by admin');
      onAdFailedToLoad?.call();
      return;
    }

    if (isAdsDisabled) {
      _logger.i('DEBUG: BLOCKING REWARDED AD - Ads disabled in config');
      onAdFailedToLoad?.call();
      return;
    }

    if (isLevelPlayEnabled) {
      await LevelPlayService.showRewarded(
        onUserEarnedReward: onUserEarnedReward,
        onAdClosed: onAdClosed,
        onAdFailed: onAdFailedToLoad,
      );
    } else {
      _logger.w('LevelPlay is not enabled');
      onAdFailedToLoad?.call();
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../models/levelplay_config_model.dart';
import 'consent_service.dart';

/// Thin wrapper around the Unity LevelPlay SDK (interstitial + rewarded).
/// Banner and native are widgets, see widgets/monetization_ads_widget.dart.
class LevelPlayService {
  LevelPlayService._();

  static final Logger _logger = Logger();

  static bool _initialized = false;
  static Completer<bool>? _initCompleter;
  static LevelPlayConfig? _config;

  static LevelPlayInterstitialAd? _interstitial;
  static LevelPlayRewardedAd? _rewarded;
  static _InterstitialListener? _interstitialListener;
  static _RewardedListener? _rewardedListener;

  static bool get isInitialized => _initialized;
  static LevelPlayConfig? get config => _config;

  /// Initialise the SDK once. Returns true when ready to load ads.
  static Future<bool> initialize(LevelPlayConfig config, {String? userId}) {
    if (_initialized) return Future.value(true);
    if (_initCompleter != null) return _initCompleter!.future;

    if (!config.enabled || !config.hasAppKey) {
      _logger.w('LevelPlay disabled or App Key missing, skipping init');
      return Future.value(false);
    }

    _config = config;
    _initCompleter = Completer<bool>();

    // Regulation / test settings must be set BEFORE init.
    final meta = <String, List<String>>{
      if (config.childDirected) 'is_child_directed': ['true'],
      if (config.testSuiteEnabled) 'is_test_suite': ['enable'],
    };
    if (meta.isNotEmpty) LevelPlay.setMetaData(meta);
    ConsentService.applyToSdk();

    final builder = LevelPlayInitRequest.builder(config.appKey);
    if (userId != null && userId.isNotEmpty) builder.withUserId(userId);

    LevelPlay.init(
      initRequest: builder.build(),
      initListener: _InitListener(
        onSuccess: () {
          _initialized = true;
          _createFullScreenAds();
          if (!(_initCompleter?.isCompleted ?? true)) {
            _initCompleter!.complete(true);
          }
        },
        onFailed: (message) {
          _logger.e('LevelPlay init failed: $message');
          _initialized = false;
          final c = _initCompleter;
          _initCompleter = null; // allow a later retry
          if (c != null && !c.isCompleted) c.complete(false);
        },
      ),
    );
    return _initCompleter!.future;
  }

  static void _createFullScreenAds() {
    final cfg = _config!;
    if (cfg.interstitialId.isNotEmpty) {
      _interstitialListener = _InterstitialListener();
      _interstitial = LevelPlayInterstitialAd(adUnitId: cfg.interstitialId)
        ..setListener(_interstitialListener!)
        ..loadAd();
    }
    if (cfg.rewardedId.isNotEmpty) {
      _rewardedListener = _RewardedListener();
      _rewarded = LevelPlayRewardedAd(adUnitId: cfg.rewardedId)
        ..setListener(_rewardedListener!)
        ..loadAd();
    }
  }

  static Future<bool> _waitReady(
    Future<bool> Function() isReady,
    VoidCallback reload, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (await isReady()) return true;
    reload();
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (await isReady()) return true;
    }
    return false;
  }

  /// Show an interstitial. [onAdClosed] is called after it closes,
  /// [onAdFailed] if nothing could be shown (so callers can continue).
  static Future<void> showInterstitial({
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailed,
  }) async {
    final ad = _interstitial;
    final listener = _interstitialListener;
    if (!_initialized || ad == null || listener == null) {
      onAdFailed?.call();
      return;
    }
    final ready = await _waitReady(
      () async => await ad.isAdReady(),
      () => ad.loadAd(),
    );
    if (!ready) {
      onAdFailed?.call();
      return;
    }
    listener.onClosed = onAdClosed;
    listener.onFailed = onAdFailed;
    ad.showAd();
  }

  /// Show a rewarded ad. [onUserEarnedReward] fires on `onAdRewarded`
  /// (which can arrive after the ad is closed).
  static Future<void> showRewarded({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailed,
  }) async {
    final ad = _rewarded;
    final listener = _rewardedListener;
    if (!_initialized || ad == null || listener == null) {
      onAdFailed?.call();
      return;
    }
    final ready = await _waitReady(
      () async => await ad.isAdReady(),
      () => ad.loadAd(),
      timeout: const Duration(seconds: 6),
    );
    if (!ready) {
      onAdFailed?.call();
      return;
    }
    listener.onRewarded = onUserEarnedReward;
    listener.onClosed = onAdClosed;
    listener.onFailed = onAdFailed;
    ad.showAd();
  }

  /// Opens the LevelPlay integration test suite (admin/debug). Requires
  /// `testSuiteEnabled` in the config *before* the app started.
  static void launchTestSuite() {
    if (!_initialized) return;
    LevelPlay.launchTestSuite();
  }
}

class _InitListener implements LevelPlayInitListener {
  final VoidCallback onSuccess;
  final void Function(String message) onFailed;
  _InitListener({required this.onSuccess, required this.onFailed});

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) => onSuccess();

  @override
  void onInitFailed(LevelPlayInitError error) => onFailed(error.toString());
}

class _InterstitialListener implements LevelPlayInterstitialAdListener {
  VoidCallback? onClosed;
  VoidCallback? onFailed;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLoadFailed(LevelPlayAdError error) {}
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    LevelPlayService._interstitial?.loadAd();
    final cb = onFailed;
    onClosed = null;
    onFailed = null;
    cb?.call();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    LevelPlayService._interstitial?.loadAd(); // preload the next one
    final cb = onClosed;
    onClosed = null;
    onFailed = null;
    cb?.call();
  }
}

class _RewardedListener implements LevelPlayRewardedAdListener {
  VoidCallback? onRewarded;
  VoidCallback? onClosed;
  VoidCallback? onFailed;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLoadFailed(LevelPlayAdError error) {}
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    final cb = onRewarded;
    onRewarded = null;
    cb?.call();
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    LevelPlayService._rewarded?.loadAd();
    final cb = onFailed;
    onRewarded = null;
    onClosed = null;
    onFailed = null;
    cb?.call();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    LevelPlayService._rewarded?.loadAd();
    final cb = onClosed;
    onClosed = null;
    onFailed = null;
    // onRewarded is intentionally left set: it may fire after onAdClosed.
    cb?.call();
  }
}

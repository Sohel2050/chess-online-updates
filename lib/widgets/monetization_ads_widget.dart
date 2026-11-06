import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../models/user_model.dart';
import '../providers/monetization_provider.dart';
import '../providers/premium_provider.dart';
import '../services/levelplay_service.dart';

enum MonetizationAdType { banner, native }

/// Shows a Unity LevelPlay banner or native ad.
///
/// * `banner`: adaptive banner.
/// * `native`: LevelPlay SMALL native template (needs ~175dp height). If the
///   slot is shorter than that, an adaptive banner is shown instead so the
///   ad is never clipped.
class MonetizationAdsWidget extends StatefulWidget {
  final ChessUser? user;
  final MonetizationAdType adType;

  /// Called with `true` when an ad is (or can be) shown and `false` when the
  /// slot should be hidden (ads disabled, SDK not ready in time, or the ad
  /// failed to load). Lets a screen collapse the empty slot.
  final ValueChanged<bool>? onVisibilityChanged;

  const MonetizationAdsWidget({
    super.key,
    this.user,
    this.adType = MonetizationAdType.banner,
    this.onVisibilityChanged,
  });

  @override
  State<MonetizationAdsWidget> createState() => _MonetizationAdsWidgetState();
}

class _MonetizationAdsWidgetState extends State<MonetizationAdsWidget> {
  static const double _nativeHeight = 175;
  static const double _nativeWidth = 300;

  bool _sdkReady = LevelPlayService.isInitialized;
  Timer? _readyTimer;
  bool? _lastReported;

  void _report(bool visible) {
    if (_lastReported == visible) return;
    _lastReported = visible;
    final cb = widget.onVisibilityChanged;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(visible);
    });
  }

  @override
  void initState() {
    super.initState();
    if (!_sdkReady) {
      // The SDK initialises asynchronously after app start; wait for it.
      var tries = 0;
      _readyTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        tries++;
        if (LevelPlayService.isInitialized) {
          t.cancel();
          if (mounted) setState(() => _sdkReady = true);
        } else if (tries >= 30) {
          t.cancel();
          _report(false); // SDK never became ready: hide the slot
        }
      });
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MonetizationProvider, PremiumProvider>(
      builder: (context, monetization, premium, _) {
        if (!monetization.globalAdsEnabled ||
            monetization.isAdsDisabled ||
            premium.isPremium ||
            widget.user?.removeAds == true) {
          _report(false);
          return const SizedBox.shrink();
        }

        final typeEnabled = widget.adType == MonetizationAdType.banner
            ? monetization.bannerAdsEnabled
            : monetization.nativeAdsEnabled;
        if (!typeEnabled) {
          _report(false);
          return const SizedBox.shrink();
        }
        if (!_sdkReady) return const SizedBox.shrink(); // still starting

        final config = LevelPlayService.config;
        if (config == null) {
          _report(false);
          return const SizedBox.shrink();
        }

        if (widget.adType == MonetizationAdType.native) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final fits =
                  constraints.maxHeight == double.infinity ||
                  constraints.maxHeight >= _nativeHeight;
              if (fits) {
                return _NativeAdView(
                  placement: config.nativePlacement,
                  height: _nativeHeight,
                  width: _nativeWidth,
                  onLoaded: () => _report(true),
                  onFailed: () => _report(false),
                );
              }
              return _BannerAdView(
                adUnitId: config.bannerId,
                onLoaded: () => _report(true),
                onFailed: () => _report(false),
              );
            },
          );
        }
        return _BannerAdView(
          adUnitId: config.bannerId,
          onLoaded: () => _report(true),
          onFailed: () => _report(false),
        );
      },
    );
  }
}

class _BannerAdView extends StatefulWidget {
  final String adUnitId;
  final VoidCallback? onLoaded;
  final VoidCallback? onFailed;
  const _BannerAdView({required this.adUnitId, this.onLoaded, this.onFailed});

  @override
  State<_BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<_BannerAdView>
    implements LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _key =
      GlobalKey<LevelPlayBannerAdViewState>();
  LevelPlayAdSize? _size;

  @override
  void initState() {
    super.initState();
    LevelPlayAdSize.createAdaptiveAdSize().then((size) {
      if (mounted) setState(() => _size = size);
    });
  }

  @override
  void dispose() {
    _key.currentState?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (widget.adUnitId.isEmpty || size == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: LevelPlayBannerAdView(
          key: _key,
          adUnitId: widget.adUnitId,
          adSize: size,
          listener: this,
          onPlatformViewCreated: () => _key.currentState?.loadAd(),
        ),
      ),
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => widget.onLoaded?.call();
  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay banner failed: $error');
    widget.onFailed?.call();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}

class _NativeAdView extends StatefulWidget {
  final String placement;
  final double height;
  final double width;
  final VoidCallback? onLoaded;
  final VoidCallback? onFailed;
  const _NativeAdView({
    required this.placement,
    required this.height,
    required this.width,
    this.onLoaded,
    this.onFailed,
  });

  @override
  State<_NativeAdView> createState() => _NativeAdViewState();
}

class _NativeAdViewState extends State<_NativeAdView>
    implements LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;

  @override
  void initState() {
    super.initState();
    final builder = LevelPlayNativeAd.builder().withListener(this);
    if (widget.placement.isNotEmpty) {
      builder.withPlacementName(widget.placement);
    }
    _nativeAd = builder.build();
  }

  @override
  void dispose() {
    _nativeAd?.destroyAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LevelPlayNativeAdView(
        height: widget.height,
        width: widget.width,
        nativeAd: _nativeAd,
        templateType: LevelPlayTemplateType.SMALL,
        onPlatformViewCreated: () => _nativeAd?.loadAd(),
      ),
    );
  }

  @override
  void onAdClicked(dynamic nativeAd, dynamic adInfo) {}
  @override
  void onAdImpression(dynamic nativeAd, dynamic adInfo) {}
  @override
  void onAdLoadFailed(dynamic nativeAd, dynamic error) {
    debugPrint('LevelPlay native failed: $error');
    widget.onFailed?.call();
  }

  @override
  void onAdLoaded(dynamic nativeAd, dynamic adInfo) => widget.onLoaded?.call();
}

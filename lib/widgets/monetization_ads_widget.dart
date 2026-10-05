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

  const MonetizationAdsWidget({
    super.key,
    this.user,
    this.adType = MonetizationAdType.banner,
  });

  @override
  State<MonetizationAdsWidget> createState() => _MonetizationAdsWidgetState();
}

class _MonetizationAdsWidgetState extends State<MonetizationAdsWidget> {
  static const double _nativeHeight = 175;
  static const double _nativeWidth = 300;

  bool _sdkReady = LevelPlayService.isInitialized;
  Timer? _readyTimer;

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
          return const SizedBox.shrink();
        }

        final typeEnabled = widget.adType == MonetizationAdType.banner
            ? monetization.bannerAdsEnabled
            : monetization.nativeAdsEnabled;
        if (!typeEnabled || !_sdkReady) return const SizedBox.shrink();

        final config = LevelPlayService.config;
        if (config == null) return const SizedBox.shrink();

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
                );
              }
              return _BannerAdView(adUnitId: config.bannerId);
            },
          );
        }
        return _BannerAdView(adUnitId: config.bannerId);
      },
    );
  }
}

class _BannerAdView extends StatefulWidget {
  final String adUnitId;
  const _BannerAdView({required this.adUnitId});

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
  void onAdLoaded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('LevelPlay banner failed: $error');
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
  const _NativeAdView({
    required this.placement,
    required this.height,
    required this.width,
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
  }

  @override
  void onAdLoaded(dynamic nativeAd, dynamic adInfo) {}
}

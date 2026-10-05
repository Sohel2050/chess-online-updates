import 'dart:io';
import 'package:flutter_chess_app/utils/constants.dart';

/// Unity LevelPlay settings, managed from the admin panel and stored on the
/// backend (`/admin/config/levelplayConfig`, read via `/public/config/...`).
class LevelPlayConfig {
  final String androidAppKey;
  final String iosAppKey;
  final String androidBannerId;
  final String iosBannerId;
  final String androidInterstitialId;
  final String iosInterstitialId;
  final String androidRewardedId;
  final String iosRewardedId;
  final String nativePlacement;
  final bool enabled;
  final bool gdprEnabled;
  final bool childDirected;
  final bool testSuiteEnabled;
  final DateTime lastUpdated;

  LevelPlayConfig({
    this.androidAppKey = '',
    this.iosAppKey = '',
    this.androidBannerId = '',
    this.iosBannerId = '',
    this.androidInterstitialId = '',
    this.iosInterstitialId = '',
    this.androidRewardedId = '',
    this.iosRewardedId = '',
    this.nativePlacement = '',
    this.enabled = true,
    this.gdprEnabled = true,
    this.childDirected = false,
    this.testSuiteEnabled = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  String get appKey => Platform.isIOS ? iosAppKey : androidAppKey;
  String get bannerId => Platform.isIOS ? iosBannerId : androidBannerId;
  String get interstitialId =>
      Platform.isIOS ? iosInterstitialId : androidInterstitialId;
  String get rewardedId => Platform.isIOS ? iosRewardedId : androidRewardedId;

  bool get hasAppKey => appKey.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    Constants.lpAndroidAppKey: androidAppKey,
    Constants.lpIosAppKey: iosAppKey,
    Constants.lpAndroidBannerId: androidBannerId,
    Constants.lpIosBannerId: iosBannerId,
    Constants.lpAndroidInterstitialId: androidInterstitialId,
    Constants.lpIosInterstitialId: iosInterstitialId,
    Constants.lpAndroidRewardedId: androidRewardedId,
    Constants.lpIosRewardedId: iosRewardedId,
    Constants.lpNativePlacement: nativePlacement,
    Constants.enabled: enabled,
    Constants.lpGdprEnabled: gdprEnabled,
    Constants.lpChildDirected: childDirected,
    Constants.lpTestSuite: testSuiteEnabled,
    Constants.lastUpdated: lastUpdated.toIso8601String(),
  };

  factory LevelPlayConfig.fromMap(Map<String, dynamic> m) => LevelPlayConfig(
    androidAppKey: m[Constants.lpAndroidAppKey] ?? '',
    iosAppKey: m[Constants.lpIosAppKey] ?? '',
    androidBannerId: m[Constants.lpAndroidBannerId] ?? '',
    iosBannerId: m[Constants.lpIosBannerId] ?? '',
    androidInterstitialId: m[Constants.lpAndroidInterstitialId] ?? '',
    iosInterstitialId: m[Constants.lpIosInterstitialId] ?? '',
    androidRewardedId: m[Constants.lpAndroidRewardedId] ?? '',
    iosRewardedId: m[Constants.lpIosRewardedId] ?? '',
    nativePlacement: m[Constants.lpNativePlacement] ?? '',
    enabled: m[Constants.enabled] ?? true,
    gdprEnabled: m[Constants.lpGdprEnabled] ?? true,
    childDirected: m[Constants.lpChildDirected] ?? false,
    testSuiteEnabled: m[Constants.lpTestSuite] ?? false,
    lastUpdated: m[Constants.lastUpdated] is String
        ? DateTime.tryParse(m[Constants.lastUpdated]) ?? DateTime.now()
        : DateTime.now(),
  );

  LevelPlayConfig copyWith({
    String? androidAppKey,
    String? iosAppKey,
    String? androidBannerId,
    String? iosBannerId,
    String? androidInterstitialId,
    String? iosInterstitialId,
    String? androidRewardedId,
    String? iosRewardedId,
    String? nativePlacement,
    bool? enabled,
    bool? gdprEnabled,
    bool? childDirected,
    bool? testSuiteEnabled,
    DateTime? lastUpdated,
  }) => LevelPlayConfig(
    androidAppKey: androidAppKey ?? this.androidAppKey,
    iosAppKey: iosAppKey ?? this.iosAppKey,
    androidBannerId: androidBannerId ?? this.androidBannerId,
    iosBannerId: iosBannerId ?? this.iosBannerId,
    androidInterstitialId: androidInterstitialId ?? this.androidInterstitialId,
    iosInterstitialId: iosInterstitialId ?? this.iosInterstitialId,
    androidRewardedId: androidRewardedId ?? this.androidRewardedId,
    iosRewardedId: iosRewardedId ?? this.iosRewardedId,
    nativePlacement: nativePlacement ?? this.nativePlacement,
    enabled: enabled ?? this.enabled,
    gdprEnabled: gdprEnabled ?? this.gdprEnabled,
    childDirected: childDirected ?? this.childDirected,
    testSuiteEnabled: testSuiteEnabled ?? this.testSuiteEnabled,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
}

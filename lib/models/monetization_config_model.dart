import 'package:flutter_chess_app/utils/constants.dart';

/// Only Unity LevelPlay is supported now. Old stored values such as
/// 'admob' or 'applovin' are treated as LevelPlay so existing configs keep
/// working after the migration.
enum MonetizationProviderType { levelplay, disabled }

extension MonetizationProviderExtension on MonetizationProviderType {
  String get value {
    switch (this) {
      case MonetizationProviderType.levelplay:
        return 'levelplay';
      case MonetizationProviderType.disabled:
        return 'disabled';
    }
  }

  static MonetizationProviderType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'levelplay':
      case 'admob':
      case 'applovin':
        return MonetizationProviderType.levelplay;
      default:
        return MonetizationProviderType.disabled;
    }
  }
}

class MonetizationConfig {
  final MonetizationProviderType provider;
  final bool adsEnabled;
  final DateTime lastUpdated;

  MonetizationConfig({
    required this.provider,
    this.adsEnabled = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    Constants.monetizationProvider: provider.value,
    Constants.adsEnabled: adsEnabled,
    Constants.lastUpdated: lastUpdated.toIso8601String(),
  };

  factory MonetizationConfig.fromMap(Map<String, dynamic> map) {
    final raw = map[Constants.lastUpdated];
    return MonetizationConfig(
      provider: MonetizationProviderExtension.fromString(
        (map[Constants.monetizationProvider] ?? 'levelplay').toString(),
      ),
      adsEnabled: map[Constants.adsEnabled] ?? true,
      lastUpdated: raw is String
          ? DateTime.tryParse(raw) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  MonetizationConfig copyWith({
    MonetizationProviderType? provider,
    bool? adsEnabled,
    DateTime? lastUpdated,
  }) => MonetizationConfig(
    provider: provider ?? this.provider,
    adsEnabled: adsEnabled ?? this.adsEnabled,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  /// Default when nothing is stored yet: LevelPlay on.
  factory MonetizationConfig.defaultConfig() =>
      MonetizationConfig(provider: MonetizationProviderType.levelplay);

  bool get isLevelPlayEnabled =>
      provider == MonetizationProviderType.levelplay && adsEnabled;
  bool get isAdsDisabled =>
      provider == MonetizationProviderType.disabled || !adsEnabled;
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

/// Model for version configuration from the backend.
class VersionConfig {
  final String minimumVersion;
  final String latestVersion;
  final String? updateMessage;
  final String? changelog; // What's new in this version
  final bool forceUpdate;
  final String? playStoreUrl;
  final String? appStoreUrl;

  VersionConfig({
    required this.minimumVersion,
    required this.latestVersion,
    this.updateMessage,
    this.changelog,
    this.forceUpdate = false,
    this.playStoreUrl,
    this.appStoreUrl,
  });

  /// Parses the GitHub `update_config.json` file:
  /// {"min_version","latest_version","update_message","play_store_url","app_store_url"}
  factory VersionConfig.fromGithubJson(Map<String, dynamic> map) {
    String? clean(dynamic v) {
      final t = (v as String?)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return VersionConfig(
      minimumVersion: clean(map['min_version']) ?? '0.0.0',
      latestVersion: clean(map['latest_version']) ?? '0.0.0',
      updateMessage: clean(map['update_message']),
      changelog: clean(map['changelog']),
      forceUpdate: map['force_update'] as bool? ?? false,
      playStoreUrl: clean(map['play_store_url']),
      appStoreUrl: clean(map['app_store_url']),
    );
  }

  factory VersionConfig.fromMap(Map<String, dynamic> map) {
    return VersionConfig(
      minimumVersion: map['minimumVersion'] as String? ?? '0.0.0',
      latestVersion: map['latestVersion'] as String? ?? '0.0.0',
      updateMessage: map['updateMessage'] as String?,
      changelog: map['changelog'] as String?,
      forceUpdate: map['forceUpdate'] as bool? ?? false,
      playStoreUrl: map['playStoreUrl'] as String?,
      appStoreUrl: map['appStoreUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minimumVersion': minimumVersion,
      'latestVersion': latestVersion,
      if (updateMessage != null) 'updateMessage': updateMessage,
      if (changelog != null) 'changelog': changelog,
      'forceUpdate': forceUpdate,
      if (playStoreUrl != null) 'playStoreUrl': playStoreUrl,
      if (appStoreUrl != null) 'appStoreUrl': appStoreUrl,
    };
  }
}

/// Service to manage app version checking and updates via the backend
/// (`/admin/config/versionConfig` / `/public/config/versionConfig`) —
/// replaces the old Firestore `config/version` document.
class VersionService {
  static final Logger _logger = Logger();
  static const String _configKey = 'versionConfig';

  /// Version rules live in a public JSON file on GitHub. Edit that file (and
  /// commit) to force or suggest an update; no app release is needed.
  static const String _githubConfigUrl =
      'https://raw.githubusercontent.com/Sohel2050/Chess-Version-Controller/main/update_config.json';

  /// Last config fetched, used by [openAppStore] for the store links.
  static VersionConfig? _lastConfig;

  static Future<VersionConfig?> _fetchGithubConfig() async {
    try {
      // The query string avoids stale CDN/browser caches.
      final uri = Uri.parse(
        '$_githubConfigUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http
          .get(uri, headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _logger.w('GitHub version config HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final config = VersionConfig.fromGithubJson(decoded);
      _logger.i(
        'GitHub version config: min=${config.minimumVersion}, latest=${config.latestVersion}',
      );
      return config;
    } catch (e) {
      _logger.w('Could not fetch GitHub version config: $e');
      return null;
    }
  }

  /// Enable test/demo mode to show force update dialog without a real
  /// backend config. Set to true to see the dialog, false to use the
  /// real stored config.
  static bool useTestMode = false;

  /// Get the current app version
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      _logger.i('Current app version: $version');
      return version;
    } catch (e) {
      _logger.e('Error getting current version: $e');
      return '0.0.0';
    }
  }

  /// Get version configuration from the backend
  static Future<VersionConfig?> getVersionConfig() async {
    try {
      // Test/demo mode: return dummy config that triggers force update
      if (useTestMode) {
        _logger.i('=== USING TEST MODE - returning dummy version config ===');
        final config = VersionConfig(
          minimumVersion: '99.0.0', // Much higher than any real version
          latestVersion: '100.0.0',
          updateMessage:
              'A new version is available with exciting features! Please update to continue.',
          changelog:
              '• Fixed critical bugs\n• Improved performance\n• Added new features\n• Enhanced UI/UX',
          forceUpdate: true,
        );
        _logger.i(
          'TEST MODE Config: min=${config.minimumVersion}, latest=${config.latestVersion}, force=${config.forceUpdate}',
        );
        return config;
      }

      // 1) Primary source: GitHub update_config.json
      final github = await _fetchGithubConfig();
      if (github != null) {
        _lastConfig = github;
        return github;
      }

      _logger.i('Falling back to backend version config...');
      final result = await ApiClient.instance.get('/public/config/$_configKey', withAuth: false);
      final value = Map<String, dynamic>.from(result['value'] ?? {});

      if (value.isEmpty) {
        _logger.w('Version config not found on backend');
        return null;
      }

      final config = VersionConfig.fromMap(value);
      _lastConfig = config;
      _logger.i(
        'Version config fetched: min=${config.minimumVersion}, latest=${config.latestVersion}, force=${config.forceUpdate}',
      );
      return config;
    } catch (e) {
      _logger.e('Error fetching version config from backend: $e');
      return null;
    }
  }

  /// Compare two semantic versions (e.g., "1.2.3" vs "1.2.4")
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int compareVersions(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map(int.parse).toList();
      final parts2 = v2.split('.').map(int.parse).toList();

      // Pad with zeros to make same length
      final maxLength = parts1.length > parts2.length
          ? parts1.length
          : parts2.length;
      while (parts1.length < maxLength) parts1.add(0);
      while (parts2.length < maxLength) parts2.add(0);

      for (int i = 0; i < maxLength; i++) {
        if (parts1[i] < parts2[i]) {
          _logger.i('compareVersions: $v1 < $v2 → -1');
          return -1;
        }
        if (parts1[i] > parts2[i]) {
          _logger.i('compareVersions: $v1 > $v2 → 1');
          return 1;
        }
      }
      _logger.i('compareVersions: $v1 == $v2 → 0');
      return 0;
    } catch (e) {
      _logger.e('Error comparing versions: $e');
      return 0;
    }
  }

  /// Check if update is required
  /// Returns true if current version < minimum required version
  static Future<bool> isUpdateRequired() async {
    try {
      final config = await getVersionConfig();
      if (config == null) return false;

      final currentVersion = await getCurrentVersion();
      final comparison = compareVersions(currentVersion, config.minimumVersion);

      final isRequired = comparison < 0; // current < minimum
      _logger.i(
        'Update required check: current=$currentVersion, minimum=${config.minimumVersion}, required=$isRequired',
      );

      return isRequired;
    } catch (e) {
      _logger.e('Error checking if update is required: $e');
      return false;
    }
  }

  /// Check if update is available (newer version exists)
  static Future<bool> isUpdateAvailable() async {
    try {
      final config = await getVersionConfig();
      if (config == null) return false;

      final currentVersion = await getCurrentVersion();
      final comparison = compareVersions(currentVersion, config.latestVersion);

      final isAvailable = comparison < 0; // current < latest
      _logger.i(
        'Update available check: current=$currentVersion, latest=${config.latestVersion}, available=$isAvailable',
      );

      return isAvailable;
    } catch (e) {
      _logger.e('Error checking if update is available: $e');
      return false;
    }
  }

  /// Open the app store to update the app
  static Future<bool> openAppStore() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;

      // Prefer the store links from update_config.json
      final config = _lastConfig ?? await getVersionConfig();
      String? storeUrl;
      if (Platform.isAndroid) {
        storeUrl =
            config?.playStoreUrl ??
            'https://play.google.com/store/apps/details?id=$packageName';
      } else if (Platform.isIOS) {
        final ios = config?.appStoreUrl;
        // Ignore the placeholder id (idXXXXXXXXX) until a real one is set.
        storeUrl = (ios == null || ios.contains('XXXX')) ? null : ios;
      }
      if (storeUrl == null) {
        _logger.w('No app store link available for this platform');
        return false;
      }

      if (await canLaunchUrl(Uri.parse(storeUrl))) {
        await launchUrl(
          Uri.parse(storeUrl),
          mode: LaunchMode.externalApplication,
        );
        return true;
      }

      _logger.w('Could not open app store');
      return false;
    } catch (e) {
      _logger.e('Error opening app store: $e');
      return false;
    }
  }

  /// Log version check for analytics
  static Future<void> logVersionCheck(bool updateRequired) async {
    try {
      final currentVersion = await getCurrentVersion();
      _logger.i(
        'Version check logged: version=$currentVersion, updateRequired=$updateRequired',
      );
    } catch (e) {
      _logger.e('Error logging version check: $e');
    }
  }

  /// Initialize version config on the backend if it doesn't exist.
  /// This is called once on app startup to ensure the config exists.
  /// Requires an admin-logged-in session (uses the admin config endpoint).
  static Future<bool> initializeVersionConfigIfNeeded() async {
    try {
      _logger.i('Checking if version config needs initialization...');

      final existing = await getVersionConfig();
      if (existing != null) {
        _logger.i('✓ Version config already exists on backend');
        return true;
      }

      // Create initial config with current app version
      final currentVersion = await getCurrentVersion();
      _logger.i(
        'Creating initial version config on backend with version: $currentVersion',
      );

      final config = VersionConfig(
        minimumVersion: currentVersion,
        latestVersion: currentVersion,
        updateMessage: 'A new version is available. Please update to continue.',
        changelog: 'Initial version',
        forceUpdate: false,
      );

      await ApiClient.instance.put('/admin/config/$_configKey', body: {'value': config.toMap()});

      _logger.i(
        '✓ Version config initialized on backend with current version: $currentVersion',
      );
      return true;
    } catch (e) {
      _logger.e('Error initializing version config: $e');
      return false;
    }
  }

  /// Update the latestVersion on the backend (call this when you release a
  /// new version). Updates without changing minimumVersion.
  /// Requires an admin-logged-in session.
  static Future<bool> updateLatestVersion({
    required String newVersion,
    String? changelogText,
    bool forceUpdate = false,
  }) async {
    try {
      _logger.i('Updating latest version to $newVersion (force=$forceUpdate)');

      final current = await getVersionConfig();
      final updated = VersionConfig(
        minimumVersion: current?.minimumVersion ?? newVersion,
        latestVersion: newVersion,
        updateMessage: current?.updateMessage,
        changelog: changelogText ?? current?.changelog,
        forceUpdate: forceUpdate,
      );

      await ApiClient.instance.put('/admin/config/$_configKey', body: {'value': updated.toMap()});

      _logger.i(
        '✓ Successfully updated latestVersion to $newVersion on backend',
      );
      return true;
    } catch (e) {
      _logger.e('Error updating latest version: $e');
      return false;
    }
  }

  /// Force update the minimum required version (use this for
  /// security/critical updates). Users with versions below this will be
  /// forced to update. Requires an admin-logged-in session.
  static Future<bool> setMinimumRequiredVersion({
    required String minVersion,
    String? updateMessage,
    String? changelogText,
  }) async {
    try {
      _logger.i('Setting minimum required version to $minVersion');

      final current = await getVersionConfig();
      final updated = VersionConfig(
        minimumVersion: minVersion,
        latestVersion: current?.latestVersion ?? minVersion,
        updateMessage: updateMessage ?? current?.updateMessage,
        changelog: changelogText ?? current?.changelog,
        forceUpdate: true,
      );

      await ApiClient.instance.put('/admin/config/$_configKey', body: {'value': updated.toMap()});

      _logger.i(
        '✓ Successfully set minimum required version to $minVersion on backend',
      );
      return true;
    } catch (e) {
      _logger.e('Error setting minimum required version: $e');
      return false;
    }
  }
}

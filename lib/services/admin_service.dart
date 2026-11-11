import 'dart:async';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:logger/logger.dart';

/// Talks to the self-hosted Node.js backend (see /backend/routes/admin.js)
/// instead of Firestore + Cloud Functions. Every method still returns the
/// same `Map<String, dynamic>` shape (`success`, `message`, etc.) the old
/// Firestore-based version did, so `admin_screen.dart` needed only small
/// changes.
///
/// Admin authorization is enforced by the backend itself (JWT + isAdmin
/// flag), so the `adminEmail` parameters below are kept only for logging /
/// call-site compatibility — the real check happens server-side.
class AdminService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  /// Checks if the currently logged-in user is an admin. The backend infers
  /// the identity from the JWT, so `adminEmail` is unused here but kept for
  /// compatibility with existing call sites.
  Future<bool> isAdmin(String adminEmail) async {
    try {
      final result = await _api.get('/admin/stats/users');
      return result['success'] == true;
    } on ApiException catch (e) {
      if (e.statusCode == 403) return false;
      _logger.e('Error checking admin status: $e');
      return false;
    } catch (e) {
      _logger.e('Error checking admin status: $e');
      return false;
    }
  }

  /// Gets comprehensive user statistics (admin only).
  Future<Map<String, dynamic>> getUserStatistics(String adminEmail) async {
    try {
      final result = await _api.get('/admin/stats/users');
      return {
        'success': true,
        'stats': result['stats'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get user statistics: $e');
      return {
        'success': false,
        'message': 'Failed to get user statistics: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Gets database statistics (admin only).
  Future<Map<String, dynamic>> getDatabaseStats(String adminEmail) async {
    try {
      final result = await _api.get('/admin/stats/database');
      return {
        'success': true,
        'stats': result['stats'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get database stats: $e');
      return {
        'success': false,
        'message': 'Failed to get database stats: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Cleans up archived games (admin only).
  Future<Map<String, dynamic>> cleanupArchivedGames(
    String adminEmail, {
    int daysToKeep = 30,
  }) async {
    try {
      final result = await _api.post('/admin/cleanup/archived-games');
      return {
        'success': true,
        'message': 'Cleanup completed successfully',
        'deletedCount': result['deletedCount'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Cleanup failed: $e');
      return {
        'success': false,
        'message': 'Cleanup failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Cleans up waiting games older than 5 minutes (admin only).
  Future<Map<String, dynamic>> cleanupWaitingGames(String adminEmail) async {
    try {
      final result = await _api.post('/admin/cleanup/waiting-games');
      return {
        'success': true,
        'message': 'Cleanup completed successfully',
        'deletedCount': result['deletedCount'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Cleanup failed: $e');
      return {
        'success': false,
        'message': 'Cleanup failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Verifies active games (admin only).
  Future<Map<String, dynamic>> verifyActiveGames(String adminEmail) async {
    try {
      final result = await _api.post('/admin/verify-active-games');
      return {
        'success': true,
        'count': result['count'],
        'games': result['games'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to verify active games: $e');
      return {
        'success': false,
        'message': 'Failed to verify active games: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Archives active games with no activity for 1+ hour (admin only).
  Future<Map<String, dynamic>> cleanupStaleActiveGames(
    String adminEmail, {
    int staleMinutes = 60,
  }) async {
    try {
      final result = await _api.post(
        '/admin/cleanup/stale-active-games',
        body: {'staleMinutes': staleMinutes},
      );
      return {
        'success': true,
        'message': 'Stale active games archived successfully',
        'archivedCount': result['modifiedCount'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to cleanup stale active games: $e');
      return {
        'success': false,
        'message': 'Failed to cleanup stale active games: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Gets per-game-mode settings (admin only).
  Future<Map<String, dynamic>> getGameModeSettings(String adminEmail) async {
    try {
      final result = await _api.get('/admin/game-mode-settings');
      return {
        'success': true,
        'settings': result['settings'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get game mode settings: $e');
      return {
        'success': false,
        'message': 'Failed to get game mode settings: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Updates per-game-mode settings (admin only).
  Future<Map<String, dynamic>> updateGameModeSettings(
    String adminEmail,
    Map<String, dynamic> settings,
  ) async {
    try {
      final result = await _api.put(
        '/admin/game-mode-settings',
        body: {'settings': settings},
      );
      return {
        'success': true,
        'settings': result['settings'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to update game mode settings: $e');
      return {
        'success': false,
        'message': 'Failed to update game mode settings: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Returns just the enabled game modes, derived from getGameModeSettings.
  Future<List<Map<String, dynamic>>> getEnabledGameModes() async {
    // Time control + title for the three built-in modes, keyed by the name the
    // admin panel stores them under.
    const defaults = {
      'classical': {'title': Constants.classical, 'timeControl': '60 sec/move'},
      'tempo': {'title': Constants.fast, 'timeControl': '30 sec/move'},
      'blitz': {'title': Constants.blitz3, 'timeControl': '3 min + 5s bonus 3s'},
    };
    try {
      // Public route: normal players are not admins, so /admin/... would refuse them.
      final result = await _api.get('/public/config/gameModeSettings', withAuth: false);
      final settings = Map<String, dynamic>.from(result['value'] ?? {});
      // Nothing saved yet by the admin => every mode is on.
      if (settings.isEmpty) {
        return defaults.entries
            .map((e) => <String, dynamic>{'mode': e.key, ...e.value})
            .toList();
      }
      return settings.entries
          .where((e) => (e.value is Map) && (e.value['enabled'] == true))
          .map((e) => <String, dynamic>{
                'mode': e.key,
                ...?defaults[e.key],
                ...Map<String, dynamic>.from(e.value),
              })
          .toList();
    } catch (e) {
      _logger.e('Failed to get enabled game modes: $e');
      return [];
    }
  }

  /// Gets global ads settings (admin only — for the admin panel toggle UI).
  Future<Map<String, dynamic>> getAdsSettings(String adminEmail) async {
    try {
      final result = await _api.get('/admin/ads-settings');
      final settings = Map<String, dynamic>.from(result['settings'] ?? {});
      return {
        'success': true,
        'bannerAdsEnabled': settings['bannerAdsEnabled'] ?? true,
        'interstitialAdsEnabled': settings['interstitialAdsEnabled'] ?? true,
        'appOpenAdsEnabled': settings['appOpenAdsEnabled'] ?? true,
        'nativeAdsEnabled': settings['nativeAdsEnabled'] ?? true,
        'enabled': settings.values.any((v) => v == true),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to get ads settings: $e');
      return {
        'success': false,
        'message': 'Failed to get ads settings: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Updates one ad type's enabled flag (admin only).
  Future<Map<String, dynamic>> updateAdsSettings(
    String adminEmail,
    String adType,
    bool enabled,
  ) async {
    if (!['banner', 'interstitial', 'appOpen', 'native'].contains(adType)) {
      throw Exception(
        'Invalid ad type. Must be one of: banner, interstitial, appOpen, native',
      );
    }
    try {
      // Read-modify-write, since the backend stores all ad types in one doc.
      final current = await _api.get('/admin/ads-settings');
      final settings = Map<String, dynamic>.from(current['settings'] ?? {});
      settings['${adType}AdsEnabled'] = enabled;

      final result = await _api.put('/admin/ads-settings', body: {'settings': settings});
      return {
        'success': true,
        'message': 'Ads settings updated successfully',
        'adType': adType,
        'enabled': enabled,
        'settings': result['settings'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to update ads settings: $e');
      return {
        'success': false,
        'message': 'Failed to update ads settings: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Current ad-frequency limits (admin only).
  Future<Map<String, dynamic>> getAdFrequency() async {
    try {
      final r = await _api.get('/admin/ads-settings');
      final s = Map<String, dynamic>.from(r['settings'] ?? {});
      return {
        'appOpenMaxPerDay': s['appOpenMaxPerDay'] ?? 3,
        'appOpenMinGapHours': s['appOpenMinGapHours'] ?? 4,
        'interstitialMaxPerHour': s['interstitialMaxPerHour'] ?? 3,
        'interstitialEveryNGameOvers': s['interstitialEveryNGameOvers'] ?? 2,
      };
    } catch (e) {
      _logger.e('Failed to get ad frequency: $e');
      return {
        'appOpenMaxPerDay': 3,
        'appOpenMinGapHours': 4,
        'interstitialMaxPerHour': 3,
        'interstitialEveryNGameOvers': 2,
      };
    }
  }

  /// Saves ad-frequency limits (0 = no limit). Admin only.
  Future<bool> updateAdFrequency({
    int? appOpenMaxPerDay,
    double? appOpenMinGapHours,
    int? interstitialMaxPerHour,
    int? interstitialEveryNGameOvers,
  }) async {
    try {
      final current = await _api.get('/admin/ads-settings');
      final s = Map<String, dynamic>.from(current['settings'] ?? {});
      if (appOpenMaxPerDay != null) s['appOpenMaxPerDay'] = appOpenMaxPerDay;
      if (appOpenMinGapHours != null) {
        s['appOpenMinGapHours'] = appOpenMinGapHours;
      }
      if (interstitialMaxPerHour != null) {
        s['interstitialMaxPerHour'] = interstitialMaxPerHour;
      }
      if (interstitialEveryNGameOvers != null) {
        s['interstitialEveryNGameOvers'] = interstitialEveryNGameOvers;
      }
      await _api.put('/admin/ads-settings', body: {'settings': s});
      return true;
    } catch (e) {
      _logger.e('Failed to update ad frequency: $e');
      return false;
    }
  }

  /// Triggers the server-side guest-cleanup job (admin only). Returns
  /// immediately — the job itself runs in the background on the VPS,
  /// safely paginated for any number of users. Poll/watch
  /// [getGuestCleanupStatus] / [watchGuestCleanupStatus] for progress.
  Future<Map<String, dynamic>> deleteInactiveGuestUsers(
    String adminEmail, {
    int inactiveDays = 15,
  }) async {
    try {
      final result = await _api.post(
        '/admin/guest-cleanup/trigger',
        body: {'inactiveDays': inactiveDays},
      );
      return {
        'success': true,
        'started': result['started'] ?? false,
        'message': result['message'] ?? 'Guest cleanup triggered.',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Failed to trigger guest cleanup: $e');
      return {
        'success': false,
        'message': 'Failed to trigger guest cleanup: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// One-off read of the current guest-cleanup job status/progress.
  Future<Map<String, dynamic>?> getGuestCleanupStatus() async {
    try {
      final result = await _api.get('/admin/guest-cleanup/status');
      return result['status'] as Map<String, dynamic>?;
    } catch (e) {
      _logger.e('Failed to get guest cleanup status: $e');
      return null;
    }
  }

  /// Polling-based "live" stream of guest-cleanup progress. There's no
  /// realtime push for this yet (that's Phase 2 / Socket.IO territory), so
  /// this polls the REST endpoint every 2 seconds — good enough for a
  /// progress dialog, and keeps `admin_screen.dart`'s StreamBuilder working
  /// unchanged.
  Stream<Map<String, dynamic>?> watchGuestCleanupStatus() async* {
    while (true) {
      yield await getGuestCleanupStatus();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Play-screen feature toggles (Play Online / Computer / Local
  /// Multiplayer buttons) — admin can show/hide each independently, and
  /// every player's app picks up the change live (polled every 3s) without
  /// needing to restart the app. Uses the same generic config storage as
  /// game-mode/ads/admob/etc settings.
  static const _playFeaturesKey = 'playFeatures';
  static const Map<String, bool> _playFeaturesDefaults = {
    'onlineEnabled': true,
    'cpuEnabled': true,
    'localMultiplayerEnabled': true,
  };

  Future<Map<String, bool>> getPlayFeatures() async {
    try {
      final result = await _api.get('/public/config/$_playFeaturesKey', withAuth: false);
      final value = Map<String, dynamic>.from(result['value'] ?? {});
      if (value.isEmpty) return _playFeaturesDefaults;
      return {
        for (final key in _playFeaturesDefaults.keys) key: value[key] ?? _playFeaturesDefaults[key]!,
      };
    } catch (e) {
      _logger.e('Error getting play features: $e');
      return _playFeaturesDefaults;
    }
  }

  /// Live-updating stream (polls every 3s) so toggling a feature in the
  /// admin panel shows up for players without them restarting the app.
  Stream<Map<String, bool>> watchPlayFeatures() async* {
    while (true) {
      yield await getPlayFeatures();
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Admin-only: update one or more play-screen feature toggles.
  Future<void> updatePlayFeatures(Map<String, bool> updates) async {
    final current = await getPlayFeatures();
    final merged = {...current, ...updates};
    await _api.put('/admin/config/$_playFeaturesKey', body: {'value': merged});
  }

  /// Voice-chat ad-gate toggle — independent of the general "Ads Enabled"
  /// switch. When true (default), non-premium users must watch an ad (or
  /// upgrade) to unlock in-game voice chat, same as before. When false,
  /// voice chat is free for everyone regardless of the global ads
  /// setting or any other ad type. Uses the same generic config storage
  /// as the play-features toggles above.
  static const _voiceChatFeatureKey = 'voiceChatFeature';

  Future<bool> getVoiceChatAdGateEnabled() async {
    try {
      final result = await _api.get('/public/config/$_voiceChatFeatureKey', withAuth: false);
      final value = Map<String, dynamic>.from(result['value'] ?? {});
      return value['adGateEnabled'] ?? true;
    } catch (e) {
      _logger.e('Error getting voice chat ad-gate setting: $e');
      return true;
    }
  }

  /// Live-updating stream (polls every 3s) so toggling this in the admin
  /// panel takes effect for players without an app restart.
  Stream<bool> watchVoiceChatAdGateEnabled() async* {
    while (true) {
      yield await getVoiceChatAdGateEnabled();
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Admin-only: turn the voice-chat ad-gate on/off.
  Future<void> updateVoiceChatAdGateEnabled(bool enabled) async {
    await _api.put('/admin/config/$_voiceChatFeatureKey', body: {
      'value': {'adGateEnabled': enabled},
    });
  }

  // ---------- Contact Us (WhatsApp on/off + support email) ----------
  // Stored in the generic admin config under "contactConfig"; readable by everyone.
  static const _contactConfigKey = 'contactConfig';

  Future<ContactConfig> getContactConfig() async {
    try {
      final result = await _api.get('/public/config/$_contactConfigKey', withAuth: false);
      return ContactConfig.fromJson(Map<String, dynamic>.from(result['value'] ?? {}));
    } catch (e) {
      _logger.e('Error getting contact config: $e');
      return const ContactConfig();
    }
  }

  /// Admin-only.
  Future<void> updateContactConfig(ContactConfig config) async {
    await _api.put('/admin/config/$_contactConfigKey', body: {'value': config.toJson()});
  }

  /// Used by regular users' screens to decide whether to show ads at all.
  static Future<bool> isAdTypeEnabled(String adType) async {
    try {
      final result = await ApiClient.instance.get(
        '/public/ads-settings',
        withAuth: false,
      );
      final fieldName = '${adType}AdsEnabled';
      return result[fieldName] ?? true;
    } catch (e) {
      Logger().e('Error checking if $adType ad is enabled: $e');
      return true; // Default to enabled on error
    }
  }

  static Future<bool> areBannerAdsEnabled() => isAdTypeEnabled('banner');
  static Future<bool> areInterstitialAdsEnabled() => isAdTypeEnabled('interstitial');
  static Future<bool> areAppOpenAdsEnabled() => isAdTypeEnabled('appOpen');
  static Future<bool> areNativeAdsEnabled() => isAdTypeEnabled('native');
}

/// Contact Us settings controlled from the admin panel.
///
/// Defaults are used until the admin saves something different, or when the server
/// cannot be reached: support e-mail + WhatsApp live chat both shown.
class ContactConfig {
  static const String defaultEmail = 'support@albonik.com';
  static const String defaultWhatsapp = '+15059103477';

  final bool whatsappEnabled; // show / hide the "Live chat" (WhatsApp) card
  final String whatsappNumber; // with country code
  final String email;

  const ContactConfig({
    this.whatsappEnabled = true,
    this.whatsappNumber = defaultWhatsapp,
    this.email = defaultEmail,
  });

  factory ContactConfig.fromJson(Map<String, dynamic> j) {
    final wa = (j['whatsappNumber'] ?? '').toString().trim();
    final mail = (j['email'] ?? '').toString().trim();
    return ContactConfig(
      // Missing key (never saved) = shown. An explicit false from the admin = hidden.
      whatsappEnabled: j.containsKey('whatsappEnabled')
          ? j['whatsappEnabled'] == true
          : true,
      whatsappNumber: wa.isEmpty ? defaultWhatsapp : wa,
      email: mail.isEmpty ? defaultEmail : mail,
    );
  }

  Map<String, dynamic> toJson() => {
        'whatsappEnabled': whatsappEnabled,
        'whatsappNumber': whatsappNumber,
        'email': email,
      };

  /// WhatsApp number reduced to digits only (what wa.me needs).
  String get whatsappDigits => whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
  bool get hasWhatsapp => whatsappEnabled && whatsappDigits.isNotEmpty;
  bool get hasEmail => email.isNotEmpty;
}

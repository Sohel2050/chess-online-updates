import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Anonymous usage statistics (v83), sent to OUR backend (POST /analytics/events), no third party.
///
/// - Only the event names / property keys the server allows are accepted (see backend/utils/analyticsEvents.js).
/// - No e-mail, name, chat or game content is ever sent; the server stores only the account id with the event.
/// - Events are queued, sent in small batches (every ~30 s, 10 events, or when the app goes to the background)
///   and kept until the user is signed in. Failures are ignored: analytics must never disturb the player.
/// - The player can switch it off (Privacy Settings). Off in debug builds, so test taps do not pollute the numbers.
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const String _prefKey = 'analytics_enabled';
  static const int _maxQueue = 100;
  static const int _batchSize = 25;

  bool _enabled = true;
  bool _initialized = false;
  bool _sending = false;
  String _appVersion = '';
  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;

  bool get enabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) {
      _queue.clear();
      _timer?.cancel();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// [props] values must be short plain text, numbers or booleans (the server drops anything else).
  void track(String name, [Map<String, Object>? props]) {
    if (!_enabled || kDebugMode) return;
    _queue.add({
      'name': name,
      if (props != null && props.isNotEmpty) 'props': props,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    if (_queue.length > _maxQueue) _queue.removeRange(0, _queue.length - _maxQueue);
    if (_queue.length >= 10) {
      unawaited(flush());
    } else {
      _timer ??= Timer(const Duration(seconds: 30), () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  /// One screen opened (short lower-case name, e.g. 'puzzles'). Only names, never content.
  void screen(String name) => track('screen_view', {'screen': name});

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_sending || !_enabled || _queue.isEmpty) return;
    _sending = true;
    try {
      // Not signed in yet: keep the events, the next flush will send them.
      final token = await ApiClient.instance.token;
      if (token == null || token.isEmpty) return;

      final batch = _queue.take(_batchSize).toList();
      try {
        await ApiClient.instance.post('/analytics/events', body: {
          'events': batch,
          'platform': _platform(),
          'appVersion': _appVersion,
        });
        _queue.removeRange(0, batch.length);
      } catch (e) {
        debugPrint('AnalyticsService: send failed (kept for later): $e');
      }
    } finally {
      _sending = false;
    }
    // More than one batch waiting: send the rest on the next timer tick.
    if (_queue.isNotEmpty) {
      _timer ??= Timer(const Duration(seconds: 30), () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  String _platform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(flush());
  }
}

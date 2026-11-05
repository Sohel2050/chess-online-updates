import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting (Firebase Crashlytics).
///
/// - Quietly does nothing until Firebase is configured (`android/app/google-services.json`),
///   exactly like [PushService]. The app never fails because of reporting.
/// - Off in debug builds (so your own test crashes do not fill the dashboard).
/// - Reports only the technical error + stack trace, an app-side random id from Firebase,
///   and the account id (a database id, no e-mail or name). Mention this in the privacy policy
///   and in the Play Console "Data safety" form (see CHANGES_v80.md).
///
/// Every method is safe to call at any time, from anywhere, without awaiting.
class CrashReporter {
  CrashReporter._();

  static bool _ready = false;
  static bool get isReady => _ready;

  /// Call once from main(), right after `WidgetsFlutterBinding.ensureInitialized()`.
  /// Replaces the default handlers for Flutter errors and uncaught platform errors.
  static Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      _ready = true;
    } catch (e) {
      debugPrint('Crash reporting disabled (Firebase not configured): $e');
      _ready = false;
    }
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      if (_ready) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Unhandled platform error: $error');
      _record(error, stack, fatal: true, reason: 'platform error');
      return true; // handled: the app keeps running
    };
  }

  /// For `runZonedGuarded`'s error callback (uncaught async errors).
  static void recordZoneError(Object error, StackTrace stack) {
    debugPrint('Unhandled async error: $error');
    _record(error, stack, fatal: true, reason: 'uncaught async error');
  }

  /// A handled problem worth knowing about (shows as a non-fatal issue). Use in `catch` blocks
  /// where the app recovers but you still want to see how often it happens.
  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    _record(error, stack, fatal: false, reason: reason);
  }

  /// A short breadcrumb that is attached to the next crash report ("opened review", "socket reconnect").
  static void log(String message) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// Ties reports to the signed-in account (database id only). Pass '' on sign-out.
  static void setUserId(String? id) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(id ?? '');
    } catch (_) {}
  }

  /// Extra searchable detail on reports, e.g. setKey('screen', 'game').
  static void setKey(String key, Object value) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (_) {}
  }

  static void _record(Object error, StackTrace? stack, {required bool fatal, String? reason}) {
    if (!_ready) return;
    try {
      unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal, reason: reason));
    } catch (_) {}
  }
}

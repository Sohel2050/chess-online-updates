import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_chess_app/screens/club_screen.dart';
import 'package:flutter_chess_app/screens/daily_game_screen.dart';
import 'package:flutter_chess_app/screens/messages_screen.dart';
import 'package:flutter_chess_app/screens/tournament_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/message_service.dart';
import 'package:flutter_chess_app/services/offline_service.dart';

/// Push notifications for admin messages (Firebase Cloud Messaging).
///
/// Firebase is used ONLY to deliver notifications; all data stays on your own
/// backend. If `android/app/google-services.json` is missing, [init] fails
/// quietly and the app works exactly as before (messages still show up in
/// Settings -> Messages).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Set from main.dart, used to open a message when a notification is tapped.
  static GlobalKey<NavigatorState>? navigatorKey;

  static const String _channelId = 'admin_messages';
  static const String _dailyChannelId = 'daily_reminders';
  // Payload used for local notifications of the daily reminder (a message id otherwise).
  static const String _dailyPayload = 'daily';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;
  bool _available = false;
  String? _registeredToken;
  String? _pendingMessageId; // notification tapped before the UI was ready (message id or [_dailyPayload])

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('Push disabled (Firebase not configured): $e');
      return;
    }
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is asked through Firebase in registerForCurrentUser().
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _openMessage(response.payload),
      );
      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Messages',
          description: 'Messages from the Chess team',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _dailyChannelId,
          'Daily reminders',
          description: 'Daily puzzle and streak reminders',
          importance: Importance.defaultImportance,
        ),
      );

      // iOS shows the banner itself, even while the app is open.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // Android, app open: FCM does not show anything itself, so show it ourselves.
      FirebaseMessaging.onMessage.listen(_showForeground);
      // App in background, notification tapped.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _openMessage(_payloadOf(m)),
      );
      // App was closed, notification tapped.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingMessageId = _payloadOf(initial);
      // FCM can rotate the token at any time.
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToServer);
    } catch (e) {
      debugPrint('Push listeners setup failed: $e');
    }
  }

  /// Call once the user is logged in (home screen). Asks for the notification
  /// permission (Android 13+), sends this phone's token to the server and
  /// opens a message if the app was started from a notification.
  Future<void> registerForCurrentUser() async {
    await init();
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iPhone the FCM token only exists once Apple has handed out its own (APNs) token.
        for (var i = 0; i < 10; i++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
    final pending = _pendingMessageId;
    if (pending != null) {
      _pendingMessageId = null;
      _openMessage(pending);
    }
  }

  /// Call BEFORE the login token is cleared, so this phone stops getting
  /// the previous user's notifications.
  Future<void> unregister() async {
    if (!_available) return;
    try {
      final token = _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient.instance.post('/messages/device-token/remove', body: {'token': token});
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
    _registeredToken = null;
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient.instance.post(
        '/messages/device-token',
        body: {
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
          // Lets the server send the daily reminder in the user's local evening.
          'tz': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      _registeredToken = token;
    } catch (e) {
      // Not logged in yet / offline: registerForCurrentUser() runs again next launch.
      debugPrint('Could not send push token: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return; // iOS already showed it
    final n = message.notification;
    if (n == null) return;
    final isDaily = message.data['type'] == 'daily_reminder';
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: isDaily
            ? const AndroidNotificationDetails(
                _dailyChannelId,
                'Daily reminders',
                channelDescription: 'Daily puzzle and streak reminders',
              )
            : const AndroidNotificationDetails(
                _channelId,
                'Messages',
                channelDescription: 'Messages from the Chess team',
                importance: Importance.high,
                priority: Priority.high,
              ),
      ),
      payload: _payloadOf(message),
    );
  }

  /// What a tapped notification opens. Admin messages carry a message id (plain payload); the others are
  /// "<kind>:<id>" (tournament, daily game, club). Daily reminders only bring the user back to the home screen.
  String? _payloadOf(RemoteMessage m) {
    final d = m.data;
    switch (d['type']) {
      case 'daily_reminder':
        return _dailyPayload;
      case 'tournament':
        return d['tournamentId'] == null ? null : 'tournament:${d['tournamentId']}';
      case 'daily_game':
        return d['gameId'] == null ? null : 'daily_game:${d['gameId']}';
      case 'club':
        return d['clubId'] == null ? null : 'club:${d['clubId']}';
      default:
        return d['messageId']?.toString();
    }
  }

  /// Opens a tournament / daily game / club from a tapped notification. Needs the signed-in user for the screen.
  Future<void> _openTarget(NavigatorState nav, String kind, String id) async {
    nav.popUntil((route) => route.isFirst);
    if (kind == 'daily_game') {
      nav.push(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: id)));
      return;
    }
    final user = await OfflineService().getCachedUser();
    if (user == null) return; // not signed in: stay on the home screen
    nav.push(MaterialPageRoute(
      builder: (_) => kind == 'tournament' ? TournamentScreen(tournamentId: id, user: user) : ClubScreen(clubId: id, user: user),
    ));
  }

  void _openMessage(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pendingMessageId = messageId;
      return;
    }
    final colon = messageId.indexOf(':');
    if (colon > 0) {
      final kind = messageId.substring(0, colon);
      if (kind == 'tournament' || kind == 'daily_game' || kind == 'club') {
        unawaited(_openTarget(nav, kind, messageId.substring(colon + 1)));
        return;
      }
    }
    if (messageId == _dailyPayload) {
      // Home shows the streak pill and the daily puzzle card.
      nav.popUntil((route) => route.isFirst);
      return;
    }
    // Tapping the notification counts as a click, same as tapping it in the list.
    unawaited(MessageService().trackClick(messageId));
    nav.push(
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(messageId: messageId, title: ''),
      ),
    );
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/screens/import_pgn_screen.dart';
import 'package:flutter_chess_app/screens/spectator_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/offline_service.dart';
import 'package:flutter_chess_app/utils/share_link.dart';

/// Opens a shared game link (https://<host>/g/<code>) tapped in a browser, chat or mail:
/// the import screen opens and imports the game at once. Waits (up to ~20 s) until the app has a
/// navigator and a signed-in (or guest) user, so a link that cold-starts the app is not lost.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<Uri>? _sub;
  String? _lastOpened;
  DateTime? _lastOpenedAt;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_sub != null) return;
    _navigatorKey = navigatorKey;
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink(); // the link that started the app, if any
      if (initial != null) unawaited(_handle(initial));
      _sub = links.uriLinkStream.listen((uri) => unawaited(_handle(uri)), onError: (Object e) => debugPrint('DeepLink: $e'));
    } catch (e) {
      debugPrint('DeepLink init failed: $e'); // links just do not open the app; nothing else breaks
    }
  }

  /// https://<host>/live/<code>: opens the live (spectator) screen of that game.
  Future<void> _handleLive(String code) async {
    final now = DateTime.now();
    if (_lastOpened == 'live:$code' && _lastOpenedAt != null && now.difference(_lastOpenedAt!) < const Duration(seconds: 5)) return;
    _lastOpened = 'live:$code';
    _lastOpenedAt = now;
    for (var i = 0; i < 40; i++) {
      final nav = _navigatorKey?.currentState;
      final user = nav == null ? null : await OfflineService().getCachedUser();
      if (nav != null && user != null) {
        // The link carries a short code; ask the server which game it is.
        // If the server does not know the lookup, the code is used as the game id.
        var gameId = code;
        try {
          final r = await ApiClient.instance.get('/games/live/$code');
          final id = r['gameId']?.toString();
          if (id != null && id.isNotEmpty) gameId = id;
        } catch (_) {}
        nav.push(MaterialPageRoute(builder: (_) => SpectatorScreen(gameId: gameId)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _handle(Uri uri) async {
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs.first == 'live' && segs[1].isNotEmpty) {
      return _handleLive(segs[1]);
    }
    final text = uri.toString();
    final code = ShareLink.extractCode(text);
    if (code == null) return;
    // The same link can be delivered twice (initial link + stream): open it once.
    final now = DateTime.now();
    if (_lastOpened == code && _lastOpenedAt != null && now.difference(_lastOpenedAt!) < const Duration(seconds: 5)) return;
    _lastOpened = code;
    _lastOpenedAt = now;
    for (var i = 0; i < 40; i++) {
      final nav = _navigatorKey?.currentState;
      final user = nav == null ? null : await OfflineService().getCachedUser();
      if (nav != null && user != null) {
        nav.push(MaterialPageRoute(builder: (_) => ImportPgnScreen(initialText: text, autoImport: true)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

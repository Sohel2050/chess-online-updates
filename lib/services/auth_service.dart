import 'dart:async';
import 'dart:io' show SocketException;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chess_app/services/analytics_service.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/services/push_service.dart';
import 'package:flutter_chess_app/services/offline_service.dart';
import 'package:flutter_chess_app/services/sign_in_results.dart';
import 'package:logger/logger.dart';

/// Replaces FirebaseAuth-based sign-in/sign-up (previously in
/// `UserService`) with calls to the self-hosted backend's `/auth` routes.
///
/// Kept as a separate, small class so `login_screen.dart` and
/// `sign_up_screen.dart` only need their service swapped for auth calls —
/// the rest of `UserService` (profile storage, ratings, offline sync, etc.)
/// is untouched here and can be migrated separately.
class AuthService {
  final ApiClient _api = ApiClient.instance;
  final Logger _logger = Logger();

  ChessUser _userFromJson(Map<String, dynamic> json) {
    return ChessUser(
      uid: json['_id']?.toString(),
      email: json['email'],
      displayName: json['displayName'] ?? 'Player',
      photoUrl: json['photoUrl'],
      classicalRating: json['classicalRating'] ?? 1200,
      blitzRating: json['blitzRating'] ?? 1200,
      tempoRating: json['tempoRating'] ?? 1200,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      gamesWon: json['gamesWon'] ?? 0,
      gamesLost: json['gamesLost'] ?? 0,
      gamesDraw: json['gamesDraw'] ?? 0,
      achievements: List<String>.from(json['achievements'] ?? const []),
      friends: List<String>.from(json['friends'] ?? const []),
      friendRequestsSent: List<String>.from(json['friendRequestsSent'] ?? const []),
      friendRequestsReceived: List<String>.from(json['friendRequestsReceived'] ?? const []),
      blockedUsers: List<String>.from(json['blockedUsers'] ?? const []),
      isOnline: json['isOnline'] ?? false,
      isGuest: json['isGuest'] ?? false,
      fcmToken: json['fcmToken'] ?? '',
      countryCode: json['countryCode'],
      removeAds: json['removeAds'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
    );
  }

  /// Fires when the default avatar of a brand-new account has finished uploading
  /// in the background (uid, photoUrl). main.dart listens and refreshes the UI.
  static final StreamController<MapEntry<String, String>> _avatarReady =
      StreamController<MapEntry<String, String>>.broadcast();
  static Stream<MapEntry<String, String>> get avatarReady => _avatarReady.stream;

  /// Gives a BRAND-NEW account the default avatar, IN THE BACKGROUND.
  /// Before, guest creation / sign up WAITED for this image upload (up to 60 s on a
  /// slow network), so the app looked stuck on open, login and sign up. Now the
  /// user is returned at once and the photo appears when the upload finishes.
  /// Only runs when the account has no photo at all, so existing photos are never touched.
  void _setDefaultAvatarInBackground(ChessUser user, String token) {
    final photo = user.photoUrl;
    if (photo != null && photo.isNotEmpty) return;
    final uid = user.uid;
    unawaited(() async {
      try {
        // The server refuses asset paths in photoUrl: upload the default avatar as a photo.
        final data = await rootBundle.load(AssetsManager.defaultAvatar);
        final result = await _api.uploadFile(
          '/users/me/profile-image',
          field: 'image',
          bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          filename: 'avatar.jpg',
          authToken: token, // sign up logs out right after: keep using THIS account's token
        );
        final url = result['photoUrl'] as String?;
        if (url != null && uid != null) _avatarReady.add(MapEntry(uid, url));
      } catch (e) {
        _logger.w('Could not save default avatar: $e');
      }
    }());
  }

  /// Same validation the old UserService exposed, kept so screens that
  /// call `_userService.isValidEmail(...)` in their form validators keep
  /// working unchanged.
  String? isValidEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    // Lenient on purpose: rejecting real addresses ("+tags", long TLDs like
    // .store/.online) is worse than letting a typo through to the server check.
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? isValidName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 3) return 'Name must be at least 3 characters';
    return null;
  }

  /// Plain-words reason for a failed request (instead of a vague "Something went wrong").
  String _networkMessage(Object e) {
    if (e is TimeoutException) {
      return 'The server took too long to respond. Please check your internet and try again.';
    }
    if (e is SocketException || e.runtimeType.toString() == 'ClientException') {
      return 'Cannot reach the server. Please check your internet connection and try again.';
    }
    return 'Something went wrong (${e.runtimeType}). Please try again.';
  }

  /// POST /auth/login — replaces FirebaseAuth.signInWithEmailAndPassword.
  Future<SignInResult> signIn(String email, String password) async {
    try {
      final response = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        withAuth: false,
      );
      final token = response['token'] as String;
      await _api.setToken(token);
      final user = _userFromJson(Map<String, dynamic>.from(response['user']));
      await OfflineService().cacheUser(user); // lets the app open while the server is down
      return SignInSuccess(user);
    } on ApiException catch (e) {
      return SignInError(e.message);
    } catch (e) {
      _logger.e('signIn failed: $e');
      return SignInError(_networkMessage(e));
    }
  }

  /// GET /auth/detect-country — country guessed from the caller's IP by our own
  /// server (offline database, nothing sent to third parties). Null if unknown.
  Future<String?> detectCountry() async {
    try {
      final r = await _api.get('/auth/detect-country', withAuth: false);
      final code = r['countryCode']?.toString();
      return (code != null && RegExp(r'^[A-Za-z]{2}$').hasMatch(code))
          ? code.toUpperCase()
          : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /auth/signup — replaces FirebaseAuth.createUserWithEmailAndPassword.
  Future<SignInResult> signUp(
    String email,
    String password,
    String displayName, [
    String? countryCode,
  ]) async {
    try {
      final response = await _api.post(
        '/auth/signup',
        body: {
          'email': email.trim(),
          'password': password,
          'displayName': displayName.trim(),
          if (countryCode != null) 'countryCode': countryCode,
        },
        // Sends the current session (if any): when the user is a guest, the
        // server upgrades THAT account, so its rating, stats and premium survive.
        withAuth: true,
      );
      final token = response['token'] as String;
      await _api.setToken(token);
      // A guest being upgraded keeps its own photo (the server upgrades the same
      // account); only a brand-new account without a photo gets the default.
      final user = _userFromJson(Map<String, dynamic>.from(response['user']));
      _setDefaultAvatarInBackground(user, token);
      await OfflineService().cacheUser(user);
      AnalyticsService.instance.track('signup', {'method': 'email'});
      return SignInSuccess(user);
    } on ApiException catch (e) {
      return SignInError(e.message);
    } catch (e) {
      _logger.e('signUp failed: $e');
      return SignInError(_networkMessage(e));
    }
  }

  /// POST /auth/guest — replaces FirebaseAuth.signInAnonymously.
  Future<ChessUser> signInAnonymously() async {
    final response = await _api.post('/auth/guest', withAuth: false);
    final token = response['token'] as String;
    await _api.setToken(token);
    final user = _userFromJson(Map<String, dynamic>.from(response['user']));
    _setDefaultAvatarInBackground(user, token);
    await OfflineService().cacheUser(user);
    return user;
  }

  /// Restores a session from a locally stored JWT (app startup) —
  /// replaces the old `FirebaseAuth.instance.authStateChanges()` bootstrap.
  /// Returns null if there's no token, or it's expired/invalid (in which
  /// case the stale token is cleared so the app falls through to
  /// guest/login as if never signed in).
  Future<ChessUser?> restoreSession() async {
    final token = await _api.token;
    if (token == null) return null;
    try {
      final response = await _api.get('/auth/me');
      final user = _userFromJson(Map<String, dynamic>.from(response['user']));
      await OfflineService().cacheUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _api.clearToken();
        await OfflineService().clearUserCache();
        return null;
      }
      // Server error (VPS off / restarting): the token is still valid. Use the saved copy of
      // the user. NEVER return null here: that made the app create a brand-new guest and
      // overwrite the saved login, which looked like "logged out".
      _logger.w('restoreSession: server error ${e.statusCode}, using cached user');
      final cached = await OfflineService().getCachedUser();
      if (cached != null) return cached;
      throw SessionUnavailableException();
    } catch (e) {
      _logger.e('restoreSession failed (network?): $e');
      final cached = await OfflineService().getCachedUser();
      if (cached != null) return cached;
      throw SessionUnavailableException();
    }
  }

  Future<void> signOut() async {
    await OfflineService().clearUserCache();
    // Needs the login token, so it must run before clearToken().
    await PushService.instance.unregister();
    await _api.clearToken();
  }
}

/// The saved login is still valid but the server cannot be reached and there is no saved copy
/// of the user yet. The app shows a retry screen instead of creating a new guest account.
class SessionUnavailableException implements Exception {
  @override
  String toString() => 'Server not reachable';
}

import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
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

  /// Same validation the old UserService exposed, kept so screens that
  /// call `_userService.isValidEmail(...)` in their form validators keep
  /// working unchanged.
  String? isValidEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? isValidName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name is too short';
    return null;
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
      return SignInSuccess(user);
    } on ApiException catch (e) {
      return SignInError(e.message);
    } catch (e) {
      _logger.e('signIn failed: $e');
      return SignInError('Something went wrong. Please try again.');
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
        withAuth: false,
      );
      final token = response['token'] as String;
      await _api.setToken(token);
      final user = _userFromJson(Map<String, dynamic>.from(response['user']));
      return SignInSuccess(user);
    } on ApiException catch (e) {
      return SignInError(e.message);
    } catch (e) {
      _logger.e('signUp failed: $e');
      return SignInError('Something went wrong. Please try again.');
    }
  }

  /// POST /auth/guest — replaces FirebaseAuth.signInAnonymously.
  Future<ChessUser> signInAnonymously() async {
    final response = await _api.post('/auth/guest', withAuth: false);
    final token = response['token'] as String;
    await _api.setToken(token);
    return _userFromJson(Map<String, dynamic>.from(response['user']));
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
      return _userFromJson(Map<String, dynamic>.from(response['user']));
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _api.clearToken();
      return null;
    } catch (e) {
      _logger.e('restoreSession failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _api.clearToken();
  }
}

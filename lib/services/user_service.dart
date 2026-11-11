import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/services/puzzle_service.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/offline_service.dart';
import '../providers/user_provider.dart';

class UserService {
  final Logger logger = Logger();
  final OfflineService _offlineService = OfflineService();

  /// Country code (e.g. 'BD', 'GB', 'IN') taken from the phone's region setting,
  /// or 'US' if the phone doesn't have one.
  ///
  /// This used to call ipify + ip-api.com over plain HTTP. Android release
  /// builds block plain HTTP, so every user ended up as 'US', and the user's IP
  /// address was being sent to two third parties. The device region needs no
  /// network and shares nothing.
  Future<String> getCountryCodeFromIP() async {
    final dispatcher = PlatformDispatcher.instance;
    for (final locale in [dispatcher.locale, ...dispatcher.locales]) {
      final code = locale.countryCode;
      if (code != null && RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
        return code.toUpperCase();
      }
    }
    return 'US';
  }

  /// Live counters of the Play screen (online / waiting / games). The server pushes them over the game
  /// socket about 2 s after any change; a normal request fetches the first numbers and acts as a safety
  /// net (every 5 s while the socket is down or silent for 30 s).
  Stream<Map<String, int>> getGameStatsStream({String? gameMode}) {
    final socketService = GameSocketService.instance;
    late final StreamController<Map<String, int>> controller;
    Timer? fallbackTimer;
    StreamSubscription<Map<String, dynamic>>? pushSub;
    var lastData = DateTime.fromMillisecondsSinceEpoch(0);
    var gotData = false;
    final wanted = gameMode ?? '';

    Map<String, int> parse(Map<dynamic, dynamic> r) {
      int n(dynamic v) => v is num ? v.toInt() : 0;
      return {
        'online': n(r['online']),
        'waiting': n(r['waiting']),
        'playing': n(r['playing']),
        // Number of running games (older servers only send `playing` = players).
        'games': r['games'] is num ? n(r['games']) : n(r['playing']) ~/ 2,
      };
    }

    void emit(Map<String, int> m) {
      gotData = true;
      lastData = DateTime.now();
      if (!controller.isClosed) controller.add(m);
    }

    Future<void> fetchOnce() async {
      try {
        final result = await ApiClient.instance.get(
          '/users/stats/live',
          query: gameMode != null ? {'gameMode': gameMode} : null,
        );
        emit(parse(result));
      } catch (e) {
        logger.e('Error in game stats stream: $e');
        if (!gotData && !controller.isClosed) controller.add({'online': 0, 'waiting': 0, 'playing': 0, 'games': 0});
      }
    }

    controller = StreamController<Map<String, int>>.broadcast(
      onListen: () {
        // 1. The server pushes the numbers by socket (about 2 s after any change, and at once on subscribe).
        pushSub = socketService.onLiveStats.listen((e) {
          if ((e['gameMode']?.toString() ?? '') == wanted) emit(parse(e));
        });
        socketService.subscribeLiveStats(gameMode);
        // 2. A normal request for the first numbers (also if the socket is not up yet).
        fetchOnce();
        // 3. Safety net: ask normally if the socket is down or has been silent for a while.
        fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!socketService.isConnected || DateTime.now().difference(lastData) > const Duration(seconds: 30)) {
            fetchOnce();
          }
        });
      },
      onCancel: () {
        fallbackTimer?.cancel();
        pushSub?.cancel();
        socketService.unsubscribeLiveStats(gameMode);
      },
    );
    return controller.stream;
  }

  /// Polls just the online count (used by a couple of simpler UI spots
  /// that only need this one number) — same 4s cadence as
  /// [getGameStatsStream].
  Stream<int> getOnlinePlayersCountStream() async* {
    await for (final stats in getGameStatsStream()) {
      yield stats['online'] ?? 0;
    }
  }

  // Update user status to online/offline. `uid` is kept for call-site
  // compatibility — the backend always updates the logged-in user
  // (identified via JWT), not an arbitrary ID.
  Future<void> updateUserStatusOnline(String uid, bool isOnline) async {
    try {
      await ApiClient.instance.put('/users/me/online-status', body: {'isOnline': isOnline});
      logger.i('User $uid status updated to ${isOnline ? "online" : "offline"}');
    } catch (e) {
      logger.e('Error updating user status for $uid: $e');
      // Don't throw error to prevent app crashes - this is a background operation
      if (!isOnline) {
        _scheduleOfflineStatusRetry(uid);
      }
    }
  }

  // Schedule a retry for offline status update
  void _scheduleOfflineStatusRetry(String uid) {
    // Retry after a delay - this will help when network comes back
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        await ApiClient.instance.put('/users/me/online-status', body: {'isOnline': false});
        logger.i('Retry successful: User $uid set to offline');
      } catch (e) {
        logger.w('Retry failed for setting user $uid offline: $e');
        // If retry fails, we'll rely on server-side cleanup or next app launch
      }
    });
  }

  /// Clean up stale online status on app startup
  /// This helps ensure accurate online counts by setting the current user online
  Future<void> cleanupOnlineStatus(String uid) async {
    try {
      await updateUserStatusOnline(uid, true);
      logger.i('Online status cleanup completed for user $uid');
    } catch (e) {
      logger.e('Error during online status cleanup for $uid: $e');
    }
  }

  /// Force set user offline with multiple retry attempts
  /// This is useful when the app is being terminated or when we really need
  /// to ensure the user is marked offline
  Future<void> forceSetUserOffline(String uid) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await ApiClient.instance.put('/users/me/online-status', body: {'isOnline': false});
        logger.i('Force offline successful for user $uid on attempt $attempt');
        return; // Success, exit the retry loop
      } catch (e) {
        if (attempt == maxRetries) {
          logger.e('Force offline failed for user $uid after $maxRetries attempts: $e');
          return; // Last attempt failed, but don't throw to avoid crashes
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> signOut() async {
    try {
      await ApiClient.instance.clearToken();
      await _offlineService.clearUserCache();
    } catch (e) {
      throw Exception('An unknown error occurred during sign out.');
    }
  }

  /// STUB on the backend side (no email provider wired up yet — see
  /// backend/README.md). Still safe to call; it just won't actually
  /// deliver an email until that's set up.
  Future<void> resendEmailVerification() async {
    try {
      await ApiClient.instance.post('/auth/resend-verification');
    } catch (e) {
      throw Exception(
        'An unknown error occurred while resending verification email.',
      );
    }
  }

  Future<bool> emailExists(String email) async {
    try {
      final result = await ApiClient.instance.get(
        '/auth/email-exists',
        query: {'email': email},
        withAuth: false,
      );
      return result['exists'] == true;
    } catch (e) {
      logger.e('Error checking if email exists: $e');
      return false;
    }
  }

  /// STUB on the backend side (no email provider wired up yet — see
  /// backend/README.md). Still safe to call; it just won't actually
  /// deliver a reset email until that's set up.
  Future<void> resetPassword(String email) async {
    try {
      await ApiClient.instance.post(
        '/auth/reset-password',
        body: {'email': email},
        withAuth: false,
      );
    } catch (e) {
      throw Exception('An unknown error occurred during password reset.');
    }
  }

  /// Shrinks the picture to a JPEG before upload. Works for any source format
  /// (JPG, PNG, WEBP, HEIC...). The old version looked for ".jp" in the file name
  /// and crashed for every picture that wasn't a .jpg/.jpeg.
  Future<File> _compressImage(File file) async {
    final outPath =
        '${Directory.systemTemp.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      // If compression isn't possible, upload the original; the server resizes it anyway.
      return result != null ? File(result.path) : file;
    } catch (e) {
      logger.w('Image compression failed, uploading the original: $e');
      return file;
    }
  }

  /// Uploads a profile image to the backend (`POST /users/me/profile-image`,
  /// multipart/form-data), which compresses/resizes it server-side with
  /// sharp and returns the new public URL. Client-side compression still
  /// happens first too, purely to keep the upload small over slow
  /// connections — the server-side pass is the one that actually matters
  /// for consistent output quality.
  /// `userId` is kept for call-site compatibility — the backend always
  /// updates the logged-in user (identified via JWT).
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final compressedImage = await _compressImage(imageFile);
      final bytes = await compressedImage.readAsBytes();
      final result = await ApiClient.instance.uploadFile(
        '/users/me/profile-image',
        field: 'image',
        bytes: bytes,
        filename: '$userId.jpg',
      );
      return result['photoUrl'] as String;
    } catch (e) {
      logger.e('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image.');
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      await ApiClient.instance.delete('/users/me/profile-image');
    } catch (e) {
      logger.e('Error deleting profile image: $e');
      throw Exception('Failed to delete profile image.');
    }
  }

  /// The server only accepts a profile picture through the photo upload (it
  /// answers "Use the photo upload to change your picture" to an asset path),
  /// so a built-in avatar is uploaded like a normal photo. Returns the new
  /// photoUrl.
  Future<String> uploadAvatarAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final result = await ApiClient.instance.uploadFile(
        '/users/me/profile-image',
        field: 'image',
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        filename: 'avatar.jpg',
      );
      return result['photoUrl'] as String;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not upload the avatar. Check your connection and try again.');
    }
  }

  /// Saves ONLY the photo / avatar. The name and country are not sent, so a
  /// guest (whose generated name may not pass the name check) can still save
  /// an avatar. Throws the server's real message on failure.
  Future<void> updatePhotoUrl(String photoUrl) async {
    try {
      await ApiClient.instance.put('/users/me', body: {'photoUrl': photoUrl});
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not reach the server. Check your connection and try again.');
    }
  }

  Future<void> updateUser(ChessUser user) async {
    bool isValid = isValidName(user.displayName);
    if (!isValid) {
      throw ArgumentError('Invalid user name: ${user.displayName}');
    }
    try {
      await ApiClient.instance.put('/users/me', body: {
        'displayName': user.displayName,
        if (user.photoUrl != null) 'photoUrl': user.photoUrl,
        if (user.countryCode != null) 'countryCode': user.countryCode,
      });
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unknown error occurred while updating user data.');
    }
  }

  /// Update user's removeAds status (for in-app purchases)
  Future<void> updateRemoveAds(String userId, bool removeAds) async {
    // This is now a legacy method, delegate to updatePremiumStatus
    await updatePremiumStatus(userId, removeAds);
  }

  /// Update user's premium status (for in-app purchases)
  /// `userId` is kept for call-site compatibility — the backend always
  /// updates the logged-in user (identified via JWT), not an arbitrary ID.
  Future<void> updatePremiumStatus(
    String userId,
    bool isPremium, {
    DateTime? premiumStartDate,
    DateTime? premiumExpiryDate,
    String? productId,
    String? purchaseToken,
  }) async {
    try {
      await ApiClient.instance.put('/users/me/premium', body: {
        'isPremium': isPremium,
        if (premiumStartDate != null) 'premiumStartDate': premiumStartDate.toIso8601String(),
        if (premiumExpiryDate != null) 'premiumExpiryDate': premiumExpiryDate.toIso8601String(),
        // The server checks these with Google Play before granting premium.
        if (productId != null) 'productId': productId,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
      });
      logger.i('Updated premium status for user $userId to $isPremium');
    } on ApiException {
      rethrow; // callers need the status code (e.g. 400 = purchase already expired)
    } catch (e) {
      logger.e('Error updating premium status: $e');
      throw Exception('Failed to update premium status.');
    }
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      // Deletes the profile image, the user document, and (server-side)
      // any associated auth — all handled by the one backend call now,
      // instead of three separate Storage/Firestore/Auth calls.
      await deleteProfileImage(uid);
      await ApiClient.instance.delete('/users/me');
      await ApiClient.instance.clearToken();
    } catch (e) {
      throw Exception('An unknown error occurred during account deletion.');
    }
  }

  bool isValidName(String name) {
    if (name.isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    if (name.length < 3) {
      throw ArgumentError('Name must be at least 3 characters long');
    }
    if (name.length > 30) {
      throw ArgumentError('Name cannot exceed 30 characters');
    }
    // Name can only contain letters, numbers and spaces
    // Letters of ANY language (incl. combining marks like Bengali vowel signs).
    if (!RegExp(r'^[\p{L}\p{M}\p{N}\s]+$', unicode: true).hasMatch(name)) {
      throw ArgumentError('Name can only contain letters, numbers and spaces');
    }

    return true;
  }

  Future<ChessUser?> getUserById(String userId) async {
    try {
      final result = await ApiClient.instance.get('/users/$userId');
      final json = Map<String, dynamic>.from(result['user']);
      json['uid'] = json['_id']?.toString() ?? userId; // Mongo's `_id` -> ChessUser's `uid`
      return ChessUser.fromMap(json);
    } catch (e) {
      logger.e('Error getting user by ID: $e');
    }
    return null;
  }

  /// Updates user statistics after a game concludes. All the Elo/rating
  /// math now happens atomically on the backend (`POST /users/game-result`)
  /// in one MongoDB transaction, instead of a client-side Firestore
  /// transaction — see that endpoint for the ported rating logic.
  Future<void> updateUserStatsAfterGame({
    required String userId,
    required String gameResult,
    required String gameMode,
    required String gameId,
    String? opponentId,
  }) async {
    try {
      final result = await ApiClient.instance.post('/users/game-result', body: {
        'gameResult': gameResult,
        'gameMode': gameMode,
        'gameId': gameId,
        'date': PuzzleService.localDateKey(), // the user's own calendar day (streak / missions)
        if (opponentId != null && opponentId.isNotEmpty) 'opponentId': opponentId,
      });

      final ratingTypeField =
          Constants.gameModeToRatingType[gameMode] ?? Constants.classicalRating;
      final newRating = result['newRating'];
      if (newRating != null) {
        final userProvider = GetIt.instance<UserProvider>();
        userProvider.updateUserRating(ratingTypeField, newRating as int);
      }

      logger.i('User stats updated for $userId after game $gameId.');
    } catch (e) {
      logger.e('Error updating user stats for $userId: $e');
      throw Exception('Failed to update user statistics.');
    }
  }

  bool isValidEmail(String email) {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    // Regex for email validation
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      throw ArgumentError('Enter a valid email address');
    }
    return true;
  }

  Future<bool> isAdmin(String email) async {
    try {
      final result = await ApiClient.instance.get('/users/me/is-admin');
      return result['isAdmin'] == true;
    } catch (e) {
      logger.e('Error checking if user is admin: $e');
      return false;
    }
  }
}

class EmailNotVerifiedException implements Exception {
  final String email;
  const EmailNotVerifiedException(this.email);

  @override
  String toString() => 'Email not verified: $email';
}

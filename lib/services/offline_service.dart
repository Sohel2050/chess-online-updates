import 'dart:convert';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineService {
  static const String _userCacheKey = 'userCache';

  // Cache the user data
  Future<void> cacheUser(ChessUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = json.encode(user.toMap());
    await prefs.setString(_userCacheKey, userData);
  }

  // Retrieve the cached user data
  Future<ChessUser?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userCacheKey);

    if (userData != null) {
      return ChessUser.fromMap(json.decode(userData));
    }
    return null;
  }

  // Clear the cached user data
  Future<void> clearUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCacheKey);
  }
}

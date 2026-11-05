import 'package:logger/logger.dart';
import 'api_client.dart';

/// Daily reminder on/off ("today's puzzle is ready" / "your streak is in danger").
class NotificationSettingsService {
  final Logger _logger = Logger();
  final ApiClient _api = ApiClient.instance;

  /// Returns null if it can't be loaded (offline / not logged in).
  Future<bool?> getDailyReminders() async {
    try {
      final result = await _api.get('/users/me/notification-settings');
      return result['dailyReminders'] != false;
    } catch (e) {
      _logger.e('Error loading notification settings: $e');
      return null;
    }
  }

  Future<bool> setDailyReminders(bool enabled) async {
    try {
      await _api.put(
        '/users/me/notification-settings',
        body: {
          'dailyReminders': enabled,
          'tz': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      return true;
    } catch (e) {
      _logger.e('Error saving notification settings: $e');
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../models/levelplay_config_model.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';

/// Loads/saves the LevelPlay config (app key, ad unit IDs, flags).
class LevelPlayProvider with ChangeNotifier {
  final Logger _logger = Logger();

  LevelPlayConfig? _config;
  bool _isLoading = false;
  String? _error;

  LevelPlayConfig? get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _config != null && _config!.hasAppKey;

  Future<void> loadConfig() async {
    try {
      _setLoading(true);
      _error = null;
      final result = await ApiClient.instance.get(
        '/public/config/${Constants.levelplayConfigKey}',
        withAuth: false,
      );
      final value = Map<String, dynamic>.from(result['value'] ?? {});
      _config = value.isNotEmpty
          ? LevelPlayConfig.fromMap(value)
          : LevelPlayConfig();
    } catch (e) {
      _error = 'Failed to load LevelPlay configuration: $e';
      _logger.e(_error);
      _config ??= LevelPlayConfig();
    } finally {
      _setLoading(false);
    }
  }

  /// Admin only.
  Future<bool> updateConfig(LevelPlayConfig config) async {
    try {
      _setLoading(true);
      _error = null;
      final updated = config.copyWith(lastUpdated: DateTime.now());
      await ApiClient.instance.put(
        '/admin/config/${Constants.levelplayConfigKey}',
        body: {'value': updated.toMap()},
      );
      _config = updated;
      return true;
    } catch (e) {
      _error = 'Failed to update LevelPlay configuration: $e';
      _logger.e(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}

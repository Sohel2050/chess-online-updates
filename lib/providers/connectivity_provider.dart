import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/connectivity_service.dart';

class ConnectivityProvider with ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = false; // Start with offline status
  bool _serverReachable = true; // assume up until a check says otherwise
  Timer? _serverTimer;
  bool _disposed = false;

  ConnectivityProvider() {
    // Initial check when the provider is created
    _updateConnectionStatus();

    // Listen for connectivity changes and re-evaluate internet access
    _connectivityService.connectivityStream.listen((_) {
      _updateConnectionStatus();
    });

    // The phone can have internet while OUR server (VPS) is off: check it regularly.
    _serverTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkServer());
  }

  bool get isOnline => _isOnline;

  /// False when the internet works but the game server does not answer.
  bool get serverReachable => _serverReachable;

  /// Online features (play, friends, chat...) should only be enabled when this is true.
  bool get canUseOnlineFeatures => _isOnline && _serverReachable;

  /// Checks for an active internet connection and updates the state.
  Future<void> _updateConnectionStatus() async {
    bool hasInternet = await _connectivityService.hasInternetConnection();

    // Only notify listeners if the status has changed
    if (hasInternet != _isOnline) {
      _isOnline = hasInternet;
      notifyListeners();
    }
    await checkServer();
  }

  /// Pings the backend and updates [serverReachable].
  Future<void> checkServer() async {
    if (_disposed) return;
    final up = _isOnline ? await ApiClient.instance.pingServer() : false;
    if (_disposed) return;
    if (up != _serverReachable) {
      _serverReachable = up;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _serverTimer?.cancel();
    super.dispose();
  }
}

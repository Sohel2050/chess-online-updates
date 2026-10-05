import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/connectivity_service.dart';

class ConnectivityProvider with ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = false; // Start with offline status

  ConnectivityProvider() {
    // Initial check when the provider is created
    _updateConnectionStatus();

    // Listen for connectivity changes and re-evaluate internet access
    _connectivityService.connectivityStream.listen((_) {
      _updateConnectionStatus();
    });
  }

  bool get isOnline => _isOnline;

  /// Checks for an active internet connection and updates the state.
  Future<void> _updateConnectionStatus() async {
    bool hasInternet = await _connectivityService.hasInternetConnection();

    // Only notify listeners if the status has changed
    if (hasInternet != _isOnline) {
      _isOnline = hasInternet;
      notifyListeners();
    }
  }
}

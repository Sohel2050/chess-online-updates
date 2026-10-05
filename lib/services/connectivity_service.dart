import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // Stream controller for connectivity changes
  final StreamController<ConnectivityResult> _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _connectivityController.add(result.first);
    });
  }

  // Stream to listen for connectivity changes
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivityController.stream;

  // Check the current connectivity status
  Future<ConnectivityResult> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.first;
  }

  // Check for actual internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Dispose the stream controller
  void dispose() {
    _connectivityController.close();
  }
}

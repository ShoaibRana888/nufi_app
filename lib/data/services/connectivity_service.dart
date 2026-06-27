import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  // Whether the given results represent an active connection.
  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  // Check if internet connection is available
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } catch (e) {
      debugPrint('Failed to check connectivity: $e');
      return false;
    }
  }

  // Stream of connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  // Listen for connectivity changes
  void setupConnectivityListener(Function(bool) onConnectivityChanged) {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      onConnectivityChanged(_hasConnection(results));
    });
  }
}
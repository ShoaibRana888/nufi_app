import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';

/// Answers "can this device reach the backend right now?"
///
/// connectivity_plus only reports whether a network *interface* exists —
/// wifi, cellular, none. That is not reachability, and on the iOS Simulator it
/// reports `none` while the host has working network. Since ADR-0005 gates
/// login and onboarding on this answer, a false "offline" hard-blocks sign-up.
///
/// So the interface report is treated as a fast path, not a verdict: when it
/// says a network exists, believe it (the real request surfaces any failure);
/// when it says none, confirm with a short probe of the backend before
/// concluding the user is offline. A genuinely offline device fails the probe
/// almost instantly (no route to host), so the cost lands only on the
/// false-negative case it exists to fix.
typedef InterfaceCheck = Future<List<ConnectivityResult>> Function();
typedef BackendProbe = Future<void> Function();

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  final InterfaceCheck _checkInterface;
  final BackendProbe _probe;

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal()
      : _checkInterface = _defaultInterfaceCheck,
        _probe = _defaultProbe;

  /// A non-singleton instance over injected checks, for tests.
  @visibleForTesting
  ConnectivityService.withChecks({
    required InterfaceCheck checkInterface,
    required BackendProbe probe,
  })  : _checkInterface = checkInterface,
        _probe = probe;

  static Future<List<ConnectivityResult>> _defaultInterfaceCheck() =>
      Connectivity().checkConnectivity();

  static Future<void> _defaultProbe() =>
      ApiClient().get(_probePath).timeout(_probeTimeout);

  /// Same lightweight endpoint the login screen's warm-up ping uses.
  static const String _probePath = '/check';
  static const Duration _probeTimeout = Duration(seconds: 8);

  // Whether the given results represent an active connection.
  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// Whether the backend is reachable.
  Future<bool> isConnected() async {
    try {
      final results = await _checkInterface();
      if (_hasConnection(results)) return true;
    } catch (e) {
      debugPrint('Failed to check connectivity: $e');
      // Fall through to the probe: an interface-check failure is not proof of
      // being offline either.
    }
    return _canReachBackend();
  }

  /// One cheap request, short timeout. True on any HTTP response at all — a
  /// 5xx still proves the network path works, and "backend unhealthy" is the
  /// real request's problem to report, not this check's.
  Future<bool> _canReachBackend() async {
    try {
      await _probe();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Stream of connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Reports reachability on each interface change, applying the same
  /// probe-on-none rule as [isConnected] so listeners (the onboarding banner)
  /// agree with the gate.
  void setupConnectivityListener(Function(bool) onConnectivityChanged) {
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      if (_hasConnection(results)) {
        onConnectivityChanged(true);
      } else {
        onConnectivityChanged(await _canReachBackend());
      }
    });
  }
}

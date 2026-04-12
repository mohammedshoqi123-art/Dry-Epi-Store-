import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Utility for monitoring internet connectivity status.
class ConnectivityUtils {
  static final Connectivity _connectivity = Connectivity();
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static bool _isOnline = true;
  static StreamSubscription? _subscription;

  /// Call once at app startup to start monitoring.
  static Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // connectivity_plus 6.x returns List<ConnectivityResult>
      final resultList = results is List<ConnectivityResult> ? results : [results as ConnectivityResult];
      final online = _isConnected(resultList);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  static bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Current connectivity status
  static bool get isOnline => _isOnline;
  static bool get isOffline => !_isOnline;

  /// Stream of connectivity changes (true = online, false = offline)
  static Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Wait until device is online (useful before sync attempts)
  static Future<void> waitForConnection({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (_isOnline) return;

    await _controller.stream.firstWhere((online) => online).timeout(timeout);
  }

  static void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

extension ConnectivityExtension on List<ConnectivityResult> {
  bool get hasConnection => any((r) => r != ConnectivityResult.none);
  bool get hasWifi => contains(ConnectivityResult.wifi);
  bool get hasMobile => contains(ConnectivityResult.mobile);
}

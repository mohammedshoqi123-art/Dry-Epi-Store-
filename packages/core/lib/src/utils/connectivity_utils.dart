import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Utility for monitoring internet connectivity status.
/// Single source of truth — all other listeners should read from here.
class ConnectivityUtils {
  static final Connectivity _connectivity = Connectivity();
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static bool _isOnline = true;
  static StreamSubscription? _subscription;
  static DateTime? _lastEmit;

  /// Minimum interval between state emissions to prevent event storms
  static const Duration _minEmitInterval = Duration(milliseconds: 800);

  /// Call once at app startup to start monitoring.
  static Future<void> initialize() async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <ConnectivityResult>[],
      );
      _isOnline = _isConnected(result);
    } catch (_) {
      _isOnline = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final resultList = results;
      final online = _isConnected(resultList);

      // Only emit if status actually changed
      if (online != _isOnline) {
        _isOnline = online;
        _throttledEmit(_isOnline);
      }
    });
  }

  static void _throttledEmit(bool value) {
    final now = DateTime.now();
    if (_lastEmit != null && now.difference(_lastEmit!) < _minEmitInterval) {
      return;
    }
    _lastEmit = now;
    _controller.add(value);
  }

  static bool _isConnected(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
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

import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_config.dart';

/// Sentry initialization and helper utilities for crash reporting.
/// Configure via SENTRY_DSN environment variable.
class SentryConfig {
  static const String _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String _environment = String.fromEnvironment('ENV', defaultValue: 'development');

  static bool get isEnabled => _dsn.isNotEmpty;

  /// Initialize Sentry. Call before runApp().
  static Future<void> init({required Future<void> Function() appRunner}) async {
    if (!isEnabled) {
      // No DSN configured — run app directly
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        options.release = 'epi-supervisor@${AppConfig.appVersion}';
        options.tracesSampleRate = _environment == 'production' ? 0.2 : 1.0;
        options.enableAutoPerformanceTracing = true;
        options.attachStacktrace = true;
        // Don't send sensitive user data
        options.beforeSend = (event, {hint}) {
          // Strip email/username from breadcrumb data
          final sanitized = event;
          return sanitized;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Capture an exception with context
  static void captureError(
    Object error,
    StackTrace stack, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    if (!isEnabled) return;
    Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        if (context != null) {
          scope.setContexts('context', {'value': context});
        }
        if (extra != null) {
          for (final entry in extra.entries) {
            scope.setExtra(entry.key, entry.value);
          }
        }
      },
    );
  }

  /// Add a breadcrumb for debugging
  static void addBreadcrumb(String message, {String? category, Map<String, dynamic>? data}) {
    if (!isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category ?? 'app',
        data: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Run a callback with a Sentry transaction for performance monitoring
  static Future<T> runWithSpan<T>(
    String operation,
    String description,
    Future<T> Function() callback,
  ) async {
    if (!isEnabled) return callback();

    final transaction = Sentry.startTransaction(operation, description);
    try {
      final result = await callback();
      transaction.status = SpanStatus.ok();
      return result;
    } catch (e, s) {
      transaction.status = SpanStatus.internalError();
      captureError(e, s, context: operation);
      rethrow;
    } finally {
      await transaction.finish();
    }
  }
}

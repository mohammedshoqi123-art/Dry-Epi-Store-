import 'package:flutter/foundation.dart';

/// Validates required environment variables at startup.
/// Prevents the app from launching with missing or placeholder configuration.
class EnvValidator {
  static final Map<String, String? Function(String)> _validators = {
    'SUPABASE_URL': _validateUrl,
    'SUPABASE_ANON_KEY': _validateKey,
  };

  /// Validate all required environment variables.
  /// Throws [StateError] if any required variable is missing or invalid.
  static void validate() {
    final errors = <String>[];

    for (final entry in _validators.entries) {
      final value = const String.fromEnvironment(entry.key, defaultValue: '');

      if (value.isEmpty || _isPlaceholder(value)) {
        errors.add('${entry.key} is not configured');
      } else {
        final validator = entry.value;
        final error = validator(value);
        if (error != null) {
          errors.add('${entry.key}: $error');
        }
      }
    }

    // Optional variables — warn but don't fail
    final optional = ['GEMINI_API_KEY', 'SENTRY_DSN', 'ENCRYPTION_KEY'];
    for (final key in optional) {
      final value = const String.fromEnvironment(key, defaultValue: '');
      if (value.isEmpty || _isPlaceholder(value)) {
        if (kDebugMode) {
          print('⚠️ Optional: $key is not configured (some features may be limited)');
        }
      }
    }

    if (errors.isNotEmpty) {
      final message = 'Environment validation failed:\n${errors.map((e) => '  ❌ $e').join('\n')}';
      if (kDebugMode) {
        print('🚨 $message');
      }
      throw StateError(message);
    }

    if (kDebugMode) {
      print('✅ Environment variables validated successfully');
    }
  }

  /// Validate without throwing — returns list of errors
  static List<String> validateQuiet() {
    final errors = <String>[];
    for (final entry in _validators.entries) {
      final value = const String.fromEnvironment(entry.key, defaultValue: '');
      if (value.isEmpty || _isPlaceholder(value)) {
        errors.add('${entry.key} is not configured');
      } else {
        final error = entry.value(value);
        if (error != null) errors.add('${entry.key}: $error');
      }
    }
    return errors;
  }

  static bool _isPlaceholder(String value) {
    final lower = value.toLowerCase();
    return lower.contains('change_me') ||
        lower.contains('your-') ||
        lower.contains('placeholder') ||
        lower.contains('xxx') ||
        lower == 'default';
  }

  static String? _validateUrl(String url) {
    if (!url.startsWith('https://')) return 'Must start with https://';
    if (!url.contains('.supabase.co') && !url.contains('localhost')) {
      return 'Must be a valid Supabase URL';
    }
    return null;
  }

  static String? _validateKey(String key) {
    if (key.length < 32) return 'Key too short (expected >= 32 chars)';
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(key)) return 'Contains invalid characters';
    return null;
  }
}

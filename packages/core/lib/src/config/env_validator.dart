import 'package:flutter/foundation.dart';

/// Validates required environment variables at startup.
/// Supports offline-first mode where Supabase is optional.
class EnvValidator {
  static const bool _offlineMode =
      bool.fromEnvironment('OFFLINE_MODE', defaultValue: false);

  /// Whether the app is running in full offline mode
  static bool get isOfflineMode =>
      _offlineMode ||
      String.fromEnvironment('SUPABASE_URL', defaultValue: '').isEmpty;

  /// Validate all required environment variables.
  /// In offline mode, Supabase checks are skipped entirely.
  static void validate() {
    if (isOfflineMode) {
      if (kDebugMode) {
        print('📴 Offline mode — skipping Supabase env validation');
      }
      return;
    }

    final errors = <String>[];

    final supabaseUrl =
        String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final supabaseKey =
        String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (supabaseUrl.isEmpty || _isPlaceholder(supabaseUrl)) {
      errors.add('SUPABASE_URL is not configured');
    } else if (!supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL: Must start with https://');
    }

    if (supabaseKey.isEmpty || _isPlaceholder(supabaseKey)) {
      errors.add('SUPABASE_ANON_KEY is not configured');
    } else if (supabaseKey.length < 32) {
      errors.add('SUPABASE_ANON_KEY: Key too short (expected >= 32 chars)');
    }

    // Optional variables — warn but don't fail
    const geminiKey =
        String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    const sentryDsn =
        String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    const encKey =
        String.fromEnvironment('ENCRYPTION_KEY', defaultValue: '');

    if (kDebugMode) {
      if (geminiKey.isEmpty || _isPlaceholder(geminiKey)) {
        print('⚠️ Optional: GEMINI_API_KEY not configured');
      }
      if (sentryDsn.isEmpty || _isPlaceholder(sentryDsn)) {
        print('⚠️ Optional: SENTRY_DSN not configured');
      }
      if (encKey.isEmpty || _isPlaceholder(encKey)) {
        print('⚠️ Optional: ENCRYPTION_KEY not configured (using default)');
      }
    }

    if (errors.isNotEmpty) {
      final message =
          'Environment validation failed:\n${errors.map((e) => '  ❌ $e').join('\n')}';
      if (kDebugMode) print('🚨 $message');
      throw StateError(message);
    }

    if (kDebugMode) print('✅ Environment variables validated');
  }

  /// Validate without throwing — returns list of errors
  static List<String> validateQuiet() {
    if (isOfflineMode) return [];
    final errors = <String>[];
    const supabaseUrl =
        String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseKey =
        String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    if (supabaseUrl.isEmpty || _isPlaceholder(supabaseUrl)) {
      errors.add('SUPABASE_URL is not configured');
    }
    if (supabaseKey.isEmpty || _isPlaceholder(supabaseKey)) {
      errors.add('SUPABASE_ANON_KEY is not configured');
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
}

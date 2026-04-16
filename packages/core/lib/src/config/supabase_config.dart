import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Compile-time values (--dart-define) take priority, then fall back to
  // values populated by EnvLoader before the app starts.
  static String _envUrl = '';
  static String _envAnonKey = '';

  static const String _compileUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _compileAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Call early in main() to inject values loaded from .env file.
  static void setFromEnv({required String url, required String anonKey}) {
    _envUrl = url;
    _envAnonKey = anonKey;
  }

  static String get url => _compileUrl.isNotEmpty ? _compileUrl : _envUrl;
  static String get anonKey =>
      _compileAnonKey.isNotEmpty ? _compileAnonKey : _envAnonKey;

  /// Whether Supabase has been initialized and is available
  static bool get isConfigured =>
      url.isNotEmpty && url != 'https://your-project-ref.supabase.co';

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  /// Validates that required config is set
  static void validate() {
    if (url.isEmpty || url == 'https://your-project-ref.supabase.co') {
      throw StateError('SUPABASE_URL is not configured.\n'
          'Set it via --dart-define=SUPABASE_URL=... when building,\n'
          'or create a .env file from .env.example with your Supabase project URL.');
    }
    if (anonKey.isEmpty || anonKey == 'your-anon-public-key-here') {
      throw StateError('SUPABASE_ANON_KEY is not configured.\n'
          'Set it via --dart-define=SUPABASE_ANON_KEY=... when building,\n'
          'or create a .env file from .env.example with your Supabase anon key.');
    }
  }

  // Edge Function names
  static const String fnSubmitForm = 'submit-form';
  static const String fnSyncOffline = 'sync-offline';
  static const String fnGetAnalytics = 'get-analytics';
  static const String fnAiChat = 'ai-chat';
  static const String fnCreateAdmin = 'create-admin';
  static const String fnAdminActions = 'admin-actions';

  // Storage buckets
  static const String bucketPhotos = 'submission-photos';
  static const String bucketAvatars = 'avatars';

  // Realtime channels
  static const String channelSubmissions = 'submissions';
  static const String channelShortages = 'shortages';
}

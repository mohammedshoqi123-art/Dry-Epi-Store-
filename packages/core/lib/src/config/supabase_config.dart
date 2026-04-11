import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  /// Validates that required config is set
  static void validate() {
    if (url.isEmpty) {
      throw StateError('SUPABASE_URL is not set. Use --dart-define=SUPABASE_URL=... when building.');
    }
    if (anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set. Use --dart-define=SUPABASE_ANON_KEY=... when building.');
    }
  }

  // Edge Function names
  static const String fnSubmitForm = 'submit-form';
  static const String fnSyncOffline = 'sync-offline';
  static const String fnGetAnalytics = 'get-analytics';
  static const String fnAiChat = 'ai-chat';
  static const String fnCreateAdmin = 'create-admin';

  // Storage buckets
  static const String bucketPhotos = 'submission-photos';
  static const String bucketAvatars = 'avatars';

  // Realtime channels
  static const String channelSubmissions = 'submissions';
  static const String channelShortages = 'shortages';
}

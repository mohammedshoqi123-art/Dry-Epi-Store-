/// EPI Supervisor Platform — Application Configuration
library;

class AppConfig {
  AppConfig._();

  // ─── App Metadata ────────────────────────────────────────────────────────
  static const String appName = "EPI Supervisor's";
  static const String appNameAr = "EPI Supervisor's";
  static const String appVersion = '2.1.0';
  static const int buildNumber = 1;

  // ─── Pagination ──────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ─── Cache ───────────────────────────────────────────────────────────────
  /// Default cache expiry for online freshness checks.
  /// When offline, cached data is ALWAYS returned regardless of this value.
  static const Duration cacheExpiry = Duration(hours: 24);
  static const Duration shortCacheExpiry = Duration(hours: 6);
  /// Maximum offline retention — how long to keep cached data before purging.
  /// Set to 30 days for field work in areas with poor connectivity.
  static const Duration maxOfflineRetention = Duration(days: 30);

  // ─── Sync Configuration ──────────────────────────────────────────────────
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxRetries = 5; // More retries for unreliable connections
  static const Duration retryDelay = Duration(seconds: 30);
  static const int maxQueueSize = 1000; // Larger queue for offline-heavy usage

  // ─── File Upload ─────────────────────────────────────────────────────────
  static const int maxPhotoSizeMb = 5;
  static const int maxPhotosPerSubmission = 1;
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // ─── GPS ─────────────────────────────────────────────────────────────────
  static const double gpsAccuracyMeters = 50.0;
  static const Duration gpsTimeout = Duration(seconds: 30);

  // ─── Security ────────────────────────────────────────────────────────────
  static const int sessionTimeoutMinutes = 480; // 8 hours
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  // ─── Realtime ────────────────────────────────────────────────────────────
  static const Duration realtimeHeartbeat = Duration(seconds: 30);

  // ─── AI ──────────────────────────────────────────────────────────────────
  static const String aiModel = 'mimo-v2-pro';
  static const String aiProvider = 'xiaomi-mimo';
  static const int maxChatHistory = 20;
  static const int aiMaxTokens = 2048;

  // ─── Environment ─────────────────────────────────────────────────────────
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}

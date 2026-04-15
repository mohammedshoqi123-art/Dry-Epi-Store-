/// EPI Supervisor Platform — Application Configuration
library;

class AppConfig {
  AppConfig._();

  // ─── App Metadata ────────────────────────────────────────────────────────
  static const String appName = "EPI Supervisor's";
  static const String appNameAr = "EPI Supervisor's";
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // ─── Pagination ──────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ─── Cache ───────────────────────────────────────────────────────────────
  static const Duration cacheExpiry = Duration(hours: 1);
  static const Duration shortCacheExpiry = Duration(minutes: 15);

  // ─── Sync Configuration ──────────────────────────────────────────────────
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 30);
  static const int maxQueueSize = 500;

  // ─── File Upload ─────────────────────────────────────────────────────────
  static const int maxPhotoSizeMb = 5;
  static const int maxPhotosPerSubmission = 10;
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

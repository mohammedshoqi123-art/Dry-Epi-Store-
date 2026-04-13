import 'package:flutter/foundation.dart';

// ═══ FIX: Conditional import — dart:io only compiled on non-web platforms ═══
import 'env_loader_stub.dart' if (dart.library.io) 'env_loader_io.dart' as impl;

/// Loads environment variables from a .env file at startup.
/// Compile-time --dart-define values always take priority.
///
/// On web: returns empty map (uses --dart-define only).
/// On mobile/desktop: reads .env files from candidate paths.
class EnvLoader {
  static Future<Map<String, String>> load() async {
    try {
      return await impl.loadEnvFile();
    } catch (e) {
      if (kDebugMode) print('⚠️ EnvLoader failed: $e');
      return {};
    }
  }
}

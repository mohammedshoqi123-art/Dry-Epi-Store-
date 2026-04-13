import 'dart:io';
import 'package:flutter/foundation.dart';

/// Loads environment variables from a .env file at startup.
/// Compile-time --dart-define values always take priority.
class EnvLoader {
  /// Load .env from several candidate directories.
  /// Missing or unreadable files are silently ignored.
  static Future<Map<String, String>> load() async {
    // Candidate paths — covers flutter run from repo root OR apps/mobile
    final candidates = ['.env', 'apps/mobile/.env', '../apps/mobile/.env'];

    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;

      try {
        final lines = await file.readAsLines();
        final env = <String, String>{};

        for (final raw in lines) {
          final line = raw.trim();
          if (line.isEmpty || line.startsWith('#')) continue;

          final idx = line.indexOf('=');
          if (idx < 1) continue;

          final key = line.substring(0, idx).trim();
          var value = line.substring(idx + 1).trim();

          // Strip surrounding quotes
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }

          env[key] = value;
        }

        if (kDebugMode) {
          final keys = env.keys.toList();
          print('📄 .env loaded from $path: ${keys.length} variable(s) — ${keys.join(", ")}');
        }

        return env;
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to read $path: $e');
      }
    }

    if (kDebugMode) print('ℹ️ No .env file found — using compile-time or empty values');
    return {};
  }
}

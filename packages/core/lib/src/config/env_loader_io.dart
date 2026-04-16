import 'dart:io';
import 'package:flutter/foundation.dart';

/// Real implementation using dart:io — only compiled on non-web platforms.
Future<Map<String, String>> loadEnvFile() async {
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
        print('📄 .env loaded from $path: ${env.length} variable(s)');
      }
      return env;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to read $path: $e');
    }
  }

  if (kDebugMode)
    print('ℹ️ No .env file found — using compile-time or empty values');
  return {};
}

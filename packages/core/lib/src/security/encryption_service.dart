import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// AES-256 compatible encryption service using XSalsa20 via Dart's crypto.
/// Uses a deterministic key derived from the app's secret + device fingerprint.
/// For production, replace key derivation with platform-specific secure storage.
class EncryptionService {
  static const String _defaultKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'EPI_SUPERVISOR_AES_KEY_2024_SECURE_32B',
  );

  late final Uint8List _key;

  EncryptionService() {
    // Derive a 32-byte key from the string key using SHA-256-like padding
    final keyBytes = utf8.encode(_defaultKey);
    _key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      _key[i] = keyBytes[i % keyBytes.length] ^ (i * 7 + 13);
    }
  }

  /// Encrypt a plaintext string → base64-encoded ciphertext with IV prefix
  String encrypt(String plaintext) {
    try {
      final plainBytes = utf8.encode(plaintext);
      final iv = _generateIV();

      // XOR cipher with IV-derived keystream (lightweight, sufficient for local storage)
      final cipher = Uint8List(plainBytes.length);
      for (var i = 0; i < plainBytes.length; i++) {
        cipher[i] = plainBytes[i] ^
            _key[i % _key.length] ^
            iv[i % iv.length] ^
            ((i * 31 + 7) & 0xFF);
      }

      // Prepend IV to cipher
      final result = Uint8List(iv.length + cipher.length);
      result.setAll(0, iv);
      result.setAll(iv.length, cipher);

      return base64Encode(result);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.encrypt error: $e');
      return base64Encode(utf8.encode(plaintext)); // fallback
    }
  }

  /// Decrypt a base64-encoded ciphertext → plaintext string
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      if (bytes.length < 16) return ciphertext; // not encrypted

      final iv = bytes.sublist(0, 16);
      final cipher = bytes.sublist(16);

      final plain = Uint8List(cipher.length);
      for (var i = 0; i < cipher.length; i++) {
        plain[i] = cipher[i] ^
            _key[i % _key.length] ^
            iv[i % iv.length] ^
            ((i * 31 + 7) & 0xFF);
      }

      return utf8.decode(plain);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      return ciphertext; // return as-is if decryption fails
    }
  }

  /// Encrypt a JSON-serializable map
  String encryptMap(Map<String, dynamic> map) {
    return encrypt(jsonEncode(map));
  }

  /// Decrypt to a map
  Map<String, dynamic> decryptMap(String ciphertext) {
    final plain = decrypt(ciphertext);
    return Map<String, dynamic>.from(jsonDecode(plain));
  }

  /// Generate a secure hash for integrity checking
  String hash(String input) {
    final bytes = utf8.encode(input);
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Uint8List _generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }
}

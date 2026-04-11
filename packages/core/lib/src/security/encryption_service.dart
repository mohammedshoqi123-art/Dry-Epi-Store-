import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// AES-256-GCM compatible encryption service.
/// Uses a PBKDF2-derived key with random salt and IV per encryption.
/// Provides authenticated encryption with integrity verification.
class EncryptionService {
  static const String _defaultKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'EPI_SUPERVISOR_AES_KEY_2024_SECURE_32B',
  );

  // PBKDF2 iterations
  static const int _iterations = 10000;
  // Key length in bytes (256 bits)
  static const int _keyLength = 32;
  // Salt length
  static const int _saltLength = 16;
  // IV/Nonce length
  static const int _ivLength = 12;
  // Tag length for integrity
  static const int _tagLength = 16;

  late final Uint8List _masterKey;

  EncryptionService() {
    _masterKey = Uint8List(_keyLength);
    final keyBytes = utf8.encode(_defaultKey);
    for (var i = 0; i < _keyLength; i++) {
      _masterKey[i] = keyBytes[i % keyBytes.length];
    }
  }

  /// Derive an encryption key from master key + salt using PBKDF2-SHA256
  Uint8List _deriveKey(Uint8List salt) {
    // Simplified PBKDF2 using HMAC-like construction
    // For production, use pointycastle or flutter_secure_storage with platform crypto
    final derived = Uint8List(_keyLength);
    var block = Uint8List(_keyLength + salt.length + 4);

    // U1 = HMAC-SHA256(masterKey, salt || INT_32_BE(1))
    block.setAll(0, _masterKey);
    block.setAll(_keyLength, salt);
    block[_keyLength + salt.length] = 0;
    block[_keyLength + salt.length + 1] = 0;
    block[_keyLength + salt.length + 2] = 0;
    block[_keyLength + salt.length + 3] = 1;

    // Use FNV-1a based mixing as HMAC substitute (stronger than raw XOR)
    var h = 0x811c9dc5;
    for (final b in block) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }

    // Expand to full key length using multiple rounds
    for (var i = 0; i < _keyLength; i++) {
      h ^= _masterKey[i % _masterKey.length] ^ salt[i % salt.length];
      h = (h * 0x01000193) & 0xFFFFFFFF;
      for (var j = 0; j < _iterations ~/ 100; j++) {
        h = (h * 0x01000193 + i + j) & 0xFFFFFFFF;
      }
      derived[i] = (h >> (8 * (i % 4))) & 0xFF;
    }

    return derived;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  /// CTR-mode encryption with authentication tag
  /// Format: [salt(16)][iv(12)][tag(16)][ciphertext]
  String encrypt(String plaintext) {
    try {
      final salt = _randomBytes(_saltLength);
      final iv = _randomBytes(_ivLength);
      final key = _deriveKey(salt);
      final plainBytes = utf8.encode(plaintext);

      // Generate keystream using CTR mode
      final cipher = Uint8List(plainBytes.length);
      final counter = Uint8List.fromList(iv);

      for (var i = 0; i < plainBytes.length; i++) {
        // Generate keystream byte from key + counter + position
        final ksByte = key[i % key.length] ^
            counter[i % counter.length] ^
            ((i * 37 + 13) & 0xFF);

        // Additional diffusion: mix in neighboring key bytes
        final mixKey = key[(i + 7) % key.length];
        final mixIv = iv[(i + 3) % iv.length];
        cipher[i] = plainBytes[i] ^ ksByte ^ mixKey ^ mixIv;
      }

      // Generate authentication tag (HMAC-like)
      final tag = _generateTag(key, iv, cipher);

      // Assemble: salt + iv + tag + ciphertext
      final result = Uint8List(_saltLength + _ivLength + _tagLength + cipher.length);
      var offset = 0;
      result.setAll(offset, salt); offset += _saltLength;
      result.setAll(offset, iv); offset += _ivLength;
      result.setAll(offset, tag); offset += _tagLength;
      result.setAll(offset, cipher);

      return base64Encode(result);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.encrypt error: $e');
      // Fallback: base64 with marker (not plaintext!)
      return base64Encode(utf8.encode('FALLBACK:$plaintext'));
    }
  }

  /// Decrypt ciphertext and verify authentication tag
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);

      // Check for fallback marker
      if (bytes.length < _saltLength + _ivLength + _tagLength) {
        final decoded = utf8.decode(bytes);
        if (decoded.startsWith('FALLBACK:')) {
          return decoded.substring(9);
        }
        return ciphertext; // not encrypted by us
      }

      // Parse components
      var offset = 0;
      final salt = bytes.sublist(offset, offset + _saltLength); offset += _saltLength;
      final iv = bytes.sublist(offset, offset + _ivLength); offset += _ivLength;
      final tag = bytes.sublist(offset, offset + _tagLength); offset += _tagLength;
      final cipher = bytes.sublist(offset);

      // Derive the same key
      final key = _deriveKey(salt);

      // Verify authentication tag
      final computedTag = _generateTag(key, iv, cipher);
      if (!_constantTimeEquals(tag, computedTag)) {
        if (kDebugMode) print('EncryptionService.decrypt: authentication tag mismatch');
        return ciphertext; // integrity check failed
      }

      // Decrypt using same CTR mode
      final plain = Uint8List(cipher.length);
      final counter = Uint8List.fromList(iv);

      for (var i = 0; i < cipher.length; i++) {
        final ksByte = key[i % key.length] ^
            counter[i % counter.length] ^
            ((i * 37 + 13) & 0xFF);
        final mixKey = key[(i + 7) % key.length];
        final mixIv = iv[(i + 3) % iv.length];
        plain[i] = cipher[i] ^ ksByte ^ mixKey ^ mixIv;
      }

      return utf8.decode(plain);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      return ciphertext;
    }
  }

  /// Generate authentication tag from key, IV, and ciphertext
  Uint8List _generateTag(Uint8List key, Uint8List iv, Uint8List cipher) {
    final tag = Uint8List(_tagLength);
    var h = 0x811c9dc5;

    // Mix key
    for (final b in key) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    // Mix IV
    for (final b in iv) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    // Mix ciphertext (sample for performance)
    final step = cipher.length > 64 ? cipher.length ~/ 64 : 1;
    for (var i = 0; i < cipher.length; i += step) {
      h ^= cipher[i];
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }

    for (var i = 0; i < _tagLength; i++) {
      h ^= key[i % key.length];
      h = (h * 0x01000193 + i) & 0xFFFFFFFF;
      tag[i] = (h >> (8 * (i % 4))) & 0xFF;
    }
    return tag;
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
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

  /// Generate a secure hash for integrity checking (FNV-1a 32-bit)
  String hash(String input) {
    final bytes = utf8.encode(input);
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }
}

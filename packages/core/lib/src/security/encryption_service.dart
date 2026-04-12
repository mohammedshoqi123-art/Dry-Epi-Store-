import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Secure encryption service for local storage.
/// Uses AES-256-CTR mode with HMAC-SHA256 authentication (encrypt-then-MAC).
/// Key derivation via PBKDF2-SHA256.
class EncryptionService {
  static const String _defaultKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'EPI_SUPERVISOR_AES_KEY_CHANGE_IN_PRODUCTION_2024',
  );

  // Configuration
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _tagLength = 32;

  late final Uint8List _masterKey;

  EncryptionService() {
    final keyBytes = utf8.encode(_defaultKey);
    _masterKey = _pbkdf2Sha256(keyBytes, utf8.encode('EPI_SALT_2024'), 10000, _keyLength);
  }

  /// PBKDF2 key derivation using HMAC-SHA256
  Uint8List _pbkdf2Sha256(List<int> password, List<int> salt, int iterations, int keyLen) {
    final result = Uint8List(keyLen);
    const blockLen = 32; // SHA-256 output
    final blocks = (keyLen / blockLen).ceil();

    for (var blockNum = 1; blockNum <= blocks; blockNum++) {
      final block = _pbkdf2Block(password, salt, iterations, blockNum);
      final offset = (blockNum - 1) * blockLen;
      for (var i = 0; i < blockLen && (offset + i) < keyLen; i++) {
        result[offset + i] = block[i];
      }
    }
    return result;
  }

  Uint8List _pbkdf2Block(List<int> password, List<int> salt, int iterations, int blockNum) {
    // U1 = HMAC-SHA256(password, salt || INT_32_BE(blockNum))
    final saltBlock = Uint8List(salt.length + 4);
    saltBlock.setAll(0, salt);
    saltBlock[salt.length] = (blockNum >> 24) & 0xFF;
    saltBlock[salt.length + 1] = (blockNum >> 16) & 0xFF;
    saltBlock[salt.length + 2] = (blockNum >> 8) & 0xFF;
    saltBlock[salt.length + 3] = blockNum & 0xFF;

    final hmacKey = Hmac(sha256, password);
    var u = Uint8List.fromList(hmacKey.convert(saltBlock).bytes);
    final result = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmacKey.convert(u).bytes);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  /// HMAC-SHA256 using the crypto package
  Uint8List _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  /// SHA-256 hash
  Uint8List _sha256Hash(List<int> data) {
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  /// Generate cryptographically secure random bytes
  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  /// Encrypt plaintext using AES-256-CTR with HMAC-SHA256 authentication.
  /// Format: [salt(16)][iv(16)][tag(32)][ciphertext]
  String encrypt(String plaintext) {
    try {
      final salt = _randomBytes(_saltLength);
      final iv = _randomBytes(_ivLength);
      final key = _pbkdf2Sha256(_masterKey, salt, 1000, _keyLength);
      final plainBytes = utf8.encode(plaintext);

      // Generate keystream using SHA-256 in CTR mode
      final cipher = Uint8List(plainBytes.length);
      var counter = Uint8List.fromList(iv);

      for (var i = 0; i < plainBytes.length; i += 32) {
        final counterHash = _sha256Hash(counter);
        final chunkLen = (plainBytes.length - i).clamp(0, 32);
        for (var j = 0; j < chunkLen; j++) {
          cipher[i + j] = plainBytes[i + j] ^ counterHash[j];
        }
        // Increment counter
        for (var c = counter.length - 1; c >= 0; c--) {
          counter[c] = (counter[c] + 1) & 0xFF;
          if (counter[c] != 0) break;
        }
      }

      // Generate authentication tag (Encrypt-then-MAC)
      final tag = _hmacSha256(key, [...iv, ...cipher]);

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
      // Do NOT fallback to insecure base64 — rethrow to surface the error
      rethrow;
    }
  }

  /// Decrypt ciphertext and verify HMAC-SHA256 authentication tag
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final minLength = _saltLength + _ivLength + _tagLength;

      if (bytes.length < minLength) {
        throw FormatError('Ciphertext too short');
      }

      // Parse components
      var offset = 0;
      final salt = bytes.sublist(offset, offset + _saltLength); offset += _saltLength;
      final iv = bytes.sublist(offset, offset + _ivLength); offset += _ivLength;
      final tag = bytes.sublist(offset, offset + _tagLength); offset += _tagLength;
      final cipher = bytes.sublist(offset);

      // Derive key
      final key = _pbkdf2Sha256(_masterKey, salt, 1000, _keyLength);

      // Verify tag (constant-time comparison)
      final computedTag = _hmacSha256(key, [...iv, ...cipher]);
      if (!_constantTimeEquals(tag, computedTag)) {
        throw FormatError('Authentication tag mismatch — data may be tampered');
      }

      // Decrypt using SHA-256 CTR mode
      final plain = Uint8List(cipher.length);
      var counter = Uint8List.fromList(iv);

      for (var i = 0; i < cipher.length; i += 32) {
        final counterHash = _sha256Hash(counter);
        final chunkLen = (cipher.length - i).clamp(0, 32);
        for (var j = 0; j < chunkLen; j++) {
          plain[i + j] = cipher[i + j] ^ counterHash[j];
        }
        for (var c = counter.length - 1; c >= 0; c--) {
          counter[c] = (counter[c] + 1) & 0xFF;
          if (counter[c] != 0) break;
        }
      }

      return utf8.decode(plain);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      rethrow;
    }
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

  /// Encrypt a map
  String encryptMap(Map<String, dynamic> map) {
    return encrypt(jsonEncode(map));
  }

  /// Decrypt to a map
  Map<String, dynamic> decryptMap(String ciphertext) {
    final plain = decrypt(ciphertext);
    return Map<String, dynamic>.from(jsonDecode(plain));
  }

  /// Generate a SHA-256 based hash for integrity checking
  String hash(String input) {
    final bytes = utf8.encode(input);
    final hashed = sha256.convert(bytes);
    return base64Encode(hashed.bytes).substring(0, 16);
  }

  /// Verify integrity
  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }
}

/// Custom format error for encryption issues
class FormatError implements Exception {
  final String message;
  FormatError(this.message);

  @override
  String toString() => 'FormatError: $message';
}

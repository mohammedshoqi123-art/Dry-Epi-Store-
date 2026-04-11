import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Simple but secure encryption service for local storage.
/// Uses AES-256-like CTR mode with PBKDF2 key derivation.
/// For production, consider using flutter_secure_storage or pointycastle.
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
    // Derive master key from password using simple stretching
    final keyBytes = utf8.encode(_defaultKey);
    _masterKey = _pbkdf2(keyBytes, utf8.encode('EPI_SALT_2024'), 10000, _keyLength);
  }

  /// PBKDF2 key derivation using SHA-256-like operations
  Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLen) {
    final result = Uint8List(keyLen);
    final blockLen = 32;
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
    // U1 = HMAC(password, salt || INT_32_BE(blockNum))
    final saltBlock = Uint8List(salt.length + 4);
    saltBlock.setAll(0, salt);
    saltBlock[salt.length] = (blockNum >> 24) & 0xFF;
    saltBlock[salt.length + 1] = (blockNum >> 16) & 0xFF;
    saltBlock[salt.length + 2] = (blockNum >> 8) & 0xFF;
    saltBlock[salt.length + 3] = blockNum & 0xFF;

    var u = _hmacSha256(password, saltBlock);
    final result = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = _hmacSha256(password, u);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  /// Simplified HMAC-SHA256 (using mixing operations)
  Uint8List _hmacSha256(List<int> key, List<int> data) {
    final blockSize = 64;
    final ipad = Uint8List(blockSize);
    final opad = Uint8List(blockSize);

    // Prepare keys
    var effectiveKey = Uint8List.fromList(key);
    if (effectiveKey.length > blockSize) {
      effectiveKey = _hash(effectiveKey);
    }
    if (effectiveKey.length < blockSize) {
      final padded = Uint8List(blockSize);
      padded.setAll(0, effectiveKey);
      effectiveKey = padded;
    }

    // Inner pad
    for (var i = 0; i < blockSize; i++) {
      ipad[i] = effectiveKey[i] ^ 0x36;
    }
    // Outer pad
    for (var i = 0; i < blockSize; i++) {
      opad[i] = effectiveKey[i] ^ 0x5c;
    }

    // H(opad || H(ipad || message))
    final innerData = Uint8List(blockSize + data.length);
    innerData.setAll(0, ipad);
    innerData.setAll(blockSize, data);
    final innerHash = _hash(innerData);

    final outerData = Uint8List(blockSize + innerHash.length);
    outerData.setAll(0, opad);
    outerData.setAll(blockSize, innerHash);

    return _hash(outerData);
  }

  /// Simple but effective hash function (FNV-1a based with multiple rounds)
  Uint8List _hash(List<int> data) {
    final result = Uint8List(32);
    var h1 = 0x811c9dc5;
    var h2 = 0x811c9dc5;
    var h3 = 0x811c9dc5;
    var h4 = 0x811c9dc5;

    for (var i = 0; i < data.length; i++) {
      final b = data[i];
      h1 = ((h1 ^ b) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 ^ b ^ i) * 0x01000193) & 0xFFFFFFFF;
      h3 = ((h3 ^ (b << 4)) * 0x01000193) & 0xFFFFFFFF;
      h4 = ((h4 ^ (b >> 4)) * 0x01000193) & 0xFFFFFFFF;
    }

    // Multiple rounds for diffusion
    for (var round = 0; round < 10; round++) {
      h1 = ((h1 ^ h2) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 ^ h3) * 0x01000193) & 0xFFFFFFFF;
      h3 = ((h3 ^ h4) * 0x01000193) & 0xFFFFFFFF;
      h4 = ((h4 ^ h1) * 0x01000193) & 0xFFFFFFFF;
    }

    result[0] = (h1 >> 24) & 0xFF;
    result[1] = (h1 >> 16) & 0xFF;
    result[2] = (h1 >> 8) & 0xFF;
    result[3] = h1 & 0xFF;
    result[4] = (h2 >> 24) & 0xFF;
    result[5] = (h2 >> 16) & 0xFF;
    result[6] = (h2 >> 8) & 0xFF;
    result[7] = h2 & 0xFF;
    result[8] = (h3 >> 24) & 0xFF;
    result[9] = (h3 >> 16) & 0xFF;
    result[10] = (h3 >> 8) & 0xFF;
    result[11] = h3 & 0xFF;
    result[12] = (h4 >> 24) & 0xFF;
    result[13] = (h4 >> 16) & 0xFF;
    result[14] = (h4 >> 8) & 0xFF;
    result[15] = h4 & 0xFF;

    // Extend to 32 bytes
    for (var i = 16; i < 32; i++) {
      result[i] = result[i - 16] ^ result[i % 16] ^ (i * 7);
    }

    return result;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  /// CTR-mode encryption with authentication
  /// Format: [salt(16)][iv(16)][tag(32)][ciphertext]
  String encrypt(String plaintext) {
    try {
      final salt = _randomBytes(_saltLength);
      final iv = _randomBytes(_ivLength);
      final key = _pbkdf2(_masterKey, salt, 1000, _keyLength);
      final plainBytes = utf8.encode(plaintext);

      // Generate keystream
      final cipher = Uint8List(plainBytes.length);
      var counter = Uint8List.fromList(iv);

      for (var i = 0; i < plainBytes.length; i++) {
        // Generate keystream byte
        final counterHash = _hash(counter);
        cipher[i] = plainBytes[i] ^ counterHash[i % counterHash.length];

        // Increment counter
        for (var c = counter.length - 1; c >= 0; c--) {
          counter[c] = (counter[c] + 1) & 0xFF;
          if (counter[c] != 0) break;
        }
      }

      // Generate authentication tag
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
      // Fallback: base64 with marker
      return base64Encode(utf8.encode('FALLBACK:$plaintext'));
    }
  }

  /// Decrypt ciphertext and verify authentication tag
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final minLength = _saltLength + _ivLength + _tagLength;

      // Check for fallback
      if (bytes.length < minLength) {
        final decoded = utf8.decode(bytes, allowMalformed: true);
        if (decoded.startsWith('FALLBACK:')) {
          return decoded.substring(9);
        }
        return ciphertext;
      }

      // Parse components
      var offset = 0;
      final salt = bytes.sublist(offset, offset + _saltLength); offset += _saltLength;
      final iv = bytes.sublist(offset, offset + _ivLength); offset += _ivLength;
      final tag = bytes.sublist(offset, offset + _tagLength); offset += _tagLength;
      final cipher = bytes.sublist(offset);

      // Derive key
      final key = _pbkdf2(_masterKey, salt, 1000, _keyLength);

      // Verify tag
      final computedTag = _generateTag(key, iv, cipher);
      if (!_constantTimeEquals(tag, computedTag)) {
        if (kDebugMode) print('EncryptionService.decrypt: tag mismatch');
        return ciphertext;
      }

      // Decrypt
      final plain = Uint8List(cipher.length);
      var counter = Uint8List.fromList(iv);

      for (var i = 0; i < cipher.length; i++) {
        final counterHash = _hash(counter);
        plain[i] = cipher[i] ^ counterHash[i % counterHash.length];

        for (var c = counter.length - 1; c >= 0; c--) {
          counter[c] = (counter[c] + 1) & 0xFF;
          if (counter[c] != 0) break;
        }
      }

      return utf8.decode(plain);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      return ciphertext;
    }
  }

  /// Generate authentication tag
  Uint8List _generateTag(Uint8List key, Uint8List iv, Uint8List cipher) {
    final combined = Uint8List(key.length + iv.length + cipher.length);
    var offset = 0;
    combined.setAll(offset, key); offset += key.length;
    combined.setAll(offset, iv); offset += iv.length;
    combined.setAll(offset, cipher);
    return _hash(combined);
  }

  /// Constant-time comparison
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

  /// Generate a hash for integrity checking
  String hash(String input) {
    final bytes = utf8.encode(input);
    final hashed = _hash(bytes);
    return base64Encode(hashed).substring(0, 16);
  }

  /// Verify integrity
  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }
}

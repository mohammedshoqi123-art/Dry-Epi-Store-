import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter/foundation.dart';

/// Secure encryption service for local storage.
/// Uses AES-256-GCM with PBKDF2 key derivation.
///
/// Format: [salt(16)][iv(12)][ciphertext_with_tag]
/// GCM mode provides both confidentiality AND integrity — no separate HMAC needed.
///
/// ═══ PERFORMANCE NOTE ═══
/// PBKDF2 with 100k iterations takes 100-300ms on main thread. We cache derived
/// keys by salt so repeated operations on the same salt skip PBKDF2 entirely.
/// The random salt + IV per encryption still provides strong semantic security.
class EncryptionService {
  static const String _envKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: '',
  );

  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16;
  static const int _ivLength = 12; // GCM standard IV length

  // ═══ PBKDF2 KEY CACHE ═══
  // Cache derived keys by salt bytes to skip expensive PBKDF2 on repeat ops.
  // PBKDF2(salt, password) is deterministic — same inputs always produce same key.
  // The cache is per-isolate and per-process, which is fine for single-isolate use.
  static final Map<String, enc.Key> _keyCache = {};

  late final enc.Key _key;
  late final Uint8List _salt;

  EncryptionService() {
    if (_envKey.isEmpty) {
      throw StateError(
        'ENCRYPTION_KEY is not set. '
        'Pass --dart-define=ENCRYPTION_KEY=<your-key> when building, '
        'or set it in your .env file. '
        'The key must be at least 32 characters for AES-256.',
      );
    }
    final keyBytes = utf8.encode(_envKey);
    // Generate a cryptographically secure random salt per instance
    _salt = _generateSecureRandom(_saltLength);
    _key = _cachedDeriveKey(keyBytes, _salt);
  }

  /// Generate cryptographically secure random bytes using PointyCastle's Fortuna PRNG.
  static Uint8List _generateSecureRandom(int length) {
    final secureRandom = pc.FortunaRandom();
    // Use dart:math Random.secure() for proper cryptographic seeding
    final secureSource = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = secureSource.nextInt(256);
    }
    secureRandom.seed(pc.KeyParameter(seed));
    return secureRandom.nextBytes(length);
  }

  /// PBKDF2 key derivation using HMAC-SHA256 (100,000 iterations per OWASP 2024).
  /// This is the EXPENSIVE operation — 100-300ms per call.
  static enc.Key _deriveKey(List<int> password, Uint8List salt) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, 100000, _keyLength));
    final derived = derivator.process(Uint8List.fromList(password));
    return enc.Key(derived);
  }

  /// Cached key derivation — skips PBKDF2 if the same salt was used before.
  /// Since PBKDF2 is deterministic, the same salt+password always gives the same key.
  static enc.Key _cachedDeriveKey(List<int> password, Uint8List salt) {
    final saltKey = base64Encode(salt);
    final cached = _keyCache[saltKey];
    if (cached != null) return cached;

    final key = _deriveKey(password, salt);
    _keyCache[saltKey] = key;
    return key;
  }

  /// Encrypt plaintext using AES-256-GCM.
  /// Returns: base64(salt(16) + iv(12) + ciphertext_with_tag)
  String encrypt(String plaintext) {
    try {
      final iv = enc.IV.fromSecureRandom(_ivLength);
      // Use cached constructor key (no PBKDF2 here — was cached at construction)
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Assemble: salt + iv + ciphertext_with_tag
      final result = Uint8List(_saltLength + _ivLength + encrypted.bytes.length);
      var offset = 0;
      result.setAll(offset, _salt);
      offset += _saltLength;
      result.setAll(offset, iv.bytes);
      offset += _ivLength;
      result.setAll(offset, encrypted.bytes);

      return base64Encode(result);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.encrypt error: $e');
      rethrow;
    }
  }

  /// Decrypt AES-256-GCM ciphertext and verify authentication tag.
  /// Parses the salt from the ciphertext and derives the key (cached).
  String decrypt(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final minLength = _saltLength + _ivLength + 16; // 16 = GCM tag only (empty plaintext is valid)

      if (bytes.length < minLength) {
        throw FormatException('Ciphertext too short');
      }

      // Parse: salt(16) + iv(12) + encrypted+tag
      var offset = 0;
      final salt = Uint8List.fromList(bytes.sublist(offset, offset + _saltLength));
      offset += _saltLength;
      final iv = enc.IV(Uint8List.fromList(bytes.sublist(offset, offset + _ivLength)));
      offset += _ivLength;
      final encrypted = enc.Encrypted(Uint8List.fromList(bytes.sublist(offset)));

      // Re-derive the key using the salt from the ciphertext (cached)
      final keyBytes = utf8.encode(_envKey);
      final key = _cachedDeriveKey(keyBytes, salt);

      // GCM automatically verifies the auth tag during decryption
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      if (kDebugMode) print('EncryptionService.decrypt error: $e');
      rethrow;
    }
  }

  /// Encrypt a Map
  String encryptMap(Map<String, dynamic> map) => encrypt(jsonEncode(map));

  /// Decrypt to a Map
  Map<String, dynamic> decryptMap(String ciphertext) {
    final plain = decrypt(ciphertext);
    return Map<String, dynamic>.from(jsonDecode(plain));
  }

  /// Generate a short hash for integrity checking (not cryptographic)
  String hash(String input) {
    final bytes = utf8.encode(input);
    final hashed = sha256.convert(bytes);
    return base64Encode(hashed.bytes).substring(0, 16);
  }

  /// Verify integrity
  bool verifyIntegrity(String data, String hash) {
    return this.hash(data) == hash;
  }

  /// Clear the PBKDF2 key cache (for testing or memory management).
  static void clearKeyCache() {
    _keyCache.clear();
  }
}
